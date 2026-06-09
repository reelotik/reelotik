import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
      ),
      body: ListView(
        children: const [

          ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.favorite, color: Colors.red),
            ),
            title: Text("Aman liked your post"),
            subtitle: Text("2 minutes ago"),
          ),

          Divider(),

          ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.comment, color: Colors.blue),
            ),
            title: Text("Rohit commented on your reel"),
            subtitle: Text("10 minutes ago"),
          ),

          Divider(),

          ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.person_add, color: Colors.green),
            ),
            title: Text("Priya started following you"),
            subtitle: Text("1 hour ago"),
          ),

          Divider(),

          ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.video_library),
            ),
            title: Text("Your reel reached 1K views"),
            subtitle: Text("Today"),
          ),
        ],
      ),
    );
  }
}