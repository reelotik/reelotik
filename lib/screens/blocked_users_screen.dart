import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Blocked Users"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>;

          final blocked =
              List<String>.from(data["blockedUsers"] ?? []);

          if (blocked.isEmpty) {
            return const Center(
              child: Text("No Blocked Users"),
            );
          }

          return ListView.builder(
            itemCount: blocked.length,
            itemBuilder: (_, i) {
              return ListTile(
                title: Text(blocked[i]),
                trailing: IconButton(
                  icon: const Icon(Icons.lock_open),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection("users")
                        .doc(uid)
                        .update({
                      "blockedUsers":
                          FieldValue.arrayRemove([
                        blocked[i]
                      ])
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}