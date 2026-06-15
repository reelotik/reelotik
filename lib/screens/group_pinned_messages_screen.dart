import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GroupPinnedMessagesScreen extends StatefulWidget {
  final String groupId;

  const GroupPinnedMessagesScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupPinnedMessagesScreen> createState() =>
      _GroupPinnedMessagesScreenState();
}

class _GroupPinnedMessagesScreenState
    extends State<GroupPinnedMessagesScreen> {
  final currentUid =
      FirebaseAuth.instance.currentUser?.uid ?? "";

  Future<void> unPinMessage(
    String messageId,
  ) async {
    await FirebaseFirestore.instance
        .collection("groups")
        .doc(widget.groupId)
        .collection("messages")
        .doc(messageId)
        .update({
      "isPinned": false,
      "pinnedBy": null,
      "pinnedAt": null,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Message Unpinned"),
        ),
      );
    }
  }

  Color getMessageColor(bool isMe) {
    return isMe
        ? const Color(0xff25D366)
        : const Color(0xff1f2937);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),

      appBar: AppBar(
        backgroundColor: const Color(0xff111827),
        title: const Text(
          "Pinned Messages",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("groups")
            .doc(widget.groupId)
            .collection("messages")
            .where(
              "isPinned",
              isEqualTo: true,
            )
            .orderBy(
              "timestamp",
              descending: true,
            )
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xff25D366),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.push_pin_outlined,
                    size: 80,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 15),
                  Text(
                    "No Pinned Messages",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xff25D366),
            onRefresh: () async {},
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];

                final data =
                    doc.data()
                        as Map<String, dynamic>;

                final senderId =
                    data["senderId"] ?? "";

                final senderName =
                    data["senderName"] ??
                        "Unknown User";

                final message =
                    data["message"] ?? "";

                final type =
                    data["type"] ?? "text";

                final isMe =
                    senderId == currentUid;

                final timestamp =
                    data["timestamp"]
                        as Timestamp?;

                String time = "";

                if (timestamp != null) {
                  time = DateFormat(
                    "dd MMM yyyy • hh:mm a",
                  ).format(
                    timestamp.toDate(),
                  );
                }

                return Container(
                  margin:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Card(
                    color: getMessageColor(isMe),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.push_pin,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(
                                  width: 5),
                              Expanded(
                                child: Text(
                                  senderName,
                                  style:
                                      TextStyle(
                                    color: isMe
                                        ? Colors.black
                                        : Colors
                                            .white,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),

                              PopupMenuButton(
                                color:
                                    Colors.white,
                                onSelected:
                                    (value) {
                                  if (value ==
                                      "unpin") {
                                    unPinMessage(
                                      doc.id,
                                    );
                                  }
                                },
                                itemBuilder:
                                    (context) =>
                                        const [
                                  PopupMenuItem(
                                    value:
                                        "unpin",
                                    child: Text(
                                      "Unpin",
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          if (type == "text")
                            Text(
                              message,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.black
                                    : Colors
                                        .white,
                                fontSize: 15,
                              ),
                            ),

                          if (type != "text")
                            Container(
                              padding:
                                  const EdgeInsets
                                      .all(10),
                              decoration:
                                  BoxDecoration(
                                color: Colors
                                    .black12,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                            10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons
                                        .attach_file,
                                  ),
                                  const SizedBox(
                                      width:
                                          8),
                                  Expanded(
                                    child: Text(
                                      type
                                          .toUpperCase(),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(
                            height: 8,
                          ),

                          Align(
                            alignment:
                                Alignment
                                    .centerRight,
                            child: Text(
                              time,
                              style:
                                  TextStyle(
                                color: isMe
                                    ? Colors
                                        .black87
                                    : Colors
                                        .white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}