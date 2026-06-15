// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print, empty_catches

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as official_emoji; 

// --- CUSTOM WIDGETS ---
import '../widgets/message_bubble.dart';
import '../widgets/reply_preview_widget.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/emoji_picker_widget.dart';

// --- SERVICES & SCREENS ---
import '../services/storage_service.dart';
import '../services/voice_record_service.dart';
import '../services/group_message_service.dart';
import 'group_info_screen.dart';
import 'group_audio_call_screen.dart';
import 'group_video_call_screen.dart';
import 'full_screen_image_viewer.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _replyingTo;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // --- STATE MANAGEMENT ---
  Set<String> selectedMessageIds = {};
  Map<String, Map<String, dynamic>> selectedMessageData = {};
  int _messageLimit = 50;
  String? currentlyPlayingUrl;
  bool showEmoji = false;

  // Advanced Recording Gesture states
  bool isRecording = false;
  bool isRecordLocked = false;
  Offset recordDragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) _updateTyping(true); else _updateTyping(false);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() => currentlyPlayingUrl = null);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      setState(() => _messageLimit += 30);
    }
  }

  Future<void> _updateTyping(bool isTyping) async {
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      "typingUsers": isTyping ? FieldValue.arrayUnion([currentUid]) : FieldValue.arrayRemove([currentUid])
    });
  }

  // --- MEDIA PICK & UPLOAD HANDLERS ---
  Future<void> _pickAndUploadMedia(String mediaType) async {
    try {
      String? downloadUrl;
      String? fileName;

      if (mediaType == "image") {
        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
        if (image == null) return;
        downloadUrl = await StorageService.uploadImage(File(image.path));
        fileName = image.name;
      } else if (mediaType == "video") {
        final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
        if (video == null) return;
        downloadUrl = await StorageService.uploadVideo(File(video.path));
        fileName = video.name;
      } else if (mediaType == "audio" || mediaType == "doc") {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: mediaType == "audio" ? FileType.audio : FileType.any,
        );
        if (result == null || result.files.single.path == null) return;
        downloadUrl = await StorageService.uploadFile(File(result.files.single.path!), "group_files");
        fileName = result.files.single.name;
      }

      if (downloadUrl != null) {
        await sendMessage(type: mediaType, url: downloadUrl, fileName: fileName);
      }
    } catch (e) {
      print("Media upload error: $e");
    }
  }

  // --- CORE MESSAGING PAYLOAD ---
  Future<void> sendMessage({String type = "text", String? url, String? msgText, String? fileName}) async {
    final text = msgText ?? _controller.text.trim();
    if (text.isEmpty && url == null) return;

    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).collection("messages").add({
      "senderId": currentUid,
      "senderName": FirebaseAuth.instance.currentUser?.displayName ?? "User",
      "message": text,
      "text": text, 
      "type": type,
      "url": url,
      "mediaUrl": url,
      "fileName": fileName,
      "status": "sent",
      "timestamp": FieldValue.serverTimestamp(),
      "seenBy": [currentUid],
      "replyText": _replyingTo?["text"] ?? _replyingTo?["message"],
      "replySenderName": _replyingTo?["senderName"],
    });

    _controller.clear();
    _updateTyping(false);
    setState(() => _replyingTo = null);
  }

  // --- SELECTION CONFIGURATIONS ---
  void _starSelected() async {
    for (String id in selectedMessageIds) {
      bool isStarred = (selectedMessageData[id]?["starredBy"] ?? []).contains(currentUid);
      await GroupMessageService.toggleStarMessage(groupId: widget.groupId, messageId: id, userId: currentUid, isCurrentlyStarred: isStarred);
    }
    setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
  }

  void _copySelected() async {
    String copiedText = selectedMessageIds.map((id) => selectedMessageData[id]?["message"] ?? selectedMessageData[id]?["text"] ?? "").where((t) => t.toString().isNotEmpty).join("\n");
    if (copiedText.isNotEmpty) await Clipboard.setData(ClipboardData(text: copiedText));
    setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
  }

  void _forwardSelected() {
    setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
  }

  void _deleteSelected() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xff1f2937),
        title: Text("Delete ${selectedMessageIds.length} message(s)?", style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              for (String id in selectedMessageIds) {
                await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).collection("messages").doc(id).update({
                  "deletedFor": FieldValue.arrayUnion([currentUid])
                });
              }
              setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
            },
            child: const Text("Delete for Me", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      )
    );
  }

  // --- PLAYBACK & DOWNLOAD LINKINGS ---
  Future<void> _handleVoicePlayback(String url) async {
    try {
      if (currentlyPlayingUrl == url) {
        await _audioPlayer.pause();
        setState(() => currentlyPlayingUrl = null);
      } else {
        await _audioPlayer.play(UrlSource(url));
        setState(() => currentlyPlayingUrl = url);
      }
    } catch (e) {
      print("Audio playback fail: $e");
    }
  }

  Future<void> _downloadFile(String url, String name) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localPath = "${appDir.path}/$name";
      await Dio().download(url, localPath);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("File saved cleanly: $name")));
    } catch (e) {}
  }

  void _showReactionMenu(String docId, String? currentReaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: const Color(0xff1f2937), borderRadius: BorderRadius.circular(24)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ["👍", "❤️", "😂", "😮", "😢", "🙏"].map((emoji) {
            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await GroupMessageService.addReaction(groupId: widget.groupId, messageId: docId, userId: currentUid, emoji: currentReaction == emoji ? "" : emoji);
              },
              child: Text(emoji, style: const TextStyle(fontSize: 30)),
            );
          }).toList(),
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection("groups").doc(widget.groupId).snapshots(),
      builder: (context, groupSnapshot) {
        String groupPhotoUrl = "";
        if (groupSnapshot.hasData && groupSnapshot.data!.exists) {
          final groupMap = groupSnapshot.data!.data() as Map<String, dynamic>;
          groupPhotoUrl = groupMap["groupPhoto"] ?? "";
        }

        return PopScope(
          canPop: selectedMessageIds.isEmpty && !showEmoji,
          onPopInvoked: (didPop) {
            if (!didPop) {
              if (selectedMessageIds.isNotEmpty) {
                setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); });
              } else if (showEmoji) {
                setState(() => showEmoji = false);
              }
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xff0b141a),
            // --- APPBAR LOGIC ---
            appBar: selectedMessageIds.isNotEmpty
              ? AppBar(
                  backgroundColor: const Color(0xff1f2937),
                  leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() { selectedMessageIds.clear(); selectedMessageData.clear(); })),
                  title: Text("${selectedMessageIds.length}", style: const TextStyle(color: Colors.white)),
                  actions: [
                    IconButton(icon: const Icon(Icons.star_outline, color: Colors.white), onPressed: _starSelected),
                    IconButton(icon: const Icon(Icons.copy, color: Colors.white), onPressed: _copySelected),
                    IconButton(icon: const Icon(Icons.forward, color: Colors.white), onPressed: _forwardSelected),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.white), onPressed: _deleteSelected),
                  ],
                )
              : AppBar(
                  backgroundColor: const Color(0xff1f2937),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white), 
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: widget.groupId))),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey.shade700,
                          backgroundImage: groupPhotoUrl.isNotEmpty ? NetworkImage(groupPhotoUrl) : null,
                          child: groupPhotoUrl.isEmpty ? const Icon(Icons.group, color: Colors.white, size: 20) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(widget.groupName, style: const TextStyle(color: Colors.white, fontSize: 16))),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupAudioCallScreen(groupName: widget.groupName)))),
                    IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupVideoCallScreen(groupName: widget.groupName)))),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white), 
                      onSelected: (val) {
                        if (val == "info") Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: widget.groupId)));
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: "info", child: Text("Group Info")),
                      ],
                    )
                  ],
                ),
            
            body: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection("groups").doc(widget.groupId)
                        .collection("messages").orderBy("timestamp", descending: true).limit(_messageLimit).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xff25D366)));
                      final docs = snapshot.data!.docs;

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final msgId = docs[index].id;
                          final bool isMe = data["senderId"] == currentUid;
                          if ((List<String>.from(data["deletedFor"] ?? [])).contains(currentUid)) return const SizedBox.shrink();

                          if (!(data["seenBy"] as List? ?? []).contains(currentUid)) {
                            docs[index].reference.update({"seenBy": FieldValue.arrayUnion([currentUid]), "status": "seen"});
                          }

                          return Slidable(
                            key: ValueKey(msgId),
                            endActionPane: ActionPane(motion: const DrawerMotion(), children: [
                              SlidableAction(onPressed: (_) => setState(() => _replyingTo = data), backgroundColor: Colors.green, icon: Icons.reply, label: "Reply"),
                            ]),
                            child: MessageBubble(
                              messageId: msgId,
                              data: data,
                              isMe: isMe,
                              selectedMessageIds: selectedMessageIds,
                              currentlyPlayingUrl: currentlyPlayingUrl,
                              onToggleSelection: (id, msgData) {
                                setState(() {
                                  if (selectedMessageIds.contains(id)) {
                                    selectedMessageIds.remove(id);
                                    selectedMessageData.remove(id);
                                  } else {
                                    selectedMessageIds.add(id);
                                    selectedMessageData[id] = msgData;
                                  }
                                });
                              },
                              onSwipeReply: () => setState(() => _replyingTo = data),
                              onDoubleTapReact: () {
                                String? currentReaction = data["reactions"] != null ? data["reactions"][currentUid] : null;
                                _showReactionMenu(msgId, currentReaction);
                              },
                              onPlayAudio: (url) => _handleVoicePlayback(url),
                              onDownloadFile: (url, name) => _downloadFile(url, name),
                              onCancelUpload: () {},
                              onRetryUpload: () {},
                              onImageTap: (url) => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: url))),
                              onVideoTap: (url) {},
                              reactionWidget: data["reactions"] != null && (data["reactions"] as Map).isNotEmpty
                                ? Wrap(
                                    spacing: 4,
                                    children: (data["reactions"] as Map).values.toSet().map<Widget>((e) => 
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xff1f2937), borderRadius: BorderRadius.circular(10)),
                                        child: Text(e.toString(), style: const TextStyle(fontSize: 12))
                                      )
                                    ).toList()
                                  )
                                : null,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                
                if (_replyingTo != null)
                  ReplyPreviewWidget(message: _replyingTo!["message"] ?? _replyingTo!["text"] ?? "Media Asset", onCancel: () => setState(() => _replyingTo = null)),
                
                // --- ADVANCED GESTURE BASED INPUT PANEL ---
                Container(
                  padding: const EdgeInsets.all(8),
                  color: const Color(0xff1f2937),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(showEmoji ? Icons.keyboard : Icons.emoji_emotions, color: Colors.white), 
                        onPressed: () {
                          if (showEmoji) _focusNode.requestFocus(); else _focusNode.unfocus();
                          setState(() => showEmoji = !showEmoji);
                        }
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file, color: Colors.white), 
                        onPressed: () => showModalBottomSheet(
                          context: context, 
                          builder: (_) => AttachmentSheet(
                            onImage: () { Navigator.pop(context); _pickAndUploadMedia("image"); },
                            onVideo: () { Navigator.pop(context); _pickAndUploadMedia("video"); },
                            onAudio: () { Navigator.pop(context); _pickAndUploadMedia("audio"); },
                            onDocument: () { Navigator.pop(context); _pickAndUploadMedia("doc"); },
                          )
                        )
                      ),
                      Expanded(
                        child: isRecording 
                          ? Text(isRecordLocked ? "🔒 Audio Recording Locked..." : "⬅ Swipe Left to Delete / ⬆ Drag Up to Lock", style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold))
                          : TextField(
                              controller: _controller, 
                              focusNode: _focusNode, 
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(hintText: "Type message...", border: InputBorder.none, hintStyle: TextStyle(color: Colors.white54)),
                            )
                      ),
                      
                      GestureDetector(
                        onLongPressStart: (_) async {
                          if (isRecording) return;
                          setState(() { isRecording = true; isRecordLocked = false; recordDragOffset = Offset.zero; });
                          await VoiceRecordService.start();
                        },
                        onLongPressMoveUpdate: (details) async {
                          if (!isRecording || isRecordLocked) return;
                          recordDragOffset = details.offsetFromOrigin;

                          if (recordDragOffset.dx < -70) {
                            await VoiceRecordService.stop();
                            setState(() { isRecording = false; isRecordLocked = false; });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recording cancelled & deleted")));
                          }
                          if (recordDragOffset.dy < -70) {
                            setState(() { isRecordLocked = true; });
                          }
                        },
                        onLongPressEnd: (_) async {
                          if (isRecordLocked) return; 
                          final path = await VoiceRecordService.stop();
                          setState(() { isRecording = false; });
                          if (path != null) {
                            final url = await StorageService.uploadFile(File(path), "voice_notes");
                            await sendMessage(type: "audio", url: url, msgText: "Voice Note");
                          }
                        },
                        child: IconButton(
                          icon: Icon(isRecording ? Icons.mic : Icons.mic_none, color: isRecording ? Colors.red : const Color(0xff25D366)), 
                          onPressed: () async {
                            if (isRecordLocked) { 
                              final path = await VoiceRecordService.stop();
                              setState(() { isRecording = false; isRecordLocked = false; });
                              if (path != null) {
                                final url = await StorageService.uploadFile(File(path), "voice_notes");
                                await sendMessage(type: "audio", url: url, msgText: "Voice Note");
                              }
                            }
                          }
                        ),
                      ),
                      if (!isRecording)
                        IconButton(icon: const Icon(Icons.send, color: Colors.green), onPressed: () => sendMessage()),
                    ],
                  ),
                ),
                
                if (showEmoji)
                  SizedBox(
                    height: 250,
                    child: official_emoji.EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        _controller.text += emoji.emoji;
                      },
                    ),
                  )
              ],
            ),
          ),
        );
      },
    );
  }
}