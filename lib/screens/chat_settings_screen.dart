import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  bool enterToSend = true;
  bool mediaAutoDownload = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      enterToSend = prefs.getBool("enterToSend") ?? true;
      mediaAutoDownload = prefs.getBool("mediaAutoDownload") ?? true;
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
        title: const Text("Chats", style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            value: enterToSend,
            activeThumbColor: const Color(0xff25D366),
            title: const Text("Enter is Send", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Enter key will send your message", style: TextStyle(color: Colors.white54)),
            onChanged: (v) {
              setState(() => enterToSend = v);
              _updateSetting("enterToSend", v);
            },
          ),
          SwitchListTile(
            value: mediaAutoDownload,
            activeThumbColor: const Color(0xff25D366),
            title: const Text("Auto Download Media", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Automatically download photos and videos", style: TextStyle(color: Colors.white54)),
            onChanged: (v) {
              setState(() => mediaAutoDownload = v);
              _updateSetting("mediaAutoDownload", v);
            },
          ),
        ],
      ),
    );
  }
}