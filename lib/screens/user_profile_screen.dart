import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart'; 
import 'package:photo_view/photo_view.dart'; // REQUIRED FOR FULL SCREEN IMAGE
import 'chat_detail_screen.dart'; // IMPORT YOUR CHAT SCREEN
import 'edit_profile_screen.dart'; // IMPORT YOUR EDIT PROFILE SCREEN

List<Contact>? _cachedContactsProfile;

Future<String?> getProfileContactName(String phone) async {
  if (phone.isEmpty) return null;
  try {
    if (await FlutterContacts.requestPermission()) {
      _cachedContactsProfile ??= await FlutterContacts.getContacts(withProperties: true);
      String normalizedSearch = phone.replaceAll(RegExp(r'\D'), '');
      if (normalizedSearch.length >= 10) normalizedSearch = normalizedSearch.substring(normalizedSearch.length - 10);
      
      for (final contact in _cachedContactsProfile!) {
        for (final number in contact.phones) {
          String normalizedContact = number.number.replaceAll(RegExp(r'\D'), '');
          if (normalizedContact.length >= 10) normalizedContact = normalizedContact.substring(normalizedContact.length - 10);
          
          if (normalizedContact == normalizedSearch) {
            return contact.displayName;
          }
        }
      }
    }
  } catch (e) { debugPrint("Contact error: $e"); }
  return null;
}

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String name;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.name,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String? _resolvedContactName;
  String? _lastCheckedPhone;
  
  // Media Counters
  int imageCount = 0;
  int videoCount = 0;
  int fileCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchSharedMediaCounts();
  }

  // --- 7. SHARED MEDIA COUNT LOGIC ---
  Future<void> _fetchSharedMediaCounts() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == widget.userId) return;

    try {
      // Find the chat document that contains both users
      final chatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      String? targetChatId;
      for (var doc in chatQuery.docs) {
        List<dynamic> participants = doc['participants'];
        if (participants.contains(widget.userId)) {
          targetChatId = doc.id;
          break;
        }
      }

      if (targetChatId != null) {
        final messagesRef = FirebaseFirestore.instance.collection('chats').doc(targetChatId).collection('messages');
        
        final images = await messagesRef.where('type', isEqualTo: 'image').count().get();
        final videos = await messagesRef.where('type', isEqualTo: 'video').count().get();
        final files = await messagesRef.where('type', isEqualTo: 'file').count().get();
        
        if (mounted) {
          setState(() {
            imageCount = images.count ?? 0;
            videoCount = videos.count ?? 0;
            fileCount = files.count ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching media counts: $e");
    }
  }

  // --- 8. BLOCK USER ---
  Future<void> _blockUser() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    await FirebaseFirestore.instance.collection("users").doc(currentUid).update({
      "blockedUsers": FieldValue.arrayUnion([widget.userId]),
    });
    
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("You blocked ${widget.name}")));
  }

  // --- 9. REPORT USER ---
  Future<void> _reportUser() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    await FirebaseFirestore.instance.collection("reports").add({
      "reporterId": currentUid,
      "reportedUserId": widget.userId,
      "timestamp": FieldValue.serverTimestamp(),
      "reason": "User reported from profile screen",
    });

    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Reported. We will review this shortly.")));
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = currentUserUid == widget.userId;

    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff111827),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        actions: [
          // 1. EDIT PROFILE BUTTON (Only if it's the current user)
          if (isCurrentUser)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
            ),
            
          // 8 & 9. BLOCK / REPORT MENU (Only if it's NOT the current user)
          if (!isCurrentUser)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'block') _blockUser();
                if (value == 'report') _reportUser();
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'report',
                  child: Text('Report Contact', style: TextStyle(color: Colors.orangeAccent)),
                ),
                const PopupMenuItem<String>(
                  value: 'block',
                  child: Text('Block User', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xff25D366)));

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          
          final photoUrl = data["photoUrl"] as String?;
          final email = (data["email"] as String?) ?? "";
          final isOnline = (data["isOnline"] as bool?) ?? false;
          final about = (data["about"] as String?) ?? ""; // 2. FETCH ABOUT
          final createdAtRaw = data["createdAt"] as Timestamp?; // 6. FETCH JOIN DATE
          
          final profileName = (data["fullName"] as String?) ?? (data["name"] as String?) ?? widget.name; 
          final phone = (data["phoneNumber"] as String?) ?? (data["phone"] as String?) ?? (data["mobile"] as String?) ?? "";

          if (phone.isNotEmpty && phone != _lastCheckedPhone) {
            _lastCheckedPhone = phone;
            getProfileContactName(phone).then((name) {
              if (mounted && name != null) {
                setState(() {
                  _resolvedContactName = name;
                });
              }
            });
          }

          String lastSeen = "Offline";
          if (data["lastSeen"] != null) {
            lastSeen = DateFormat('dd MMM yyyy, hh:mm a').format((data["lastSeen"] as Timestamp).toDate());
          }

          String joinedDate = "Unknown";
          if (createdAtRaw != null) {
            joinedDate = DateFormat('dd MMM yyyy').format(createdAtRaw.toDate());
          }

          final contactName = _resolvedContactName;
          final displayPrimary = contactName ?? (profileName.isNotEmpty ? profileName : phone);
          final showInlineProfileName = (contactName != null && profileName.isNotEmpty && displayPrimary != profileName);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 30),
                // 3. FULL SCREEN PROFILE PHOTO VIEW
                GestureDetector(
                  onTap: () {
                    if (photoUrl != null && photoUrl.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullImageScreen(imageUrl: photoUrl),
                        ),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xff1f2937),
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                    child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, size: 60, color: Colors.white54) : null,
                  ),
                ),
                const SizedBox(height: 20),
                
                Column(
                  children: [
                    Text(
                      displayPrimary,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (showInlineProfileName)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "~$profileName",
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),
                Text(email, style: const TextStyle(color: Colors.white70)),
                
                const SizedBox(height: 20),

                // 4. CHAT BUTTON (If not current user)
                if (!isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff25D366),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(userId: widget.userId, name: displayPrimary),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat, color: Colors.black),
                        label: const Text("Message", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),

                // 2. ABOUT/BIO SHOW
                Card(
                  color: const Color(0xff1f2937),
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: const Icon(Icons.info_outline, color: Color(0xff25D366)),
                    title: const Text("About", style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                      about.isEmpty ? "Available" : about,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),

                Card(
                  color: const Color(0xff1f2937),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: ListTile(
                    leading: const Icon(Icons.phone, color: Color(0xff25D366)),
                    title: const Text("Mobile Number", style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                      phone.isNotEmpty ? phone : "No phone number available",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),

                // 5. ONLINE STATUS REALTIME
                Card(
                  color: const Color(0xff1f2937),
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: Icon(
                      isOnline ? Icons.circle : Icons.access_time,
                      color: isOnline ? const Color(0xff25D366) : Colors.orange,
                    ),
                    title: Text(
                      isOnline ? "Online" : "Last Seen",
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      isOnline ? "Active Now" : lastSeen,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),

                // 6. JOIN DATE
                Card(
                  color: const Color(0xff1f2937),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                    title: const Text("Joined", style: TextStyle(color: Colors.white)),
                    subtitle: Text(joinedDate, style: const TextStyle(color: Colors.white70)),
                  ),
                ),

                // 7. SHARED MEDIA COUNTS (Only show if not current user)
                if (!isCurrentUser)
                  Card(
                    color: const Color(0xff1f2937),
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMediaCounter(Icons.image, "$imageCount", "Photos"),
                          _buildMediaCounter(Icons.videocam, "$videoCount", "Videos"),
                          _buildMediaCounter(Icons.insert_drive_file, "$fileCount", "Files"),
                        ],
                      ),
                    ),
                  ),
                  
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaCounter(IconData icon, String count, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xff25D366), size: 28),
        const SizedBox(height: 8),
        Text(count, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

// ==========================================
// FULL SCREEN PHOTO VIEWER COMPONENT
// ==========================================
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