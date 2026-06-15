import 'package:flutter/material.dart';

class AboutPrivacyScreen extends StatefulWidget {
  const AboutPrivacyScreen({super.key});

  @override
  State<AboutPrivacyScreen> createState() =>
      _AboutPrivacyScreenState();
}

class _AboutPrivacyScreenState
    extends State<AboutPrivacyScreen> {
  String selectedValue = "everyone";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        title: const Text(
          "About Privacy",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          RadioListTile(
            value: "everyone",
            groupValue: selectedValue,
            activeColor: const Color(0xff25D366),
            title: const Text(
              "Everyone",
              style: TextStyle(color: Colors.white),
            ),
            onChanged: (value) {
              setState(() => selectedValue = value!);
            },
          ),
          RadioListTile(
            value: "contacts",
            groupValue: selectedValue,
            activeColor: const Color(0xff25D366),
            title: const Text(
              "My Contacts",
              style: TextStyle(color: Colors.white),
            ),
            onChanged: (value) {
              setState(() => selectedValue = value!);
            },
          ),
          RadioListTile(
            value: "nobody",
            groupValue: selectedValue,
            activeColor: const Color(0xff25D366),
            title: const Text(
              "Nobody",
              style: TextStyle(color: Colors.white),
            ),
            onChanged: (value) {
              setState(() => selectedValue = value!);
            },
          ),
        ],
      ),
    );
  }
}