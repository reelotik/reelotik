// ignore_for_file: use_build_context_synchronously, empty_catches

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- SCREENS ---
import 'group_search_messages_screen.dart';
import 'group_media_screen.dart';
import 'group_pinned_messages_screen.dart';
import 'group_export_chat_screen.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupSettingsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  void showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ==========================================
  // CORE BACKEND ACTIONS
  // ==========================================

  Future<void> toggleMuteGroup(bool currentlyMuted) async {
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection("groups")
        .doc(widget.groupId)
        .update({
      "mutedBy": currentlyMuted 
          ? FieldValue.arrayRemove([uid]) 
          : FieldValue.arrayUnion([uid]),
    });
    showFeedback(currentlyMuted ? "Group unmuted" : "Group muted");
  }

  Future<void> toggleAdminOnlyMessages(bool currentSetting) async {
    await FirebaseFirestore.instance
        .collection("groups")
        .doc(widget.groupId)
        .update({
      "adminOnlyMessages": !currentSetting,
    });
    showFeedback(!currentSetting ? "Only admins can send messages" : "All members can send messages");
  }

  Future<void> clearChat() async {
    if (uid == null) return;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xff1f2937),
        title: const Text("Clear Chat", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to clear this chat?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection("groups")
          .doc(widget.groupId)
          .update({
        "clearedBy.$uid": FieldValue.serverTimestamp(),
      });
      showFeedback("Chat cleared");
    }
  }

  Future<void> toggleBlockGroup(bool currentlyBlocked) async {
    if (uid == null) return;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xff1f2937),
        title: Text(currentlyBlocked ? "Unblock Group" : "Block Group", style: const TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to ${currentlyBlocked ? 'unblock' : 'block'} this group?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(currentlyBlocked ? "Unblock" : "Block", style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection("groups")
          .doc(widget.groupId)
          .update({
        "blockedBy": currentlyBlocked 
            ? FieldValue.arrayRemove([uid]) 
            : FieldValue.arrayUnion([uid]),
      });
      showFeedback(currentlyBlocked ? "Group unblocked" : "Group blocked");
    }
  }

  Future<void> reportGroup() async {
    if (uid == null) return;
    await FirebaseFirestore.instance.collection("reports").add({
      "groupId": widget.groupId,
      "reportedBy": uid,
      "timestamp": FieldValue.serverTimestamp(),
    });
    showFeedback("Group reported cleanly");
  }

  void copyInviteLink() {
    final String inviteLink = "https://reelotik.com/invite/${widget.groupId}";
    Clipboard.setData(ClipboardData(text: inviteLink));
    showFeedback("Invite link copied!");
  }

  // ==========================================
  // UI BUILD WITH REAL-TIME STREAM
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff111827),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.groupName,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("groups").doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator(color: Color(0xff25D366)));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List admins = data["admins"] ?? [];
          final String createdBy = data["createdBy"] ?? "";
          
          // Live status variables
          final bool isAdmin = admins.contains(uid) || createdBy == uid;
          final bool isMuted = (data["mutedBy"] ?? []).contains(uid);
          final bool isBlocked = (data["blockedBy"] ?? []).contains(uid);
          final bool adminOnlyMessages = data["adminOnlyMessages"] ?? false;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              // --- SECTION 1: SEARCH & MEDIA ---
              _buildSectionHeader("Search & Media"),
              ListTile(
                leading: const Icon(Icons.search, color: Colors.white),
                title: const Text("Search Messages", style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupSearchMessagesScreen(groupId: widget.groupId))),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.purpleAccent),
                title: const Text("Group Media", style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupMediaScreen(groupId: widget.groupId))),
              ),
              ListTile(
                leading: const Icon(Icons.push_pin, color: Colors.amber),
                title: const Text("Pinned Messages", style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupPinnedMessagesScreen(groupId: widget.groupId))),
              ),

              const Divider(color: Colors.white12, height: 30),

              // --- SECTION 2: CHAT OPTIONS ---
              _buildSectionHeader("Chat Options"),
              SwitchListTile(
                secondary: Icon(isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.green),
                title: const Text("Mute Notifications", style: TextStyle(color: Colors.white)),
                value: isMuted,
                activeColor: const Color(0xff25D366),
                onChanged: (val) => toggleMuteGroup(isMuted),
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services, color: Colors.blueAccent),
                title: const Text("Clear Chat Messages", style: TextStyle(color: Colors.white)),
                onTap: clearChat,
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.tealAccent),
                title: const Text("Export Chat History", style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupExportChatScreen(groupId: widget.groupId, groupName: widget.groupName))),
              ),

              const Divider(color: Colors.white12, height: 30),

              // --- SECTION 3: ADMIN CONTROLS (Live Conditional Rendering) ---
              if (isAdmin) ...[
                _buildSectionHeader("Admin Preferences"),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_person, color: Colors.redAccent),
                  title: const Text("Admins Only Messages", style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Only group admins can broadcast messages", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: adminOnlyMessages,
                  activeColor: const Color(0xff25D366),
                  onChanged: (val) => toggleAdminOnlyMessages(adminOnlyMessages),
                ),
                ListTile(
                  leading: const Icon(Icons.link, color: Colors.blue),
                  title: const Text("Copy Group Invite Link", style: TextStyle(color: Colors.white)),
                  onTap: copyInviteLink,
                ),
                const Divider(color: Colors.white12, height: 30),
              ],

              // --- SECTION 4: SECURITY & DANGER ZONE ---
              _buildSectionHeader("Security & Danger Zone"),
              ListTile(
                leading: Icon(Icons.block, color: isBlocked ? Colors.green : Colors.red),
                title: Text(isBlocked ? "Unblock Group" : "Block Group", style: const TextStyle(color: Colors.white)),
                onTap: () => toggleBlockGroup(isBlocked),
              ),
              ListTile(
                leading: const Icon(Icons.report, color: Colors.orangeAccent),
                title: const Text("Report Group Content", style: TextStyle(color: Colors.white)),
                onTap: reportGroup,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(color: Color(0xff25D366), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }
}