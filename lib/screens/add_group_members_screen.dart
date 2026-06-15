import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddGroupMembersScreen extends StatefulWidget {
  final String groupId;

  const AddGroupMembersScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<AddGroupMembersScreen> createState() =>
      _AddGroupMembersScreenState();
}

class _AddGroupMembersScreenState
    extends State<AddGroupMembersScreen> {
  String searchQuery = "";
  bool isLoading = false;

  final List<String> selectedUsers = [];

  Future<void> addMembers() async {
    if (selectedUsers.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    await FirebaseFirestore.instance
        .collection("groups")
        .doc(widget.groupId)
        .update({
      "members": FieldValue.arrayUnion(selectedUsers),
    });

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Members Added"),
      ),
    );

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),

      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        title: const Text(
          "Add Members",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : addMembers,
            icon: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.check,
                    color: Colors.white,
                  ),
          )
        ],
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("groups")
            .doc(widget.groupId)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (!groupSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final groupData =
              groupSnapshot.data!.data() as Map<String, dynamic>;

          final List members =
              groupData["members"] ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search User",
                    hintStyle: const TextStyle(
                      color: Colors.white54,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white54,
                    ),
                    filled: true,
                    fillColor: const Color(0xff1f2937),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(15),
                      borderSide: BorderSide.none,
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
                        child:
                            CircularProgressIndicator(),
                      );
                    }

                    final users = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final userDoc = users[index];

                        final uid = userDoc.id;

                        if (members.contains(uid)) {
                          return const SizedBox();
                        }

                        final data = userDoc.data()
                            as Map<String, dynamic>;

                        final name =
                            data["fullName"] ??
                                data["name"] ??
                                "Unknown";

                        final photo =
                            data["photoUrl"] ?? "";

                        if (searchQuery.isNotEmpty &&
                            !name
                                .toLowerCase()
                                .contains(searchQuery)) {
                          return const SizedBox();
                        }

                        bool selected =
                            selectedUsers.contains(uid);

                        return CheckboxListTile(
                          value: selected,

                          activeColor:
                              Colors.green,

                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedUsers.add(uid);
                              } else {
                                selectedUsers
                                    .remove(uid);
                              }
                            });
                          },

                          title: Text(
                            name,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                            ),
                          ),

                          secondary:
                              CircleAvatar(
                            backgroundImage:
                                photo.isNotEmpty
                                    ? NetworkImage(
                                        photo)
                                    : null,
                            child:
                                photo.isEmpty
                                    ? const Icon(
                                        Icons
                                            .person,
                                      )
                                    : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}