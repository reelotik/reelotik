import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_detail_screen.dart';

// 1. --- RecentChatsTab (With FutureBuilder for names) ---
class RecentChatsTab extends StatelessWidget {
  const RecentChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text("User not logged in", style: TextStyle(color: Colors.white)));
    }

    return Container(
      color: const Color(0xff0D1117),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("chats")
            .where("participants", arrayContains: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No active chats", style: TextStyle(color: Colors.white)));

          final chats = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chatData = chats[index].data() as Map<String, dynamic>;
              final participants = List<String>.from(chatData['participants'] ?? []);
              final otherUserId = participants.firstWhere((id) => id != currentUser.uid, orElse: () => "Unknown");

              return Card(
                color: const Color(0xff1F2937),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xff25D366), child: Icon(Icons.person, color: Colors.white)),
                  title: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection("users").doc(otherUserId).get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) return const Text("Loading...", style: TextStyle(color: Colors.white70));
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      return Text(
                        userData?["name"] ?? "Unknown User",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                  subtitle: Text(chatData["lastMessage"] ?? "", style: const TextStyle(color: Colors.white70)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(name: "User", userId: otherUserId))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 2. --- ContactsTab ---
class ContactsTab extends StatelessWidget {
  const ContactsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!.docs.where((doc) => doc.id != FirebaseAuth.instance.currentUser?.uid).toList();
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(userData['name'] ?? 'User'),
              subtitle: Text(userData['email'] ?? ''),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(name: userData['name'], userId: userDoc.id))),
            );
          },
        );
      },
    );
  }
}

// 3. --- Placeholder Tabs ---
class CommunityTab extends StatelessWidget { const CommunityTab({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Community")); }
class UpdatesTab extends StatelessWidget { const UpdatesTab({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Updates")); }
class CallsTab extends StatelessWidget { const CallsTab({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Calls")); }