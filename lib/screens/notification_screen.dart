import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool messageNotification = true;
  bool groupNotification = true;
  bool vibration = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      messageNotification = prefs.getBool("messageNotification") ?? true;
      groupNotification = prefs.getBool("groupNotification") ?? true;
      vibration = prefs.getBool("vibration") ?? true;
    });
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Notifications", style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            value: messageNotification,
            activeThumbColor: const Color(0xff25D366),
            title: const Text("Message Notifications", style: TextStyle(color: Colors.white)),
            onChanged: (v) {
              setState(() => messageNotification = v);
              _updateSetting("messageNotification", v);
            },
          ),
          SwitchListTile(
            value: groupNotification,
            activeThumbColor: const Color(0xff25D366),
            title: const Text("Group Notifications", style: TextStyle(color: Colors.white)),
            onChanged: (v) {
              setState(() => groupNotification = v);
              _updateSetting("groupNotification", v);
            },
          ),
          SwitchListTile(
            value: vibration,
            activeThumbColor: const Color(0xff25D366),
            title: const Text("Vibration", style: TextStyle(color: Colors.white)),
            onChanged: (v) {
              setState(() => vibration = v);
              _updateSetting("vibration", v);
            },
          ),
        ],
      ),
    );
  }
}