import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatDetailScreen extends StatefulWidget {
  final String name;
  final String userId;

  const ChatDetailScreen({
    Key? key,
    required this.name,
    required this.userId,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController controller = TextEditingController();

  String get chatRoomId {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    List<String> ids = [currentUserId, widget.userId];
    ids.sort();
    return ids.join("_");
  }

  Future<void> sendMessage() async {
    if (controller.text.trim().isEmpty) return;

    final messageText = controller.text.trim();
    controller.clear();

    // 1. Message save karo
    await FirebaseFirestore.instance
        .collection("chats")
        .doc(chatRoomId)
        .collection("messages")
        .add({
      "text": messageText,
      "senderId": FirebaseAuth.instance.currentUser!.uid,
      "timestamp": FieldValue.serverTimestamp(),
    });

    // 2. Parent chat document update karo (lastMessage & metadata)
    await FirebaseFirestore.instance
        .collection("chats")
        .doc(chatRoomId)
        .set({
      "participants": [
        FirebaseAuth.instance.currentUser!.uid,
        widget.userId
      ],
      "lastMessage": messageText,
      "lastMessageTime": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print("MESSAGE SENT & CHAT DOC UPDATED: $chatRoomId");
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff111827),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text("Online", style: TextStyle(color: Colors.green, fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("chats")
                  .doc(chatRoomId)
                  .collection("messages")
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  print("STREAM ROOM ID: $chatRoomId");
                  print("DOCS: ${snapshot.data!.docs.length}");
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    bool isMe = data["senderId"] == FirebaseAuth.instance.currentUser!.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xff25D366) : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(data["text"], style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xff111827),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onSubmitted: (_) => sendMessage(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Type a message",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xff1F2937),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: const Color(0xff25D366),
                  onPressed: sendMessage,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}