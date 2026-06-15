import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:photo_view/photo_view.dart';

// ==========================================
// 1. EDIT PROFILE SCREEN (SELF)
// ==========================================
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  
  bool isSaving = false; 
  String? currentPhotoUrl; 

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (doc.exists) {
      final data = doc.data()!;
      nameController.text = data['fullName'] ?? '';
      bioController.text = data['about'] ?? '';
      setState(() {
        currentPhotoUrl = data['photoUrl'];
      });
    } else {
      setState(() {});
    }
  }

  // --- NEW: PROFILE PHOTO UPLOAD LOGIC ---
  Future<void> pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (pickedFile == null) return; // User cancelled

    setState(() => isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      File imageFile = File(pickedFile.path);
      
      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/${user.uid}.jpg');
      await storageRef.putFile(imageFile);
      
      // Get Download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'photoUrl': downloadUrl,
      });

      if (mounted) {
        setState(() => currentPhotoUrl = downloadUrl);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Photo Updated!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // --- EXISTING: UPDATE PROFILE TEXT LOGIC ---
  Future<void> updateProfile() async {
    if (nameController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name too short")));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSaving = true); 

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fullName': nameController.text.trim(), 
        'about': bioController.text.trim(),     
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated")));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating profile: $e")));
    } finally {
      if (mounted) setState(() => isSaving = false); 
    }
  }

  // --- NEW: LOGOUT LOGIC ---
  Future<void> handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      // Dummy Login Screen route replace it with your actual LoginScreen
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text("Login Screen")))), 
        (route) => false
      );
    }
  }

  // --- NEW: DELETE ACCOUNT LOGIC ---
  Future<void> handleDeleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1f2937),
        title: const Text("Delete Account?", style: TextStyle(color: Colors.redAccent)),
        content: const Text("This action cannot be undone. All your data will be lost.", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isSaving = true);
    try {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).delete();
      await user.delete();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text("Login Screen")))), 
          (route) => false
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in again to delete your account.")));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Edit Profile", style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView( 
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- PROFILE PHOTO SECTION ---
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: () {
                    // NEW: FULL SCREEN PHOTO VIEW
                    if (currentPhotoUrl != null && currentPhotoUrl!.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => FullScreenImageViewer(imageUrl: currentPhotoUrl!)
                      ));
                    }
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xff25D366),
                    backgroundImage: (currentPhotoUrl != null && currentPhotoUrl!.isNotEmpty) 
                        ? NetworkImage(currentPhotoUrl!) 
                        : null,
                    child: (currentPhotoUrl == null || currentPhotoUrl!.isEmpty) 
                        ? const Icon(Icons.person, size: 50, color: Colors.white) 
                        : null,
                  ),
                ),
                GestureDetector(
                  onTap: pickAndUploadPhoto, // REAL UPLOAD LOGIC ATTACHED
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xff25D366),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xff0D1117), width: 3),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 30),

            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Name",
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xff1f2937), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: bioController,
              maxLength: 120, 
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Bio",
                labelStyle: const TextStyle(color: Colors.white54),
                counterStyle: const TextStyle(color: Colors.white54), 
                filled: true,
                fillColor: const Color(0xff1f2937),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50, 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff25D366), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving ? null : updateProfile, 
                child: isSaving
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text("Save Changes", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 40),
            const Divider(color: Colors.white24),
            const SizedBox(height: 20),

            // --- LOGOUT & DELETE ACCOUNT BUTTONS ---
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: const Text("Logout", style: TextStyle(color: Colors.white)),
              onTap: handleLogout,
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text("Delete Account", style: TextStyle(color: Colors.redAccent)),
              onTap: handleDeleteAccount,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. FULL SCREEN PHOTO VIEWER COMPONENT
// ==========================================
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});

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

// ==========================================
// 3. OTHER USER PROFILE SCREEN (BLOCK, REPORT, COUNTERS)
// ==========================================
class OtherUserProfileScreen extends StatefulWidget {
  final String otherUserId;
  final String chatId;

  const OtherUserProfileScreen({super.key, required this.otherUserId, required this.chatId});

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  int imageCount = 0;
  int fileCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchMediaCounters();
  }

  // --- MEDIA COUNTERS LOGIC ---
  Future<void> _fetchMediaCounters() async {
    try {
      final messagesRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages');
      
      final imageQuery = await messagesRef.where('type', isEqualTo: 'image').count().get();
      final fileQuery = await messagesRef.where('type', isEqualTo: 'file').count().get();
      
      if (mounted) {
        setState(() {
          imageCount = imageQuery.count ?? 0;
          fileCount = fileQuery.count ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error fetching counts: $e");
    }
  }

  // --- BLOCK USER LOGIC ---
  Future<void> _blockUser() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    await FirebaseFirestore.instance.collection("users").doc(currentUid).update({
      "blockedUsers": FieldValue.arrayUnion([widget.otherUserId]),
    });
    
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Blocked")));
  }

  // --- REPORT USER LOGIC ---
  Future<void> _reportUser() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    await FirebaseFirestore.instance.collection("reports").add({
      "reporterId": currentUid,
      "reportedUserId": widget.otherUserId,
      "timestamp": FieldValue.serverTimestamp(),
      "reason": "Inappropriate Behavior", // This can be replaced by a dropdown selection
    });

    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Reported. We will review this shortly.")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        title: const Text("Contact Info", style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Counters Display
          Card(
            color: const Color(0xff1f2937),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.image, color: Color(0xff25D366), size: 30),
                      const SizedBox(height: 5),
                      Text("$imageCount Images", style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.insert_drive_file, color: Color(0xff25D366), size: 30),
                      const SizedBox(height: 5),
                      Text("$fileCount Files", style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 30),

          // Actions
          ListTile(
            leading: const Icon(Icons.block, color: Colors.redAccent),
            title: const Text("Block User", style: TextStyle(color: Colors.redAccent)),
            onTap: _blockUser,
          ),
          ListTile(
            leading: const Icon(Icons.flag, color: Colors.orangeAccent),
            title: const Text("Report User", style: TextStyle(color: Colors.orangeAccent)),
            onTap: _reportUser,
          ),
        ],
      ),
    );
  }
}