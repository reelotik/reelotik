// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print, unused_local_variable, empty_catches

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

// --- CUSTOM WIDGETS ---
import '../widgets/message_status_widget.dart';
import '../widgets/reaction_bar_widget.dart';
import '../widgets/reply_preview_widget.dart';
import '../widgets/message_bubble.dart';
import '../widgets/media_message_widget.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/emoji_picker_widget.dart';

// --- SERVICES & SCREENS ---
import '../services/storage_service.dart';
import '../services/voice_record_service.dart';
import 'group_info_screen.dart';
import 'group_audio_call_screen.dart';
import 'group_video_call_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  Map<String, dynamic>? _replyingTo;
  
  DocumentSnapshot? lastDocument;
  bool isLoadingMore = false;
  List<DocumentSnapshot> messages = [];
  final currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadInitialMessages() async {
    final query = FirebaseFirestore.instance.collection("groups").doc(widget.groupId).collection("messages").orderBy("timestamp", descending: true).limit(50);
    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      lastDocument = snapshot.docs.last;
      if (mounted) setState(() => messages = snapshot.docs);
    }
  }

  Future<void> _loadMoreMessages() async {
    if (isLoadingMore || lastDocument == null) return;
    setState(() => isLoadingMore = true);
    final query = FirebaseFirestore.instance.collection("groups").doc(widget.groupId).collection("messages").orderBy("timestamp", descending: true).startAfterDocument(lastDocument!).limit(50);
    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      lastDocument = snapshot.docs.last;
      if (mounted) setState(() { messages.addAll(snapshot.docs); isLoadingMore = false; });
    } else {
      setState(() => isLoadingMore = false);
    }
  }

  Future<void> sendMessage({String type = "text", String? url, String? msgText}) async {
    final text = msgText ?? _messageController.text.trim();
    if (text.isEmpty && url == null) return;

    final messageData = {
      "senderId": currentUid,
      "senderName": FirebaseAuth.instance.currentUser?.displayName ?? "User",
      "message": text,
      "type": type,
      "mediaUrl": url,
      "status": "sent",
      "seenBy": [currentUid],
      "timestamp": FieldValue.serverTimestamp(),
      "replyTo": _replyingTo != null ? _replyingTo!["message"] : null,
    };

    _messageController.clear();
    setState(() => _replyingTo = null);
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).collection("messages").add(messageData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        title: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: widget.groupId))),
          child: Text(widget.groupName, style: const TextStyle(color: Colors.white)),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupAudioCallScreen(groupName: widget.groupName)))),
          IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupVideoCallScreen(groupName: widget.groupName)))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: messages.length + (isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length) return const Center(child: CircularProgressIndicator());
                
                final data = messages[index].data() as Map<String, dynamic>;
                final messageId = messages[index].id;
                final bool isMe = data["senderId"] == currentUid;
                if ((List<String>.from(data["deletedFor"] ?? [])).contains(currentUid)) return const SizedBox();

                return Slidable(
                  key: ValueKey(messageId),
                  endActionPane: ActionPane(motion: const DrawerMotion(), children: [
                    SlidableAction(onPressed: (_) => setState(() => _replyingTo = data), backgroundColor: Colors.green, icon: Icons.reply, label: "Reply"),
                  ]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      // ✅ FIXED: Updated MessageBubble with all required parameters and removed reactionWidget
                      child: MessageBubble(
                        messageId: messageId,
                        data: data,
                        isMe: isMe,
                        selectedMessageIds: const {},
                        currentlyPlayingUrl: null,
                        onToggleSelection: (id, msg) {},
                        onSwipeReply: () => setState(() => _replyingTo = data),
                        onDoubleTapReact: () {},
                        onPlayAudio: (url) {},
                        onDownloadFile: (url, name) {},
                        onCancelUpload: () {},
                        onRetryUpload: () {},
                        onImageTap: (url) {},
                        onVideoTap: (url) {},
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (_replyingTo != null)
            ReplyPreviewWidget(message: _replyingTo!["message"], onCancel: () => setState(() => _replyingTo = null)),
          
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xff1f2937),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white), onPressed: () => showModalBottomSheet(context: context, builder: (_) => EmojiPickerWidget(onEmojiSelected: (emoji) { _messageController.text += emoji; Navigator.pop(context); }))),
                IconButton(icon: const Icon(Icons.attach_file, color: Colors.white), onPressed: () => showModalBottomSheet(context: context, builder: (_) => AttachmentSheet(onImage: () {}, onVideo: () {}, onAudio: () {}, onDocument: () {}))),
                Expanded(child: TextField(controller: _messageController, focusNode: _focusNode, style: const TextStyle(color: Colors.white))),
                GestureDetector(
                  onLongPress: () async { final path = await VoiceRecordService.stop(); if (path != null) { final url = await StorageService.uploadFile(File(path), "voice_notes"); await sendMessage(type: "audio", url: url, msgText: "Voice Note"); } },
                  child: IconButton(icon: const Icon(Icons.mic, color: Color(0xff25D366)), onPressed: () async { await VoiceRecordService.start(); }),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.green), onPressed: sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}