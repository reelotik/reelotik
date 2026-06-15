import 'package:flutter/material.dart';
import '../services/privacy_service.dart';

class LastSeenPrivacyScreen extends StatefulWidget {
  const LastSeenPrivacyScreen({super.key});

  @override
  State<LastSeenPrivacyScreen> createState() =>
      _LastSeenPrivacyScreenState();
}

class _LastSeenPrivacyScreenState
    extends State<LastSeenPrivacyScreen> {

  String selected = "everyone";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Last Seen")),
      body: Column(
        children: [
          RadioListTile(
            value: "everyone",
            groupValue: selected,
            title: const Text("Everyone"),
            onChanged: (v) async {
              selected = v!;
              setState(() {});
              await PrivacyService.updateSetting(
                "lastSeenPrivacy",
                v,
              );
            },
          ),
          RadioListTile(
            value: "contacts",
            groupValue: selected,
            title: const Text("My Contacts"),
            onChanged: (v) async {
              selected = v!;
              setState(() {});
              await PrivacyService.updateSetting(
                "lastSeenPrivacy",
                v,
              );
            },
          ),
          RadioListTile(
            value: "nobody",
            groupValue: selected,
            title: const Text("Nobody"),
            onChanged: (v) async {
              selected = v!;
              setState(() {});
              await PrivacyService.updateSetting(
                "lastSeenPrivacy",
                v,
              );
            },
          ),
        ],
      ),
    );
  }
}