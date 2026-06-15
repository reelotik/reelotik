import 'package:flutter/material.dart';
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
  // ... (Existing methods: leaveGroup, deleteGroup, etc. remain here)
  Future<void> leaveGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      "members": FieldValue.arrayRemove([user.uid]),
    });
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> deleteGroup() async {
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).delete();
    if (mounted) Navigator.pop(context);
  }

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
          final isAdmin = admins.contains(FirebaseAuth.instance.currentUser!.uid) || data["createdBy"] == FirebaseAuth.instance.currentUser!.uid;

          return ListView(
            padding: const EdgeInsets.all(15),
            children: [
              Center(
                child: Column(
                  children: [
                    // ✅ Updated: GroupPhotoPicker
                    GroupPhotoPicker(
                      imageUrl: groupPhoto,
                      onChange: () async {
                        await GroupPhotoService.changePhoto(groupId: widget.groupId);
                      },
                      onView: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: groupPhoto)),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(data["groupName"] ?? "Group", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.green),
                title: const Text("Group Settings", style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupSettingsScreen(groupId: widget.groupId, groupName: data["groupName"] ?? "Group"))),
              ),
              // ... (Remaining ListTiles: Search, Members, etc.)
              ElevatedButton.icon(icon: const Icon(Icons.exit_to_app), label: const Text("Exit Group"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: leaveGroup),
            ],
          );
        },
      ),
    );
  }
}