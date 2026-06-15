import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupAdminOnlySettingsScreen extends StatefulWidget {
  final String groupId;

  const GroupAdminOnlySettingsScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupAdminOnlySettingsScreen> createState() =>
      _GroupAdminOnlySettingsScreenState();
}

class _GroupAdminOnlySettingsScreenState
    extends State<GroupAdminOnlySettingsScreen> {
  bool loading = true;

  bool adminOnlyMessaging = false;
  bool adminOnlyMedia = false;
  bool adminOnlyEditInfo = true;
  bool adminOnlyAddMembers = true;
  bool adminOnlyPinMessages = true;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection("groups")
        .doc(widget.groupId)
        .get();

    final data = doc.data() ?? {};

    setState(() {
      adminOnlyMessaging = data["adminOnlyMessaging"] ?? false;
      adminOnlyMedia = data["adminOnlyMedia"] ?? false;
      adminOnlyEditInfo = data["adminOnlyEditInfo"] ?? true;
      adminOnlyAddMembers = data["adminOnlyAddMembers"] ?? true;
      adminOnlyPinMessages = data["adminOnlyPinMessages"] ?? true;
      loading = false;
    });
  }

  Future<void> updateSetting(
      String field,
      bool value,
      ) async {
    await FirebaseFirestore.instance
        .collection("groups")
        .doc(widget.groupId)
        .update({
      field: value,
    });
  }

  Widget buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xff1f2937),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        activeThumbColor: Colors.green,
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white54,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        title: const Text(
          "Admin Only Settings",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: loading
          ? const Center(
        child: CircularProgressIndicator(
          color: Colors.green,
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(15),
        children: [

          buildSwitchTile(
            title: "Admin Only Messaging",
            subtitle:
            "Only admins can send messages in group",
            value: adminOnlyMessaging,
            onChanged: (v) {
              setState(() {
                adminOnlyMessaging = v;
              });

              updateSetting(
                "adminOnlyMessaging",
                v,
              );
            },
          ),

          buildSwitchTile(
            title: "Admin Only Media",
            subtitle:
            "Only admins can send photos/videos/files",
            value: adminOnlyMedia,
            onChanged: (v) {
              setState(() {
                adminOnlyMedia = v;
              });

              updateSetting(
                "adminOnlyMedia",
                v,
              );
            },
          ),

          buildSwitchTile(
            title: "Admin Only Edit Group Info",
            subtitle:
            "Only admins can change name/photo/description",
            value: adminOnlyEditInfo,
            onChanged: (v) {
              setState(() {
                adminOnlyEditInfo = v;
              });

              updateSetting(
                "adminOnlyEditInfo",
                v,
              );
            },
          ),

          buildSwitchTile(
            title: "Admin Only Add Members",
            subtitle:
            "Only admins can add new members",
            value: adminOnlyAddMembers,
            onChanged: (v) {
              setState(() {
                adminOnlyAddMembers = v;
              });

              updateSetting(
                "adminOnlyAddMembers",
                v,
              );
            },
          ),

          buildSwitchTile(
            title: "Admin Only Pin Messages",
            subtitle:
            "Only admins can pin or unpin messages",
            value: adminOnlyPinMessages,
            onChanged: (v) {
              setState(() {
                adminOnlyPinMessages = v;
              });

              updateSetting(
                "adminOnlyPinMessages",
                v,
              );
            },
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "GroupChatScreen me message send karne se pehle in Firestore fields ko check karna hoga.",
                    style: TextStyle(
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}