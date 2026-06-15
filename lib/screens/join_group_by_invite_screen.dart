// lib/screens/join_group_by_invite_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'group_chat_screen.dart';

class JoinGroupByInviteScreen extends StatefulWidget {
  final String groupId;

  const JoinGroupByInviteScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<JoinGroupByInviteScreen> createState() =>
      _JoinGroupByInviteScreenState();
}

class _JoinGroupByInviteScreenState
    extends State<JoinGroupByInviteScreen> {
  bool loading = true;
  bool joining = false;

  Map<String, dynamic>? groupData;

  @override
  void initState() {
    super.initState();
    loadGroup();
  }

  Future<void> loadGroup() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("groups")
          .doc(widget.groupId)
          .get();

      if (doc.exists) {
        groupData = doc.data();
      }

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> joinGroup() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please login first"),
          ),
        );
        return;
      }

      setState(() {
        joining = true;
      });

      final groupRef = FirebaseFirestore.instance
          .collection("groups")
          .doc(widget.groupId);

      final groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        throw Exception("Group not found");
      }

      final data = groupDoc.data()!;

      List members = data["members"] ?? [];

      if (!members.contains(user.uid)) {
        await groupRef.update({
          "members": FieldValue.arrayUnion([user.uid]),
        });
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: widget.groupId,
            groupName:
                data["groupName"] ??
                data["name"] ??
                "Group",
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        joining = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        title: const Text(
          "Join Group",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xff25D366),
              ),
            )
          : groupData == null
              ? const Center(
                  child: Text(
                    "Group Not Found",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                )
              : FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection("groups")
                      .doc(widget.groupId)
                      .get(),
                  builder: (context, snapshot) {
                    final data = groupData!;

                    final List members =
                        data["members"] ?? [];

                    final bool alreadyMember =
                        members.contains(currentUid);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor:
                                const Color(0xff25D366),
                            backgroundImage:
                                (data["groupPhoto"] ?? "")
                                        .toString()
                                        .isNotEmpty
                                    ? NetworkImage(
                                        data["groupPhoto"],
                                      )
                                    : null,
                            child:
                                (data["groupPhoto"] ?? "")
                                        .toString()
                                        .isEmpty
                                    ? const Icon(
                                        Icons.group,
                                        color: Colors.white,
                                        size: 50,
                                      )
                                    : null,
                          ),

                          const SizedBox(height: 20),

                          Text(
                            data["groupName"] ??
                                data["name"] ??
                                "Group",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            data["description"] ?? "",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                            ),
                          ),

                          const SizedBox(height: 25),

                          Container(
                            padding:
                                const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.people,
                                      color:
                                          Color(0xff25D366),
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    Text(
                                      "${members.length} Members",
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.link,
                                      color:
                                          Color(0xff25D366),
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    Expanded(
                                      child: Text(
                                        widget.groupId,
                                        style:
                                            const TextStyle(
                                          color: Colors
                                              .white54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          alreadyMember
                              ? SizedBox(
                                  width:
                                      double.infinity,
                                  height: 55,
                                  child:
                                      ElevatedButton(
                                    style:
                                        ElevatedButton
                                            .styleFrom(
                                      backgroundColor:
                                          Colors.blue,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              GroupChatScreen(
                                            groupId:
                                                widget
                                                    .groupId,
                                            groupName:
                                                data["groupName"] ??
                                                    "Group",
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      "Open Group",
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  width:
                                      double.infinity,
                                  height: 55,
                                  child:
                                      ElevatedButton(
                                    style:
                                        ElevatedButton
                                            .styleFrom(
                                      backgroundColor:
                                          const Color(
                                        0xff25D366,
                                      ),
                                    ),
                                    onPressed: joining
                                        ? null
                                        : joinGroup,
                                    child: joining
                                        ? const CircularProgressIndicator(
                                            color:
                                                Colors
                                                    .white,
                                          )
                                        : const Text(
                                            "Join Group",
                                            style:
                                                TextStyle(
                                              color: Colors
                                                  .black,
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                            ),
                                          ),
                                  ),
                                ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}