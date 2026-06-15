import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_search_messages_screen.dart';
import 'group_media_screen.dart';
import 'group_pinned_messages_screen.dart';
import 'group_export_chat_screen.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupSettingsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  // Null-check operator use kiya hai taaki crash na ho
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  void showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // --- Actions ---
  Future<void> muteGroup() async {
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection("groups")
        .doc(widget.groupId)
        .update({
      "mutedBy": FieldValue.arrayUnion([uid]),
    });
    showFeedback("Group muted");
  }

  Future<void> unMuteGroup() async {
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection("groups")
        .doc(widget.groupId)
        .update({
      "mutedBy": FieldValue.arrayRemove([uid]),
    });
    showFeedback("Group unmuted");
  }

  Future<void> clearChat() async {
    if (uid == null) return;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear Chat"),
        content: const Text("Are you sure you want to clear this chat?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection("groups")
          .doc(widget.groupId)
          .update({
        "clearedBy.$uid": FieldValue.serverTimestamp(),
      });
      showFeedback("Chat cleared");
    }
  }

  Future<void> blockGroup() async {
    if (uid == null) return;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Block Group"),
        content: const Text("Are you sure you want to block this group?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Block", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection("groups")
          .doc(widget.groupId)
          .update({
        "blockedBy": FieldValue.arrayUnion([uid]),
      });
      showFeedback("Group blocked");
    }
  }

  Future<void> reportGroup() async {
    if (uid == null) return;
    await FirebaseFirestore.instance.collection("reports").add({
      "groupId": widget.groupId,
      "reportedBy": uid,
      "timestamp": FieldValue.serverTimestamp(),
    });
    showFeedback("Group reported to admin");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff111827),
        title: Text(
          widget.groupName, // Dynamic group name
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.search, color: Colors.white),
            title: const Text("Search Messages", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupSearchMessagesScreen(groupId: widget.groupId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.volume_off, color: Colors.orange),
            title: const Text("Mute Group", style: TextStyle(color: Colors.white)),
            onTap: muteGroup,
          ),
          ListTile(
            leading: const Icon(Icons.volume_up, color: Colors.green),
            title: const Text("Unmute Group", style: TextStyle(color: Colors.white)),
            onTap: unMuteGroup,
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.blue),
            title: const Text("Clear Chat", style: TextStyle(color: Colors.white)),
            onTap: clearChat,
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.green),
            title: const Text("Export Chat", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupExportChatScreen(
                    groupId: widget.groupId,
                    groupName: widget.groupName, // Ye parameter pass karna zaroori hai
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: const Text("Block Group", style: TextStyle(color: Colors.white)),
            onTap: blockGroup,
          ),
          ListTile(
            leading: const Icon(Icons.report, color: Colors.red),
            title: const Text("Report Group", style: TextStyle(color: Colors.white)),
            onTap: reportGroup,
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.purple),
            title: const Text("Group Media", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupMediaScreen(groupId: widget.groupId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.push_pin, color: Colors.amber),
            title: const Text("Pinned Messages", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupPinnedMessagesScreen(groupId: widget.groupId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}