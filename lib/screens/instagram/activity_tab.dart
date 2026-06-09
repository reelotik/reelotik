import 'package:flutter/material.dart';

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        ListTile(
          leading: CircleAvatar(
            child: Icon(Icons.favorite, color: Colors.red),
          ),
          title: Text("Rahul liked your reel"),
          subtitle: Text("2 min ago"),
        ),
        ListTile(
          leading: CircleAvatar(
            child: Icon(Icons.person_add, color: Colors.blue),
          ),
          title: Text("Amit started following you"),
          subtitle: Text("10 min ago"),
        ),
        ListTile(
          leading: CircleAvatar(
            child: Icon(Icons.comment, color: Colors.green),
          ),
          title: Text("Manish commented on your reel"),
          subtitle: Text("30 min ago"),
        ),
      ],
    );
  }
}