import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState
    extends State<ProfileSetupScreen> {
  final firstNameController =
      TextEditingController();

  final lastNameController =
      TextEditingController();

  File? imageFile;
  bool loading = false;

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<String> uploadImage() async {
    if (imageFile == null) return "";

    final ref = FirebaseStorage.instance
        .ref()
        .child(
          "profile_photos/${FirebaseAuth.instance.currentUser!.uid}.jpg",
        );

    await ref.putFile(imageFile!);

    return await ref.getDownloadURL();
  }

  Future<void> saveProfile() async {
    if (firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "First Name Required",
          ),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      String photoUrl =
          await uploadImage();

      await FirebaseFirestore.instance
          .collection("users")
          .doc(
            FirebaseAuth
                .instance.currentUser!.uid,
          )
          .set({
        "uid": FirebaseAuth
            .instance.currentUser!.uid,
        "firstName":
            firstNameController.text.trim(),
        "lastName":
            lastNameController.text.trim(),
        "fullName":
            "${firstNameController.text.trim()} ${lastNameController.text.trim()}"
                .trim(),
        "photoUrl": photoUrl,
        "isOnline": true,
        "lastSeen":
            FieldValue.serverTimestamp(),
        "updatedAt":
            FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const HomeScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Error: $e",
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xff0D1117),

      appBar: AppBar(
        backgroundColor:
            const Color(0xff111827),
        title: const Text(
          "Setup Profile",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            GestureDetector(
              onTap: pickImage,
              child: CircleAvatar(
                radius: 55,
                backgroundColor:
                    const Color(
                  0xff25D366,
                ),

                backgroundImage:
                    imageFile != null
                        ? FileImage(
                            imageFile!,
                          )
                        : null,

                child: imageFile == null
                    ? const Icon(
                        Icons.camera_alt,
                        color:
                            Colors.white,
                        size: 35,
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller:
                  firstNameController,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration:
                  InputDecoration(
                labelText:
                    "First Name",
                labelStyle:
                    const TextStyle(
                  color:
                      Colors.white70,
                ),
                filled: true,
                fillColor:
                    const Color(
                  0xff111827,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller:
                  lastNameController,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration:
                  InputDecoration(
                labelText:
                    "Last Name",
                labelStyle:
                    const TextStyle(
                  color:
                      Colors.white70,
                ),
                filled: true,
                fillColor:
                    const Color(
                  0xff111827,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xff25D366,
                  ),
                ),
                onPressed: loading
                    ? null
                    : saveProfile,
                child: loading
                    ? const CircularProgressIndicator(
                        color:
                            Colors.white,
                      )
                    : const Text(
                        "Continue",
                        style:
                            TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}