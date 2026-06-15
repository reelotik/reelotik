import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Naye Imports
import 'blocked_users_screen.dart';
import 'app_lock_screen.dart';
import 'last_seen_privacy_screen.dart';
import 'profile_photo_privacy_screen.dart';
import 'about_privacy_screen.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Settings State (Read-only for display purposes)
  String lastSeenPrivacy = "Loading...";
  String profilePhotoPrivacy = "Loading...";
  String aboutPrivacy = "Loading...";
  bool isAppLockEnabled = false;
  int blockedUsersCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchPrivacySettings();
  }

  // --- FETCH SETTINGS FOR DISPLAY ---
  Future<void> _fetchPrivacySettings() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection("users").doc(user!.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      if (mounted) {
        setState(() {
          lastSeenPrivacy = data['lastSeenPrivacy'] ?? "everyone";
          profilePhotoPrivacy = data['profilePhotoPrivacy'] ?? "everyone";
          aboutPrivacy = data['aboutPrivacy'] ?? "everyone";
          isAppLockEnabled = data['appLockEnabled'] ?? false;
          List blocked = data['blockedUsers'] ?? [];
          blockedUsersCount = blocked.length;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Privacy", style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Who can see my personal info", 
              style: TextStyle(color: Color(0xff25D366), fontWeight: FontWeight.bold)),
          ),
          
          // LAST SEEN
          ListTile(
            title: const Text("Last Seen & Online", style: TextStyle(color: Colors.white)),
            subtitle: Text(lastSeenPrivacy.toUpperCase(), style: const TextStyle(color: Colors.white54)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LastSeenPrivacyScreen())),
          ),

          // PROFILE PHOTO
          ListTile(
            title: const Text("Profile Photo", style: TextStyle(color: Colors.white)),
            subtitle: Text(profilePhotoPrivacy.toUpperCase(), style: const TextStyle(color: Colors.white54)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePhotoPrivacyScreen())),
          ),

          // ABOUT
          ListTile(
            title: const Text("About", style: TextStyle(color: Colors.white)),
            subtitle: Text(aboutPrivacy.toUpperCase(), style: const TextStyle(color: Colors.white54)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPrivacyScreen())),
          ),

          const Divider(color: Colors.white24),

          // BLOCKED USERS
          ListTile(
            leading: const Icon(Icons.block, color: Colors.redAccent),
            title: const Text("Blocked Users", style: TextStyle(color: Colors.white)),
            subtitle: Text("$blockedUsersCount users blocked"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
          ),

          // APP LOCK
          ListTile(
            leading: Icon(
              isAppLockEnabled ? Icons.lock : Icons.lock_open, 
              color: isAppLockEnabled ? const Color(0xff25D366) : Colors.white54
            ),
            title: const Text("App Lock", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Use biometric to lock the app", style: TextStyle(color: Colors.white54)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppLockScreen())),
          ),
        ],
      ),
    );
  }
}