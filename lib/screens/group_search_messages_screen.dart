import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GroupSearchMessagesScreen extends StatefulWidget {
  final String groupId;

  const GroupSearchMessagesScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupSearchMessagesScreen> createState() =>
      _GroupSearchMessagesScreenState();
}

class _GroupSearchMessagesScreenState
    extends State<GroupSearchMessagesScreen> {
  final TextEditingController _searchController = TextEditingController();

  String searchText = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    return DateFormat("dd MMM, hh:mm a").format(timestamp.toDate());
  }

  IconData _messageIcon(String type) {
    switch (type) {
      case "image":
        return Icons.image;
      case "video":
        return Icons.videocam;
      case "audio":
        return Icons.mic;
      case "document":
        return Icons.insert_drive_file;
      default:
        return Icons.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),

      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        title: const Text(
          "Search Messages",
          style: TextStyle(color: Colors.white),
        ),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (v) {
                setState(() {
                  searchText = v.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Search in group...",
                hintStyle: const TextStyle(color: Colors.white54),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("groups")
                  .doc(widget.groupId)
                  .collection("messages")
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.green,
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final msg =
                      (data["message"] ?? "").toString().toLowerCase();

                  return searchText.isEmpty
                      ? false
                      : msg.contains(searchText);
                }).toList();

                if (searchText.isEmpty) {
                  return const Center(
                    child: Text(
                      "Type something to search",
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      "No messages found",
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data =
                        filtered[index].data() as Map<String, dynamic>;

                    final msg = data["message"] ?? "";
                    final senderName =
                        data["senderName"] ?? "Unknown";
                    final msgType =
                        data["messageType"] ?? "text";

                    final timestamp =
                        data["timestamp"] as Timestamp?;

                    return Card(
                      color: const Color(0xff1f2937),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(
                            _messageIcon(msgType),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          senderName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              msg,
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(timestamp),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
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