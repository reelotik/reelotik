import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; 
import 'package:photo_view/photo_view.dart'; 

import 'login_screen.dart';
import 'edit_profile_screen.dart'; 

// NEW IMPORTS ADDED
import 'privacy_screen.dart';
import 'chat_settings_screen.dart';
import 'notification_screen.dart';
import 'help_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isUploading = false;

  Future<void> pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => isUploading = true);

    try {
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path,
        "${pickedFile.path}_compressed.jpg",
        quality: 70, 
      );

      File file = File(compressedFile?.path ?? pickedFile.path); 

      final ref = FirebaseStorage.instance
          .ref()
          .child("profile_photos")
          .child("${user.uid}.jpg");

      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({
        "photoUrl": downloadUrl,
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile photo updated")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117), 
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Settings", style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection("users")
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data?.data() == null) {
                return const Center(
                  child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xff25D366))),
                );
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              String? photoUrl = data["photoUrl"];
              
              String displayName = data["fullName"] ?? data["name"] ?? "User";
              String displayPhone = data["phone"] ?? data["phoneNumber"] ?? "";
              String displayAbout = data["about"] ?? "Available"; 

              return Container(
                color: const Color(0xff1f2937), 
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (photoUrl != null && photoUrl.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullImageScreen(imageUrl: photoUrl),
                                ),
                              );
                            } else {
                              pickAndUploadImage();
                            }
                          },
                          child: CircleAvatar(
                            radius: 35,
                            backgroundColor: const Color(0xff25D366),
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null || photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
                          ),
                        ),
                        if (isUploading) 
                          const CircleAvatar(radius: 12, backgroundColor: Color(0xff1f2937), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xff25D366))),
                        if (!isUploading)
                          GestureDetector(
                            onTap: pickAndUploadImage,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xff25D366),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xff1f2937), width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                            ),
                          )
                      ],
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayAbout,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayPhone,
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code, color: Color(0xff25D366)),
                      onPressed: () {}, 
                    )
                  ],
                ),
              );
            },
          ),
          
          // UPDATED TILE CALLS
          buildTile(Icons.person_outline, "Account", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          }),
          buildTile(Icons.lock_outline, "Privacy", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyScreen()),
            );
          }),
          buildTile(Icons.chat_outlined, "Chats", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatSettingsScreen()),
            );
          }),
          buildTile(Icons.notifications_outlined, "Notifications", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
          }),
          buildTile(Icons.help_outline, "Help", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            );
          }),

          const SizedBox(height: 20),

          Card(
            color: const Color(0xff1f2937),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: const Text("Logout", style: TextStyle(color: Colors.white)),
              onTap: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
                    "isOnline": false,
                    "lastSeen": FieldValue.serverTimestamp(),
                  });
                  await FirebaseAuth.instance.signOut();
                }
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                }
              },
            ),
          ),

          Card(
            color: const Color(0xff1f2937),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text("Delete Account", style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                bool? confirm = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xff1f2937),
                    title: const Text("Delete Account?", style: TextStyle(color: Colors.redAccent)),
                    content: const Text("This action cannot be undone. All your data will be permanently deleted.", style: TextStyle(color: Colors.white)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );

                if (confirm != true) return;

                try {
                  await FirebaseFirestore.instance.collection("users").doc(user.uid).delete();
                  await user.delete();

                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                  }
                } on FirebaseAuthException catch (e) {
                  if (e.code == 'requires-recent-login') {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in again to delete your account.")));
                  } else {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 30), 
        ],
      ),
    );
  }

  static Widget buildTile(IconData icon, String title, VoidCallback onTap) {
    return Card(
      color: const Color(0xff1f2937),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xff25D366)), 
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
      ),
    );
  }
}

class FullImageScreen extends StatelessWidget {
  final String imageUrl;
  const FullImageScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    );
  }
}