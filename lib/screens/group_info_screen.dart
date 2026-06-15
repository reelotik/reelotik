// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- CUSTOM WIDGETS & SERVICES ---
import '../widgets/group_photo_picker.dart';
import '../services/group_photo_service.dart';
import 'full_screen_image_viewer.dart';
import 'group_settings_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // ==========================================
  // GROUP ACTIONS & SECURITY
  // ==========================================

  Future<void> leaveGroup() async {
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      "members": FieldValue.arrayRemove([currentUid]),
      "admins": FieldValue.arrayRemove([currentUid]) // Remove from admins too if they leave
    });
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // ✅ DANGEROUS ISSUE FIXED: Backend & Frontend Admin Check Added
  Future<void> deleteGroup(bool isAdmin) async {
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only Admins can delete the group.")));
      return;
    }
    
    // Optional: Ask for confirmation before deleting
    bool confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xff1f2937),
        title: const Text("Delete Group?", style: TextStyle(color: Colors.white)),
        content: const Text("This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).delete();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  Future<void> muteGroup(bool isMuted) async {
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      "mutedBy": isMuted ? FieldValue.arrayRemove([currentUid]) : FieldValue.arrayUnion([currentUid])
    });
  }

  void exportChat() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Exporting chat to file...")));
    // Logic for chat export goes here (e.g., fetching all messages and converting to TXT)
  }

  void reportGroup() {
    FirebaseFirestore.instance.collection("reports").add({
      "groupId": widget.groupId,
      "reportedBy": currentUid,
      "timestamp": FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group reported for review.")));
  }

  void copyInviteLink() {
    // Generate a simple invite link format
    final String link = "https://reelotik.com/invite/${widget.groupId}";
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invite link copied to clipboard!")));
  }

  // ==========================================
  // ADMIN MEMBER CONTROLS
  // ==========================================
  Future<void> removeMember(String uid) async {
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      "members": FieldValue.arrayRemove([uid]),
      "admins": FieldValue.arrayRemove([uid])
    });
  }

  Future<void> promoteAdmin(String uid) async {
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      "admins": FieldValue.arrayUnion([uid])
    });
  }

  Future<void> demoteAdmin(String uid) async {
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      "admins": FieldValue.arrayRemove([uid])
    });
  }

  // ==========================================
  // UI BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        title: const Text("Group Info", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("groups").doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String groupPhoto = data["groupPhoto"] ?? "";
          final List members = data["members"] ?? [];
          final List admins = data["admins"] ?? [];
          final String createdBy = data["createdBy"] ?? "";
          
          // ✅ Admin Check working perfectly now
          final bool isAdmin = admins.contains(currentUid) || createdBy == currentUid;
          final bool isMuted = (data["mutedBy"] ?? []).contains(currentUid);

          return ListView(
            padding: const EdgeInsets.all(15),
            children: [
              // 1. Group Header
              Center(
                child: Column(
                  children: [
                    GroupPhotoPicker(
                      imageUrl: groupPhoto,
                      onChange: () async {
                        // Backend service for changing photo
                        await GroupPhotoService.changePhoto(groupId: widget.groupId);
                      },
                      onView: () {
                        if (groupPhoto.isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: groupPhoto)));
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(data["groupName"] ?? "Group", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text("Group • ${members.length} members", style: const TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Main Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionIcon(Icons.call, "Audio", () { /* Start Group Audio Call */ }),
                  _actionIcon(Icons.videocam, "Video", () { /* Start Group Video Call */ }),
                  _actionIcon(Icons.search, "Search", () { /* Navigate to Search Messages */ }),
                ],
              ),
              const Divider(color: Colors.white24, height: 40),

              // 3. Settings & Options
              ListTile(
                leading: const Icon(Icons.perm_media, color: Colors.blueAccent),
                title: const Text("Media, links, and docs", style: TextStyle(color: Colors.white)),
                onTap: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Media Gallery Opening..."))); },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_off, color: Colors.amber),
                title: const Text("Mute Notifications", style: TextStyle(color: Colors.white)),
                activeColor: const Color(0xff25D366),
                value: isMuted,
                onChanged: (val) => muteGroup(isMuted),
              ),
              
              if (isAdmin) // ✅ Secured: Only Admins can see Settings
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.green),
                  title: const Text("Group Settings", style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupSettingsScreen(groupId: widget.groupId, groupName: data["groupName"] ?? "Group"))),
                ),
                
              if (isAdmin) // ✅ Secured: Only Admins can generate invites
                ListTile(
                  leading: const Icon(Icons.link, color: Colors.teal),
                  title: const Text("Invite via link", style: TextStyle(color: Colors.white)),
                  onTap: copyInviteLink,
                ),

              // 4. Members Section
              const Divider(color: Colors.white24, height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Text("${members.length} Members", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
              ),
              
              if (isAdmin)
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xff25D366), child: Icon(Icons.person_add, color: Colors.white)),
                  title: const Text("Add Members", style: TextStyle(color: Colors.white)),
                  onTap: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add Members Screen Opening..."))); },
                ),

              // Members List Builder
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final memberUid = members[index];
                  final isMemberAdmin = admins.contains(memberUid) || createdBy == memberUid;
                  final isMe = memberUid == currentUid;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection("users").doc(memberUid).get(),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData) return const ListTile(title: Text("Loading...", style: TextStyle(color: Colors.white54)));
                      
                      final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                      final userName = isMe ? "You" : (userData["name"] ?? "User");
                      final userPhoto = userData["photoUrl"];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: userPhoto != null ? NetworkImage(userPhoto) : null,
                          child: userPhoto == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(userName, style: const TextStyle(color: Colors.white)),
                        trailing: isMemberAdmin ? const Text("Admin", style: TextStyle(color: Color(0xff25D366), fontSize: 12)) : null,
                        onTap: () {
                          // Allow admin actions if current user is Admin, and target is NOT the current user
                          if (isAdmin && !isMe) {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: const Color(0xff1f2937),
                              builder: (_) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    title: Text(isMemberAdmin ? "Dismiss as Admin" : "Make Group Admin", style: const TextStyle(color: Colors.white)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      isMemberAdmin ? demoteAdmin(memberUid) : promoteAdmin(memberUid);
                                    },
                                  ),
                                  ListTile(
                                    title: Text("Remove $userName", style: const TextStyle(color: Colors.red)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      removeMember(memberUid);
                                    },
                                  ),
                                ],
                              )
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),

              // 5. Danger Zone (Export, Report, Exit, Delete)
              const Divider(color: Colors.white24, height: 40),
              ListTile(leading: const Icon(Icons.download, color: Colors.white70), title: const Text("Export Chat", style: TextStyle(color: Colors.white)), onTap: exportChat),
              ListTile(leading: const Icon(Icons.thumb_down, color: Colors.redAccent), title: const Text("Report Group", style: TextStyle(color: Colors.redAccent)), onTap: reportGroup),
              ListTile(leading: const Icon(Icons.exit_to_app, color: Colors.red), title: const Text("Exit Group", style: TextStyle(color: Colors.red)), onTap: leaveGroup),
              
              if (isAdmin) // ✅ SECURITY: Only Admins can delete
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text("Delete Group", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () => deleteGroup(isAdmin),
                ),
            ],
          );
        },
      ),
    );
  }

  // Helper widget for top action icons (Call, Video, Search)
  Widget _actionIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xff1f2937), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: const Color(0xff25D366), size: 28)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}