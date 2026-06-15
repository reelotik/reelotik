import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController =
      TextEditingController();

  final List<String> selectedMembers = [];
  bool isLoading = false;

  Future<void> createGroup() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter group name")),
      );
      return;
    }

    if (selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one member")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final members = [
        currentUser.uid,
        ...selectedMembers,
      ];

      final groupRef =
          FirebaseFirestore.instance.collection("groups").doc();

      await groupRef.set({
        "groupId": groupRef.id,
        "groupName": _groupNameController.text.trim(),
        "groupPhoto": "",
        "createdBy": currentUser.uid,
        "admins": [currentUser.uid],
        "members": members,
        "createdAt": FieldValue.serverTimestamp(),
        "lastMessage": "",
      });

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Group Created")),
      );
    } catch (e) {
      debugPrint("Group create error: $e");
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        title: const Text("Create Group"),
        backgroundColor: const Color(0xff111827),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff25D366),
        onPressed: isLoading ? null : createGroup,
        child: isLoading
            ? const CircularProgressIndicator(
                color: Colors.white,
              )
            : const Icon(Icons.check),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _groupNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Group Name",
                hintStyle:
                    const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xff1f2937),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user =
                        users[index].data() as Map<String, dynamic>;

                    final uid = users[index].id;

                    if (uid == currentUid) {
                      return const SizedBox();
                    }

                    final name =
                        user["name"] ??
                        user["fullName"] ??
                        "Unknown";

                    final photo =
                        user["photoUrl"] ?? "";

                    final selected =
                        selectedMembers.contains(uid);

                    return CheckboxListTile(
                      value: selected,
                      activeColor:
                          const Color(0xff25D366),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedMembers.add(uid);
                          } else {
                            selectedMembers.remove(uid);
                          }
                        });
                      },
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      secondary: CircleAvatar(
                        backgroundImage: photo.isNotEmpty
                            ? NetworkImage(photo)
                            : null,
                        child: photo.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}