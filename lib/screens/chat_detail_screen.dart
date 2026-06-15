import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

import 'user_profile_screen.dart';
import 'media_preview_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String name;
  final String userId;

  const ChatDetailScreen({
    super.key,
    required this.name,
    required this.userId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> with WidgetsBindingObserver {
  // ==========================================
  // 1. STATE VARIABLES & CONTROLLERS
  // ==========================================
  final TextEditingController controller = TextEditingController();
  final ImagePicker picker = ImagePicker();
  final AudioRecorder audioRecorder = AudioRecorder(); 
  final AudioPlayer audioPlayer = AudioPlayer(); 
  
  StreamSubscription<QuerySnapshot>? _messageSubscription; 

  bool showEmoji = false;
  bool isRecording = false;
  String? currentlyPlayingUrl; 

  String? replyMessageText;
  String? replyMessageSenderName; 
  String? editingMessageId;
  
  Set<String> selectedMessageIds = {}; 
  Map<String, Map<String, dynamic>> selectedMessageData = {}; 

  final ValueNotifier<bool> _hasTextNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _recordDurationNotifier = ValueNotifier<int>(0);

  final ScrollController scrollController = ScrollController(); 
  bool showScrollToBottom = false; 
  int messageLimit = 20; // Fast Load Pagination

  bool cancelRecording = false;
  bool isLockedRecording = false;
  Offset dragOffset = Offset.zero; 

  Timer? _recordTimer;
  UploadTask? currentTask;

  Map<String, dynamic>? cachedUserData;
  String? wallpaperPath;
  bool isMuted = false;

  String get currentUserId => FirebaseAuth.instance.currentUser!.uid;

  String get chatRoomId {
    List<String> ids = [currentUserId, widget.userId];
    ids.sort();
    return ids.join("_");
  }

  // ==========================================
  // 2. INIT & DISPOSE LIFECYCLE
  // ==========================================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 

    _loadWallpaper();

    // Cache User Data Once
    FirebaseFirestore.instance.collection("users").doc(widget.userId).get().then((doc) {
      if (mounted && doc.exists) {
        setState(() {
          cachedUserData = doc.data();
        });
      }
    });

    // Check if Chat is Muted
    FirebaseFirestore.instance.collection("chats").doc(chatRoomId).snapshots().listen((snap) {
      if (mounted && snap.exists && snap.data()!.containsKey('mutedBy')) {
        setState(() {
          isMuted = (snap.data()!['mutedBy'] as List).contains(currentUserId);
        });
      }
    });

    controller.addListener(() {
      final hasText = controller.text.trim().isNotEmpty;
      if (_hasTextNotifier.value != hasText) {
        _hasTextNotifier.value = hasText;
      }
    });

    scrollController.addListener(() {
      if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
        setState(() { messageLimit += 20; });
      }

      if (scrollController.offset > 300) {
        if (!showScrollToBottom) setState(() { showScrollToBottom = true; });
      } else {
        if (showScrollToBottom) setState(() { showScrollToBottom = false; });
      }
    });
    
    FirebaseFirestore.instance.collection("users").doc(currentUserId).set({
      "isOnline": true,
    }, SetOptions(merge: true));
    
    FirebaseFirestore.instance.collection("chats").doc(chatRoomId).set({
      "unreadCount.$currentUserId": 0,
    }, SetOptions(merge: true));

    // Optimized Read Receipt Loop
    _messageSubscription = FirebaseFirestore.instance
        .collection("chats")
        .doc(chatRoomId)
        .collection("messages")
        .where("senderId", isEqualTo: widget.userId)
        .where("status", whereIn: ["sent", "delivered"])
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          change.doc.reference.update({
            "status": "seen",
            "seenAt": FieldValue.serverTimestamp()
          });
        }
      }
    });

    audioPlayer.onPlayerComplete.listen((event) {
      setState(() { currentlyPlayingUrl = null; });
    });
  }

  Future<void> _loadWallpaper() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = "${dir.path}/wallpaper_$chatRoomId.jpg";
    if (File(path).existsSync()) {
      setState(() {
        wallpaperPath = path;
      });
    }
  }

  Future<void> _pickWallpaper() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final dir = await getApplicationDocumentsDirectory();
      final path = "${dir.path}/wallpaper_$chatRoomId.jpg";
      await File(picked.path).copy(path);
      setState(() {
        wallpaperPath = path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wallpaper Set Successfully!"))
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FirebaseFirestore.instance.collection("users").doc(currentUserId).set({
        "isOnline": true,
      }, SetOptions(merge: true));
    } else {
      FirebaseFirestore.instance.collection("users").doc(currentUserId).set({
        "isOnline": false,
        "lastSeen": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      updateTyping(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); 
    FirebaseFirestore.instance.collection("users").doc(currentUserId).set({
      "isOnline": false,
      "lastSeen": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    updateTyping(false);

    controller.dispose();
    audioRecorder.dispose(); 
    audioPlayer.dispose(); 
    scrollController.dispose(); 
    _hasTextNotifier.dispose();
    _recordDurationNotifier.dispose();
    _recordTimer?.cancel(); 
    _messageSubscription?.cancel(); 
    super.dispose();
  }

  // ==========================================
  // 3. FORMATTERS & UTILS
  // ==========================================
  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  String _formatLastSeen(Timestamp? timestamp) {
    if (timestamp == null) return "Offline";
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));
    DateTime checkDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    String timeString = DateFormat('hh:mm a').format(dateTime);

    if (checkDate == today) {
      return "Today, $timeString";
    } else if (checkDate == yesterday) {
      return "Yesterday, $timeString";
    } else {
      return "${DateFormat('dd MMM yyyy').format(dateTime)}, $timeString";
    }
  }

  Future<void> updateTyping(bool typing) async {
    await FirebaseFirestore.instance.collection("users").doc(currentUserId).set({
      "typingTo": typing ? widget.userId : "",
    }, SetOptions(merge: true));
  }

  Future<bool> checkIsBlocked() async {
    try {
      DocumentSnapshot myDoc = await FirebaseFirestore.instance.collection("users").doc(currentUserId).get();
      final myData = myDoc.data() as Map<String, dynamic>? ?? {};
      if ((myData["blockedUsers"] ?? []).contains(widget.userId)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You blocked this user. Unblock to send a message.")));
        return true;
      }
      DocumentSnapshot theirDoc = await FirebaseFirestore.instance.collection("users").doc(widget.userId).get();
      final theirData = theirDoc.data() as Map<String, dynamic>? ?? {};
      if ((theirData["blockedUsers"] ?? []).contains(currentUserId)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You have been blocked by this user.")));
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> sendPushNotificationPayload(String messageText) async {
    try {
      await FirebaseFirestore.instance.collection("notifications").add({
        "toUserId": widget.userId,
        "fromUserId": currentUserId,
        "title": widget.name,
        "body": messageText,
        "timestamp": FieldValue.serverTimestamp(),
        "clickAction": "FLUTTER_NOTIFICATION_CLICK"
      });
    } catch (e) {
      debugPrint("Notification log error: $e");
    }
  }

  // ==========================================
  // 4. MESSAGING LOGIC
  // ==========================================
  Future<void> sendMessage({
    String? text, String? type, String? url, String? fileName, 
    String? replyText, String? replySenderName, 
  }) async {
    if (text != null && text.trim().isEmpty) return;
    if (await checkIsBlocked()) return;

    String msgText = text ?? "Sent a $type";

    await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).collection("messages").add({
      "text": text ?? "",
      "type": type ?? "text",
      "url": url,
      "fileName": fileName,
      "replyText": replyText, 
      "replySenderName": replySenderName, 
      "senderId": currentUserId,
      "timestamp": FieldValue.serverTimestamp(),
      "status": "sent", 
    });

    await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).set({
      "participants": [currentUserId, widget.userId],
      "lastMessage": msgText,
      "lastMessageTime": FieldValue.serverTimestamp(),
      "unreadCount.${widget.userId}": FieldValue.increment(1),
    }, SetOptions(merge: true));

    updateTyping(false);
    AudioPlayer().play(AssetSource("sounds/send.mp3"));
    sendPushNotificationPayload(msgText);
  }

  Future<void> processAndUploadMedia(File file, String type, String caption, {String? originalFileName, DocumentReference? retryDocRef}) async {
    String? localPath = file.path;
    String? thumbPath;
    String ext = localPath.split('.').last.toLowerCase();
    String uploadedFileName = originalFileName ?? "media_${DateTime.now().millisecondsSinceEpoch}.$ext";

    try {
      if (type == "image") {
        final tempDir = await getTemporaryDirectory();
        final targetPath = "${tempDir.path}/compress_${DateTime.now().millisecondsSinceEpoch}.jpg";
        var result = await FlutterImageCompress.compressAndGetFile(file.path, targetPath, quality: 60);
        localPath = result?.path ?? file.path;
      } else if (type == "video") {
        MediaInfo? mediaInfo = await VideoCompress.compressVideo(file.path, quality: VideoQuality.LowQuality, deleteOrigin: false);
        localPath = mediaInfo?.file?.path ?? file.path;
        try {
          final tempDir = await getTemporaryDirectory();
          thumbPath = await VideoThumbnail.thumbnailFile(video: localPath, thumbnailPath: tempDir.path, imageFormat: ImageFormat.JPEG, maxHeight: 180, quality: 75);
        } catch (e) {}
      }

      DocumentReference docRef;
      if (retryDocRef != null) {
        docRef = retryDocRef;
        await docRef.update({
          "uploading": true,
          "status": "sending",
          "progress": 0.0
        });
      } else {
        docRef = await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).collection("messages").add({
          "text": caption,
          "type": type,
          "localPath": localPath,
          "thumbPath": thumbPath,
          "fileName": uploadedFileName,
          "uploading": true,
          "progress": 0.0,
          "senderId": currentUserId,
          "timestamp": FieldValue.serverTimestamp(),
          "status": "sending", 
        });
      }

      scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

      String storagePath = "chat_$type/${DateTime.now().millisecondsSinceEpoch}_$uploadedFileName";
      Reference ref = FirebaseStorage.instance.ref().child(storagePath);
      UploadTask uploadTask = ref.putFile(File(localPath));
      currentTask = uploadTask; 

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        docRef.update({"progress": progress});
      });

      TaskSnapshot completedSnapshot = await uploadTask;
      String downloadUrl = await completedSnapshot.ref.getDownloadURL();

      await docRef.update({
        "url": downloadUrl,
        "uploading": false,
        "progress": FieldValue.delete(),
        "localPath": FieldValue.delete(),
        "thumbPath": FieldValue.delete(),
        "status": "sent",
      });

      // Secure cleanup of temporary files
      if (File(localPath).existsSync()) {
        try { File(localPath).deleteSync(); } catch (e) {}
      }
      if (thumbPath != null && File(thumbPath).existsSync()) {
        try { File(thumbPath).deleteSync(); } catch (e) {}
      }
      if (type == "video") {
        await VideoCompress.deleteAllCache();
      }
      if (type == "audio" && file.existsSync()) {
        try { file.deleteSync(); } catch (e) {}
      }

      String msgText = caption.isNotEmpty ? caption : (type == "doc" ? uploadedFileName : "Sent a $type");
      await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).set({
        "participants": [currentUserId, widget.userId],
        "lastMessage": msgText,
        "lastMessageTime": FieldValue.serverTimestamp(),
        "unreadCount.${widget.userId}": FieldValue.increment(1),
      }, SetOptions(merge: true));

      sendPushNotificationPayload(msgText);
    } catch (e) {
      if (retryDocRef == null) {
        await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).collection("messages").where("localPath", isEqualTo: localPath).get().then((value) {
          for (var doc in value.docs) {
            doc.reference.update({"status": "failed", "uploading": false});
          }
        });
      } else {
        await retryDocRef.update({"status": "failed", "uploading": false});
      }
    }
  }

  // ==========================================
  // 5. VOICE RECORDING
  // ==========================================
  Future<void> startRecording() async {
    try {
      if (await audioRecorder.hasPermission()) {
        final directory = Directory.systemTemp;
        final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await audioRecorder.start(const RecordConfig(), path: path);
        
        setState(() { isRecording = true; });
        _recordDurationNotifier.value = 0;

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _recordDurationNotifier.value++;
        });
      }
    } catch (e) {
      debugPrint("Error starting voice record: $e");
    }
  }

  Future<void> stopRecording() async {
    try {
      _recordTimer?.cancel(); 
      final path = await audioRecorder.stop();
      setState(() { isRecording = false; });
      if (path != null) {
        File audioFile = File(path);
        await processAndUploadMedia(audioFile, "audio", "Voice message");
      }
    } catch (e) {
      debugPrint("Error stopping voice record: $e");
    }
  }

  Future<void> handleVoicePlayback(String url) async {
    try {
      if (currentlyPlayingUrl == url) {
        await audioPlayer.pause();
        setState(() { currentlyPlayingUrl = null; });
      } else {
        await audioPlayer.play(UrlSource(url));
        setState(() { currentlyPlayingUrl = url; });
      }
    } catch (e) {
      debugPrint("Audio Playback Error: $e");
    }
  }

  // ==========================================
  // 6. BOTTOM SHEETS & ACTIONS
  // ==========================================
  void _showReactionMenu(String docId, String? currentReaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xff1f2937),
          borderRadius: BorderRadius.circular(30)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ["👍", "❤️", "😂", "😮", "😢", "😡"].map((emoji) {
            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).collection("messages").doc(docId).update({
                  "reaction": currentReaction == emoji ? FieldValue.delete() : emoji
                });
              },
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            );
          }).toList(),
        ),
      )
    );
  }

  void _showAttachmentBottomSheet() {
    showModalBottomSheet(
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) => Container(
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xff1f2937), 
          borderRadius: BorderRadius.circular(15)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _attachmentIcon(Icons.photo_library, Colors.purpleAccent, "Gallery", () async { 
              Navigator.pop(context); 
              await openGallery(); 
            }),
            _attachmentIcon(Icons.insert_drive_file, Colors.indigoAccent, "Document", () async { 
              Navigator.pop(context); 
              await pickDocument(); 
            }),
            _attachmentIcon(Icons.person, Colors.blueAccent, "Contact", () { 
              Navigator.pop(context); 
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contact Picker Coming Soon"))); 
            }),
            _attachmentIcon(Icons.location_on, Colors.greenAccent, "Location", () { 
              Navigator.pop(context); 
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location Picker Coming Soon"))); 
            }),
          ],
        ),
      ),
    );
  }

  Widget _attachmentIcon(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 25, 
            backgroundColor: color, 
            child: Icon(icon, color: Colors.white, size: 26)
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> openGallery() async {
    final List<XFile> mediaFiles = await picker.pickMultipleMedia();
    
    if (mediaFiles.isNotEmpty) {
      List<File> files = mediaFiles.map((e) => File(e.path)).toList();

      final previewResult = await Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => MediaPreviewScreen(files: files))
      );

      if (previewResult != null && previewResult["files"] != null) {
        List<File> finalFiles = previewResult["files"];
        String caption = previewResult["caption"] ?? "";

        for (int i = 0; i < finalFiles.length; i++) {
          File file = finalFiles[i];
          String textToSend = (i == 0) ? caption : ""; 
          String ext = file.path.split('.').last.toLowerCase();
          String type = (ext == 'mp4' || ext == 'mov' || ext == 'avi') ? "video" : "image";
          await processAndUploadMedia(file, type, textToSend);
        }
      }
    }
  }

  Future<void> pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;
      await processAndUploadMedia(file, "doc", fileName, originalFileName: fileName);
    }
  }

  Future<void> downloadFile(String url, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = "${dir.path}/$fileName";
    
    if (await File(path).exists()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File is already downloaded. Opening...")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Downloading...")));
      await Dio().download(url, path);
      
      if (path.endsWith(".jpg") || path.endsWith(".jpeg") || path.endsWith(".png")) {
        await GallerySaver.saveImage(path);
      } else if (path.endsWith(".mp4") || path.endsWith(".mov") || path.endsWith(".avi")) {
        await GallerySaver.saveVideo(path);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved cleanly!")));
    }
    
    if (!path.endsWith(".jpg") && !path.endsWith(".jpeg") && !path.endsWith(".png") &&
        !path.endsWith(".mp4") && !path.endsWith(".mov") && !path.endsWith(".avi")) {
      await OpenFilex.open(path);
    }
  }

  // ==========================================
  // 7. MESSAGE SELECTION ACTIONS
  // ==========================================
  
  // 🔥 RESTORED THIS IMPORTANT FUNCTION 🔥
  void showBottomSheetForSelected() {
    String singleId = selectedMessageIds.first;
    Map<String, dynamic> singleData = selectedMessageData[singleId]!;
    bool isMe = singleData["senderId"] == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1f2937),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply, color: Colors.white),
                title: const Text("Reply", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    replyMessageText = singleData["type"] == "text" ? singleData["text"] : "Media File";
                    replyMessageSenderName = isMe ? "You" : widget.name;
                    editingMessageId = null; 
                    selectedMessageIds.clear();
                    selectedMessageData.clear();
                  });
                },
              ),
              if (isMe && singleData["type"] == "text" && singleData["text"] != "This message was deleted")
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title: const Text("Edit Message", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      controller.text = singleData["text"];
                      editingMessageId = singleId;
                      replyMessageText = null; 
                      selectedMessageIds.clear();
                      selectedMessageData.clear();
                    });
                  },
                ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text("Message Info", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  String sentTime = singleData["timestamp"] != null 
                    ? DateFormat("dd MMM yyyy, hh:mm a").format((singleData["timestamp"] as Timestamp).toDate()) 
                    : "Pending...";
                  
                  String seenTime = singleData["seenAt"] != null
                    ? DateFormat("hh:mm a").format((singleData["seenAt"] as Timestamp).toDate())
                    : "Not Seen";

                  String statusStr = singleData["status"] == "seen" ? "Seen at $seenTime" : singleData["status"] == "failed" ? "Failed" : "Delivered";

                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xff1f2937),
                      title: const Text("Message Info", style: TextStyle(color: Colors.white)),
                      content: Text("Sent Time: $sentTime\nStatus: $statusStr\nType: ${singleData["type"]}", style: const TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context), 
                          child: const Text("OK", style: TextStyle(color: Color(0xff25D366)))
                        )
                      ],
                    ),
                  );
                  setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _pinSelected() async {
    for (String id in selectedMessageIds) {
      bool isPinned = selectedMessageData[id]?["pinned"] == true;
      await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).collection("messages").doc(id).update({
        "pinned": !isPinned
      });
    }
    setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
  }

  void _starSelected() async {
    for (String id in selectedMessageIds) {
      bool isStarred = selectedMessageData[id]?["starred"] == true;
      await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).collection("messages").doc(id).update({
        "starred": !isStarred
      });
    }
    setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
  }

  void copySelectedMessages() async {
    String copiedText = selectedMessageIds.map((id) => selectedMessageData[id]?["text"] ?? "").where((t) => t.toString().isNotEmpty).join("\n");
    if (copiedText.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: copiedText));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Messages copied")));
    }
    setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
  }

  void forwardSelectedMessages() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1f2937),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, maxChildSize: 0.9,
          builder: (_, bsController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Forward to...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection("users").where(FieldPath.documentId, isNotEqualTo: currentUserId).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final users = snapshot.data!.docs;
                      return ListView.builder(
                        controller: bsController,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(backgroundImage: user["photoUrl"] != null ? NetworkImage(user["photoUrl"]) : null),
                            title: Text(user["name"] ?? "User", style: const TextStyle(color: Colors.white)),
                            onTap: () async {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Forwarding to ${user["name"]}...")));
                              
                              List<String> ids = [currentUserId, users[index].id];
                              ids.sort();
                              String targetChatRoom = ids.join("_");

                              for (String msgId in selectedMessageIds) {
                                final msgData = selectedMessageData[msgId];
                                if (msgData != null) {
                                  await FirebaseFirestore.instance.collection("chats").doc(targetChatRoom).collection("messages").add({
                                    "text": msgData["text"], 
                                    "type": msgData["type"], 
                                    "url": msgData["url"], 
                                    "fileName": msgData["fileName"],
                                    "senderId": currentUserId, 
                                    "timestamp": FieldValue.serverTimestamp(), 
                                    "status": "sent",
                                  });
                                }
                              }

                              await FirebaseFirestore.instance.collection("chats").doc(targetChatRoom).set({
                                "participants": [currentUserId, users[index].id],
                                "lastMessage": "Forwarded message", 
                                "lastMessageTime": FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

                              setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Forwarded successfully")));
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void deleteSelectedMessages() {
    bool allMine = selectedMessageIds.every((id) => selectedMessageData[id]?["senderId"] == currentUserId);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xff1f2937),
        title: Text("Delete ${selectedMessageIds.length} message(s)?", style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              for (String id in selectedMessageIds) {
                await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).collection("messages").doc(id).update({
                  "deletedFor": FieldValue.arrayUnion([currentUserId])
                });
              }
              setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
            },
            child: const Text("Delete for Me", style: TextStyle(color: Colors.redAccent))
          ),
          if (allMine)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                for (String id in selectedMessageIds) {
                  await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).collection("messages").doc(id).update({
                    "text": "This message was deleted", 
                    "type": "deleted", 
                    "url": null
                  });
                }
                setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
              },
              child: const Text("Delete for Everyone", style: TextStyle(color: Colors.red))
            ),
        ],
      )
    );
  }

  void makeCall(bool isVideo) {
    FirebaseFirestore.instance.collection("calls").add({
      "callerId": currentUserId,
      "receiverId": widget.userId,
      "type": isVideo ? "video" : "audio",
      "status": "dialing",
      "timestamp": FieldValue.serverTimestamp()
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Calling ${widget.name}..."), backgroundColor: const Color(0xff25D366)));
  }

  // ==========================================
  // 8. MAIN UI BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    bool hasText = controller.text.trim().isNotEmpty; 

    // FIX: EMOJI KEYBOARD BACK BUTTON LOGIC
    return PopScope(
      canPop: !showEmoji && selectedMessageIds.isEmpty,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (selectedMessageIds.isNotEmpty) {
            setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
          } else if (showEmoji) {
            setState(() { showEmoji = false; });
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xff0b141a), 
        resizeToAvoidBottomInset: true, 
        
        // --- APPBAR LOGIC ---
        appBar: selectedMessageIds.isNotEmpty 
          ? AppBar(
              backgroundColor: const Color(0xff1f2937),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white), 
                onPressed: () => setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); })
              ),
              title: Text("${selectedMessageIds.length}", style: const TextStyle(color: Colors.white)),
              actions: [
                IconButton(icon: const Icon(Icons.star_outline, color: Colors.white), onPressed: _starSelected),
                IconButton(icon: const Icon(Icons.push_pin_outlined, color: Colors.white), onPressed: _pinSelected),
                IconButton(icon: const Icon(Icons.copy, color: Colors.white), onPressed: copySelectedMessages),
                IconButton(icon: const Icon(Icons.forward, color: Colors.white), onPressed: forwardSelectedMessages),
                IconButton(icon: const Icon(Icons.delete, color: Colors.white), onPressed: deleteSelectedMessages),
                if (selectedMessageIds.length == 1)
                  IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: showBottomSheetForSelected),
              ],
            )
          : AppBar(
              backgroundColor: const Color(0xff111827),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white), 
                onPressed: () => Navigator.pop(context)
              ),
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () { 
                      if (cachedUserData?["photoUrl"] != null && cachedUserData!["photoUrl"].toString().isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FullImageScreen(imageUrl: cachedUserData!["photoUrl"])));
                      }
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: cachedUserData?["photoUrl"] != null && cachedUserData!["photoUrl"].toString().isNotEmpty 
                        ? NetworkImage(cachedUserData!["photoUrl"]) 
                        : null,
                      child: (cachedUserData?["photoUrl"] == null || cachedUserData!["photoUrl"].toString().isEmpty) 
                        ? const Icon(Icons.person) 
                        : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: widget.userId, name: widget.name)));
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection("users").doc(widget.userId).snapshots(),
                            builder: (context, snapshot) {
                              String status = "Offline"; 
                              String typingStatus = "";
                              
                              if (snapshot.hasData && snapshot.data!.data() != null) {
                                Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;
                                if (data["isOnline"] == true) {
                                  status = "Online"; 
                                } else if (data["lastSeen"] != null) {
                                  status = _formatLastSeen(data["lastSeen"] as Timestamp?); 
                                }
                                typingStatus = data["typingTo"] == currentUserId ? "Typing..." : status;
                              }
                              return Text(typingStatus, style: const TextStyle(color: Colors.white70, fontSize: 11));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: () => makeCall(false)),
                IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () => makeCall(true)),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection("users").doc(currentUserId).snapshots(),
                  builder: (context, mySnap) {
                    bool isBlockedByMe = false;
                    if (mySnap.hasData && mySnap.data!.data() != null) {
                      isBlockedByMe = ((mySnap.data!.data() as Map<String, dynamic>)["blockedUsers"] ?? []).contains(widget.userId);
                    }
                    
                    return PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) async {
                        if (value == "search") {
                          showSearch(context: context, delegate: MessageSearchDelegate(chatRoomId)); 
                        }
                        if (value == "clear") {
                          await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).set({
                            "deletedFor": FieldValue.arrayUnion([currentUserId])
                          }, SetOptions(merge: true));
                        }
                        if (value == "export") {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Export Chat starting...")));
                        }
                        if (value == "mute") {
                          await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).set({
                            "mutedBy": isMuted ? FieldValue.arrayRemove([currentUserId]) : FieldValue.arrayUnion([currentUserId])
                          }, SetOptions(merge: true));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isMuted ? "Notifications Unmuted." : "Notifications Muted.")));
                        }
                        if (value == "wallpaper") {
                          _pickWallpaper();
                        }
                        if (value == "block") {
                          await FirebaseFirestore.instance.collection("users").doc(currentUserId).update({"blockedUsers": FieldValue.arrayUnion([widget.userId])});
                        }
                        if (value == "unblock") {
                          await FirebaseFirestore.instance.collection("users").doc(currentUserId).update({"blockedUsers": FieldValue.arrayRemove([widget.userId])});
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: "search", child: Text("Search Chat")),
                        PopupMenuItem(value: "mute", child: Text(isMuted ? "Unmute notifications" : "Mute notifications")),
                        const PopupMenuItem(value: "wallpaper", child: Text("Wallpaper")),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: "export", child: Text("Export Chat")),
                        const PopupMenuItem(value: "clear", child: Text("Clear Chat")),
                        if (!isBlockedByMe) 
                          const PopupMenuItem(value: "block", child: Text("Block User", style: TextStyle(color: Colors.red))),
                        if (isBlockedByMe) 
                          const PopupMenuItem(value: "unblock", child: Text("Unblock User")),
                      ],
                    );
                  }
                ),
              ],
            ),

        // --- MAIN BODY WITH WALLPAPER ---
        body: Container(
          decoration: BoxDecoration(
            color: const Color(0xff0b141a),
            image: wallpaperPath != null 
              ? DecorationImage(image: FileImage(File(wallpaperPath!)), fit: BoxFit.cover) 
              : null, 
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("chats")
                          .doc(chatRoomId)
                          .collection("messages")
                          .orderBy("timestamp", descending: true)
                          .limit(messageLimit)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xff25D366)));
                        
                        final docs = snapshot.data!.docs;

                        return ListView.builder(
                          controller: scrollController, 
                          reverse: true, 
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            
                            // Check if message is deleted for me
                            if ((List<String>.from(data["deletedFor"] ?? [])).contains(currentUserId)) {
                              return const SizedBox.shrink();
                            }

                            bool isMe = data["senderId"] == currentUserId;
                            String status = data["status"] ?? "sent";
                            bool isMedia = data["type"] == "image" || data["type"] == "video";
                            bool isUploading = data["uploading"] == true; 

                            // SWIPE TO REPLY
                            return Dismissible(
                              key: Key(docs[index].id),
                              direction: isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
                              confirmDismiss: (direction) async {
                                setState(() { 
                                  replyMessageText = data["type"] == "text" ? data["text"] : "Media File"; 
                                  replyMessageSenderName = isMe ? "You" : widget.name; 
                                  editingMessageId = null; 
                                  selectedMessageIds.clear(); 
                                  selectedMessageData.clear(); 
                                });
                                return false; 
                              },
                              background: Container(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, 
                                padding: const EdgeInsets.symmetric(horizontal: 20), 
                                child: const Icon(Icons.reply, color: Colors.white, size: 28)
                              ),
                              child: GestureDetector(
                                onLongPress: () { 
                                  if (selectedMessageIds.isEmpty && !isUploading) {
                                    setState(() { 
                                      selectedMessageIds.add(docs[index].id); 
                                      selectedMessageData[docs[index].id] = data; 
                                    }); 
                                  }
                                },
                                onTap: selectedMessageIds.isNotEmpty && !isUploading 
                                  ? () => setState(() {
                                        if (selectedMessageIds.contains(docs[index].id)) {
                                          selectedMessageIds.remove(docs[index].id);
                                          selectedMessageData.remove(docs[index].id);
                                        } else {
                                          selectedMessageIds.add(docs[index].id);
                                          selectedMessageData[docs[index].id] = data;
                                        }
                                      })
                                  : null,
                                onDoubleTap: () => _showReactionMenu(docs[index].id, data["reaction"]),
                                
                                child: Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                                    padding: isMedia ? EdgeInsets.zero : const EdgeInsets.all(10),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                    decoration: BoxDecoration(
                                      color: isMedia ? Colors.transparent 
                                        : selectedMessageIds.contains(docs[index].id) ? Colors.blueGrey 
                                        : isMe ? const Color(0xff005c4b) : const Color(0xff202c33), 
                                      borderRadius: BorderRadius.circular(isMedia ? 12 : 14)
                                    ),
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding: isMedia ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              // REPLY BANNER IN MESSAGE
                                              if (data["replyText"] != null)
                                                Container(
                                                  width: double.infinity, 
                                                  padding: const EdgeInsets.all(8), 
                                                  margin: const EdgeInsets.only(bottom: 6), 
                                                  decoration: BoxDecoration(
                                                    color: Colors.black26, 
                                                    borderRadius: BorderRadius.circular(6), 
                                                    border: Border(left: BorderSide(color: isMe ? Colors.white : const Color(0xff25D366), width: 4))
                                                  ), 
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start, 
                                                    children: [
                                                      Text(data["replySenderName"] ?? "User", style: TextStyle(color: isMe ? Colors.white : const Color(0xff25D366), fontWeight: FontWeight.bold, fontSize: 12)), 
                                                      const SizedBox(height: 2), 
                                                      Text(data["replyText"], style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)
                                                    ]
                                                  )
                                                ),

                                              // DELETED MESSAGE
                                              if (data["type"] == "deleted") 
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(vertical: 4), 
                                                  child: Text("This message was deleted", style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic))
                                                ),

                                              // IMAGE BUILDER
                                              if (data["type"] == "image")
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    if (isUploading)
                                                      Stack(
                                                        alignment: Alignment.center, 
                                                        children: [
                                                          if (data["localPath"] != null && File(data["localPath"]).existsSync()) 
                                                            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(data["localPath"]), height: 180, width: 250, fit: BoxFit.cover)) 
                                                          else 
                                                            Container(height: 180, width: 250, decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12))), 
                                                          
                                                          Container(height: 180, width: 250, decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12))), 
                                                          
                                                          Column(
                                                            mainAxisSize: MainAxisSize.min, 
                                                            children: [
                                                              CircularProgressIndicator(value: (data["progress"] ?? 0).toDouble(), color: const Color(0xff25D366)), 
                                                              const SizedBox(height: 8), 
                                                              Text("${((data["progress"] ?? 0) * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                                                              const SizedBox(height: 8), 
                                                              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () { currentTask?.cancel(); docs[index].reference.delete(); })
                                                            ]
                                                          )
                                                        ]
                                                      )
                                                    else ...[
                                                      InkWell(
                                                        onTap: () { 
                                                          if (selectedMessageIds.isEmpty) {
                                                            Navigator.push(context, MaterialPageRoute(builder: (_) => FullImageScreen(imageUrl: data["url"]))); 
                                                          }
                                                        },
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(12), 
                                                          child: CachedNetworkImage(
                                                            imageUrl: data["url"] ?? "", 
                                                            height: 180, 
                                                            width: 250, 
                                                            fit: BoxFit.cover, 
                                                            memCacheWidth: 250, 
                                                            placeholder: (context, url) => Container(height: 180, width: 250, color: Colors.black38, child: const Center(child: CircularProgressIndicator(color: Color(0xff25D366)))), 
                                                            errorWidget: (context, url, error) => Container(height: 180, width: 250, color: Colors.black38, child: const Icon(Icons.error))
                                                          )
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),

                                              // VIDEO BUILDER
                                              if (data["type"] == "video")
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    if (isUploading)
                                                      Stack(
                                                        alignment: Alignment.center, 
                                                        children: [
                                                          if (data["thumbPath"] != null && File(data["thumbPath"]).existsSync()) 
                                                            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(data["thumbPath"]), height: 180, width: 250, fit: BoxFit.cover)) 
                                                          else 
                                                            Container(height: 180, width: 250, decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12))), 
                                                          
                                                          Container(height: 180, width: 250, decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12))), 
                                                          
                                                          Column(
                                                            mainAxisSize: MainAxisSize.min, 
                                                            children: [
                                                              CircularProgressIndicator(value: (data["progress"] ?? 0).toDouble(), color: const Color(0xff25D366)), 
                                                              const SizedBox(height: 8), 
                                                              Text("${((data["progress"] ?? 0) * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                                                              const SizedBox(height: 8), 
                                                              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () { currentTask?.cancel(); docs[index].reference.delete(); })
                                                            ]
                                                          )
                                                        ]
                                                      )
                                                    else ...[
                                                      InkWell(
                                                        onTap: () { 
                                                          if (selectedMessageIds.isEmpty) {
                                                            Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoUrl: data["url"]))); 
                                                          }
                                                        },
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(12), 
                                                          child: Stack(
                                                            alignment: Alignment.center, 
                                                            children: [
                                                              Container(height: 180, width: 250, color: Colors.black45), 
                                                              const Icon(Icons.video_library, size: 80, color: Colors.white24), 
                                                              const Icon(Icons.play_circle_fill, size: 50, color: Colors.white)
                                                            ]
                                                          )
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),

                                              // AUDIO BUILDER
                                              if (data["type"] == "audio") 
                                                Row(
                                                  mainAxisSize: MainAxisSize.min, 
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(currentlyPlayingUrl == data["url"] ? Icons.pause : Icons.play_arrow, color: Colors.white), 
                                                      onPressed: () => handleVoicePlayback(data["url"])
                                                    ), 
                                                    const SizedBox(width: 4), 
                                                    const Text("Voice Message", style: TextStyle(color: Colors.white))
                                                  ]
                                                ),

                                              // DOCUMENT BUILDER
                                              if (data["type"] == "doc") 
                                                InkWell(
                                                  onTap: () { 
                                                    if (!isUploading && selectedMessageIds.isEmpty) {
                                                      downloadFile(data["url"], data["fileName"] ?? "Document.pdf"); 
                                                    }
                                                  }, 
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min, 
                                                    children: [
                                                      const Icon(Icons.description, color: Colors.white), 
                                                      const SizedBox(width: 8), 
                                                      Expanded(child: Text(data["fileName"] ?? "Document", style: const TextStyle(color: Colors.white, fontSize: 13, decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis)), 
                                                      if (isUploading) ...[ 
                                                        const SizedBox(width: 8), 
                                                        SizedBox(height: 16, width: 16, child: CircularProgressIndicator(value: (data["progress"] ?? 0).toDouble(), strokeWidth: 2, color: const Color(0xff25D366))) 
                                                      ]
                                                    ]
                                                  )
                                                ),

                                              // TEXT BUILDER
                                              if (data["type"] == "text" && (data["text"] ?? "").toString().isNotEmpty) 
                                                Text(data["text"], style: const TextStyle(color: Colors.white, fontSize: 15)),

                                              if (!isMedia) 
                                                const SizedBox(height: 4),

                                              // TIMESTAMP & STATUS (TICKS)
                                              if (!isMedia)
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (data["starred"] == true) ...[const Icon(Icons.star, size: 14, color: Colors.yellow), const SizedBox(width: 4)],
                                                    if (data["pinned"] == true) ...[const Icon(Icons.push_pin, size: 14, color: Colors.amber), const SizedBox(width: 4)],
                                                    if (data["edited"] == true) ...[const Text("edited", style: TextStyle(fontSize: 10, color: Colors.white70, fontStyle: FontStyle.italic)), const SizedBox(width: 4)],
                                                    
                                                    if (data["timestamp"] != null) 
                                                      Text(DateFormat("hh:mm a").format((data["timestamp"] as Timestamp).toDate()), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                                    
                                                    const SizedBox(width: 4),
                                                    if (isMe) 
                                                      Icon(
                                                        status == "failed" ? Icons.error : status == "sending" ? Icons.access_time : status == "seen" ? Icons.done_all : Icons.done, 
                                                        size: 14, 
                                                        color: status == "failed" ? Colors.red : status == "seen" ? Colors.blue : Colors.white70
                                                      ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                        
                                        // REACTION UI
                                        if (data["reaction"] != null && !isUploading) 
                                          Positioned(
                                            bottom: -2, 
                                            left: isMe ? null : 0, 
                                            right: isMe ? 0 : null, 
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), 
                                              decoration: BoxDecoration(color: const Color(0xff1f2937), borderRadius: BorderRadius.circular(10)), 
                                              child: Text(data["reaction"], style: const TextStyle(fontSize: 14))
                                            )
                                          ),
                                        
                                        // RETRY FAILED MEDIA
                                        if (status == "failed" && isMe) 
                                          Positioned(
                                            top: 0, 
                                            left: isMe ? -40 : null, 
                                            right: isMe ? null : -40, 
                                            child: IconButton(
                                              icon: const Icon(Icons.refresh, color: Colors.redAccent), 
                                              onPressed: () => processAndUploadMedia(File(data["localPath"]), data["type"], data["text"], retryDocRef: docs[index].reference)
                                            )
                                          )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // -- EMOJI PICKER --
                  if (showEmoji) 
                    SizedBox(
                      height: 260, 
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) { 
                          controller.text += emoji.emoji; 
                          controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length)); 
                          setState(() {}); 
                          updateTyping(true); 
                        }
                      )
                    ),

                  // -- BOTTOM INPUT FIELD --
                  SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (replyMessageText != null || editingMessageId != null)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xff1f2937), 
                              borderRadius: BorderRadius.circular(10), 
                              border: const Border(left: BorderSide(color: Color(0xff25D366), width: 4))
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, 
                                    children: [
                                      Text(editingMessageId != null ? "Editing Message" : "Replying to ${replyMessageSenderName ?? widget.name}", style: const TextStyle(color: Color(0xff25D366), fontWeight: FontWeight.bold, fontSize: 12)), 
                                      const SizedBox(height: 4), 
                                      Text(editingMessageId != null ? controller.text : replyMessageText!, style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)
                                    ]
                                  )
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white54, size: 20), 
                                  onPressed: () => setState(() { 
                                    replyMessageText = null; 
                                    replyMessageSenderName = null; 
                                    if (editingMessageId != null) { controller.clear(); editingMessageId = null; } 
                                  })
                                ),
                              ],
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              if (!isLockedRecording && !isRecording) ...[
                                IconButton(
                                  icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white), 
                                  onPressed: () { 
                                    FocusScope.of(context).unfocus(); 
                                    setState(() { showEmoji = !showEmoji; }); 
                                  }
                                ),
                                IconButton(
                                  icon: const Icon(Icons.attach_file, color: Colors.white), 
                                  onPressed: _showAttachmentBottomSheet
                                ),
                              ],

                              if (isLockedRecording) 
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red), 
                                  onPressed: () async { 
                                    _recordTimer?.cancel(); 
                                    await audioRecorder.stop(); 
                                    setState(() { isRecording = false; cancelRecording = false; isLockedRecording = false; dragOffset = Offset.zero; }); 
                                  }
                                ),
                              
                              if (isRecording)
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: isLockedRecording ? MainAxisAlignment.start : MainAxisAlignment.end, 
                                    children: [
                                      const Icon(Icons.circle, color: Colors.red, size: 12), 
                                      const SizedBox(width: 6), 
                                      ValueListenableBuilder<int>(
                                        valueListenable: _recordDurationNotifier, 
                                        builder: (context, seconds, _) => Text(_formatDuration(seconds), style: const TextStyle(color: Colors.white, fontSize: 16))
                                      ), 
                                      const Spacer(), 
                                      if (!isLockedRecording) 
                                        const Padding(
                                          padding: EdgeInsets.only(right: 15), 
                                          child: Text("⬅ Swipe to cancel\n⬆ Swipe to lock", style: TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center)
                                        )
                                    ]
                                  )
                                )
                              else
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(color: const Color(0xff2a3942), borderRadius: BorderRadius.circular(25)), 
                                    child: TextField(
                                      controller: controller, 
                                      onChanged: (val) => updateTyping(val.trim().isNotEmpty), 
                                      onTap: () { if (showEmoji) setState(() { showEmoji = false; }); }, 
                                      style: const TextStyle(color: Colors.white), 
                                      decoration: const InputDecoration(hintText: "Message...", hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 15))
                                    )
                                  )
                                ),
                                
                              const SizedBox(width: 8),

                              ValueListenableBuilder<bool>(
                                valueListenable: _hasTextNotifier,
                                builder: (context, hasText, _) {
                                  if (!isRecording && hasText) {
                                    return IconButton(
                                      icon: const Icon(Icons.send, color: Color(0xff25D366)), 
                                      onPressed: () async {
                                        if (controller.text.trim().isEmpty) return;
                                        if (editingMessageId != null) { 
                                          await FirebaseFirestore.instance.collection("chats").doc(chatRoomId).collection("messages").doc(editingMessageId).update({
                                            "text": controller.text.trim(), "edited": true
                                          }); 
                                          setState(() { editingMessageId = null; }); 
                                          controller.clear(); 
                                          updateTyping(false); 
                                          return; 
                                        }
                                        await sendMessage(text: controller.text.trim(), replyText: replyMessageText, replySenderName: replyMessageSenderName);
                                        setState(() { replyMessageText = null; replyMessageSenderName = null; }); 
                                        controller.clear();
                                      }
                                    );
                                  } else if (isLockedRecording) {
                                    return IconButton(
                                      icon: const Icon(Icons.send, color: Color(0xff25D366)), 
                                      onPressed: () async { 
                                        await stopRecording(); 
                                        setState(() { isLockedRecording = false; cancelRecording = false; dragOffset = Offset.zero; }); 
                                      }
                                    );
                                  } else {
                                    return GestureDetector(
                                      onLongPressStart: (_) async { 
                                        setState(() { dragOffset = Offset.zero; cancelRecording = false; isLockedRecording = false; }); 
                                        await startRecording(); 
                                      },
                                      onLongPressMoveUpdate: (details) { 
                                        if (!isRecording) return; 
                                        setState(() { 
                                          dragOffset = details.offsetFromOrigin; 
                                          if (dragOffset.dx < -50) cancelRecording = true; 
                                          if (dragOffset.dy < -50) isLockedRecording = true; 
                                        }); 
                                      },
                                      onLongPressEnd: (_) async { 
                                        if (cancelRecording) { 
                                          _recordTimer?.cancel(); 
                                          await audioRecorder.stop(); 
                                          setState(() { isRecording = false; cancelRecording = false; isLockedRecording = false; dragOffset = Offset.zero; }); 
                                          return; 
                                        } 
                                        if (isLockedRecording) return; 
                                        await stopRecording(); 
                                        setState(() { dragOffset = Offset.zero; }); 
                                      },
                                      child: Container(
                                        height: 48, width: 48, 
                                        transform: Matrix4.translationValues(
                                          cancelRecording ? -50 : (dragOffset.dx < 0 ? dragOffset.dx.clamp(-100.0, 0.0) : 0.0), 
                                          isLockedRecording ? -50 : (dragOffset.dy < 0 ? dragOffset.dy.clamp(-100.0, 0.0) : 0.0), 
                                          0
                                        ), 
                                        decoration: const BoxDecoration(color: Color(0xff25D366), shape: BoxShape.circle), 
                                        child: Icon(isRecording ? Icons.mic : Icons.mic_none, color: Colors.white)
                                      ),
                                    );
                                  }
                                }
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              if (showScrollToBottom) 
                Positioned(
                  right: 16, bottom: 90, 
                  child: FloatingActionButton(
                    mini: true, 
                    backgroundColor: const Color(0xff25D366), 
                    onPressed: () => scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut), 
                    child: const Icon(Icons.keyboard_arrow_down, color: Colors.white)
                  )
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// 9. FULL IMAGE SCREEN CLASS
// ====================================================================
class FullImageScreen extends StatelessWidget {
  final String imageUrl;
  const FullImageScreen({super.key, required this.imageUrl});
  
  @override 
  Widget build(BuildContext context) { 
    return Scaffold(
      backgroundColor: Colors.black, 
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)), 
      body: Center(
        child: InteractiveViewer(
          panEnabled: true, scaleEnabled: true, minScale: 0.5, maxScale: 4.0, 
          child: CachedNetworkImage(
            imageUrl: imageUrl, 
            fit: BoxFit.contain, 
            placeholder: (context, url) => const CircularProgressIndicator(color: Color(0xff25D366))
          )
        )
      )
    ); 
  }
}

// ====================================================================
// 10. VIDEO PLAYER COMPONENT
// ====================================================================
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({super.key, required this.videoUrl});
  
  @override 
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller; 
  bool _initialized = false;
  
  @override 
  void initState() { 
    super.initState(); 
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) { 
        setState(() { _initialized = true; }); 
        _controller.play(); 
      }); 
  }
  
  @override 
  void dispose() { 
    _controller.dispose(); 
    super.dispose(); 
  }
  
  @override 
  Widget build(BuildContext context) { 
    return Scaffold(
      backgroundColor: Colors.black, 
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)), 
      body: Center(
        child: _initialized 
          ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio, 
              child: Stack(
                alignment: Alignment.bottomCenter, 
                children: [
                  VideoPlayer(_controller), 
                  VideoProgressIndicator(_controller, allowScrubbing: true), 
                  Center(
                    child: IconButton(
                      icon: Icon(
                        _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, 
                        size: 60, color: Colors.white70
                      ), 
                      onPressed: () { 
                        setState(() { _controller.value.isPlaying ? _controller.pause() : _controller.play(); }); 
                      }
                    )
                  )
                ]
              )
            ) 
          : const CircularProgressIndicator(color: Color(0xff25D366))
      )
    ); 
  }
}

// ====================================================================
// 11. MESSAGE SEARCH DELEGATE
// ====================================================================
class MessageSearchDelegate extends SearchDelegate {
  final String chatRoomId;
  MessageSearchDelegate(this.chatRoomId);
  
  @override 
  ThemeData appBarTheme(BuildContext context) { 
    return ThemeData.dark().copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xff111827)), 
      scaffoldBackgroundColor: const Color(0xff0D1117), 
      inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none, hintStyle: TextStyle(color: Colors.white54))
    ); 
  }
  
  @override 
  List<Widget>? buildActions(BuildContext context) { 
    return [IconButton(icon: const Icon(Icons.clear, color: Colors.white), onPressed: () => query = "")]; 
  }
  
  @override 
  Widget? buildLeading(BuildContext context) { 
    return IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => close(context, null)); 
  }
  
  @override 
  Widget buildResults(BuildContext context) { 
    return _buildSearchList(); 
  }
  
  @override 
  Widget buildSuggestions(BuildContext context) { 
    return _buildSearchList(); 
  }
  
  Widget _buildSearchList() {
    if (query.trim().isEmpty) return const Center(child: Text("Search for messages...", style: TextStyle(color: Colors.white54)));
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("chats").doc(chatRoomId).collection("messages").orderBy("timestamp", descending: true).limit(200).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xff25D366)));
        
        final results = snapshot.data!.docs.where((doc) { 
          final data = doc.data() as Map<String, dynamic>; 
          return (data["text"] ?? "").toString().toLowerCase().contains(query.toLowerCase()); 
        }).toList();
        
        if (results.isEmpty) return const Center(child: Text("No messages found", style: TextStyle(color: Colors.white70)));
        
        return ListView.builder(
          itemCount: results.length, 
          itemBuilder: (context, index) { 
            final data = results[index].data() as Map<String, dynamic>; 
            final timestamp = data["timestamp"] as Timestamp?; 
            final timeString = timestamp != null ? DateFormat("dd MMM, hh:mm a").format(timestamp.toDate()) : ""; 
            
            return ListTile(
              leading: const Icon(Icons.message, color: Color(0xff25D366)), 
              title: Text(data["text"] ?? "", style: const TextStyle(color: Colors.white)), 
              subtitle: Text(timeString, style: const TextStyle(color: Colors.white54, fontSize: 11))
            ); 
          }
        );
      },
    );
  }
}