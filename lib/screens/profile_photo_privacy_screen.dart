import 'package:flutter/material.dart';

class ProfilePhotoPrivacyScreen extends StatefulWidget {
  const ProfilePhotoPrivacyScreen({super.key});

  @override
  State<ProfilePhotoPrivacyScreen> createState() =>
      _ProfilePhotoPrivacyScreenState();
}

class _ProfilePhotoPrivacyScreenState
    extends State<ProfilePhotoPrivacyScreen> {
  String selectedValue = "everyone";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        title: const Text(
          "Profile Photo Privacy",
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