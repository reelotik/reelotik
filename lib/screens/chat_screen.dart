import 'package:flutter/material.dart';
import 'extra_tabs.dart'; // Make sure extra_tabs.dart isi directory mein hai

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // 4 tabs ka count yahan defined hai
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xff111827),
          title: const Text("Reelotik"),
          bottom: const TabBar(
            indicatorColor: Color(0xff25D366),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Chats"),
              Tab(text: "Contacts"),
              Tab(text: "Updates"),
              Tab(text: "Calls"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RecentChatsTab(), // 1st: Active Chats
            ContactsTab(),    // 2nd: All Users
            UpdatesTab(),     // 3rd: Updates
            CallsTab(),       // 4th: Calls
          ],
        ),
      ),
    );
  }
}