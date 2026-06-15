import 'package:flutter/material.dart';

class GroupExportChatScreen extends StatelessWidget {
  final String groupId;
  final String groupName; // Yeh add kiya

  const GroupExportChatScreen({
    super.key,
    required this.groupId,
    required this.groupName, // Yeh constructor mein add kiya
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        title: Text("Export: $groupName"), // Group name show kar sakte hain
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Exporting for: $groupName", style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Yahan apna logic dalna
              },
              child: const Text("Export as TXT"),
            ),
          ],
        ),
      ),
    );
  }
}