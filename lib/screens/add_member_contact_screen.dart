import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddMemberContactScreen extends StatefulWidget {
  final String groupId;

  const AddMemberContactScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<AddMemberContactScreen> createState() =>
      _AddMemberContactScreenState();
}

class _AddMemberContactScreenState
    extends State<AddMemberContactScreen> {
  String searchText = "";

  final Set<String> selectedUsers = {};

  Future<void> addMembers() async {
    if (selectedUsers.isEmpty) return;

    await FirebaseFirestore.instance
        .collection("groups")
        .doc(widget.groupId)
        .update({
      "members": FieldValue.arrayUnion(
        selectedUsers.toList(),
      ),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Members Added Successfully"),
      ),
    );

    Navigator.pop(context);
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
          TextButton(
            onPressed: addMembers,
            child: const Text(
              "ADD",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  searchText = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Search User",
                hintStyle:
                    const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.green,
                ),
                filled: true,
                fillColor: const Color(0xff1f2937),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
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
                    groupSnapshot.data!.data()
                        as Map<String, dynamic>;

                final members =
                    List<String>.from(
                  groupData["members"] ?? [],
                );

                return StreamBuilder<QuerySnapshot>(
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

                    final filtered = users.where((doc) {
                      final data = doc.data()
                          as Map<String, dynamic>;

                      final uid = doc.id;

                      if (members.contains(uid)) {
                        return false;
                      }

                      final name =
                          (data["fullName"] ?? "")
                              .toString()
                              .toLowerCase();

                      final phone =
                          (data["phone"] ?? "")
                              .toString()
                              .toLowerCase();

                      return searchText.isEmpty ||
                          name.contains(searchText) ||
                          phone.contains(searchText);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          "No User Found",
                          style: TextStyle(
                            color: Colors.white54,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final userDoc =
                            filtered[index];

                        final data =
                            userDoc.data()
                                as Map<String, dynamic>;

                        final uid = userDoc.id;

                        final name =
                            data["fullName"] ??
                                "User";

                        final phone =
                            data["phone"] ?? "";

                        final photoUrl =
                            data["photoUrl"] ?? "";

                        final isSelected =
                            selectedUsers.contains(
                                uid);

                        return CheckboxListTile(
                          value: isSelected,
                          activeColor:
                              Colors.green,
                          tileColor:
                              const Color(
                                  0xff161B22),
                          secondary:
                              CircleAvatar(
                            backgroundImage:
                                photoUrl
                                        .toString()
                                        .isNotEmpty
                                    ? NetworkImage(
                                        photoUrl)
                                    : null,
                            child: photoUrl
                                    .toString()
                                    .isEmpty
                                ? const Icon(
                                    Icons.person)
                                : null,
                          ),
                          title: Text(
                            name,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            phone,
                            style:
                                const TextStyle(
                              color: Colors
                                  .white54,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (value ==
                                  true) {
                                selectedUsers
                                    .add(uid);
                              } else {
                                selectedUsers
                                    .remove(uid);
                              }
                            });
                          },
                        );
                      },
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