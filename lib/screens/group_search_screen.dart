import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupSearchScreen extends StatefulWidget {
  final String groupId;

  const GroupSearchScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupSearchScreen> createState() => _GroupSearchScreenState();
}

class _GroupSearchScreenState extends State<GroupSearchScreen> {
  String searchText = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        title: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Search Messages...",
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {
              searchText = value.toLowerCase();
            });
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("groups")
            .doc(widget.groupId)
            .collection("messages")
            .orderBy("timestamp", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          final filtered = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final msg =
                (data["message"] ?? "").toString().toLowerCase();

            return msg.contains(searchText);
          }).toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Text(
                "No Results",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final data =
                  filtered[index].data() as Map<String, dynamic>;

              return ListTile(
                title: Text(
                  data["message"] ?? "",
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  data["senderName"] ?? "User",
                  style: const TextStyle(
                    color: Color(0xff25D366),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}