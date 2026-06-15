import 'dart:io'; // Needed for File check
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Timestamp
import 'package:intl/intl.dart'; // Needed for DateFormat
import 'package:cached_network_image/cached_network_image.dart';

class MessageBubble extends StatelessWidget {
  final String messageId;
  final Map<String, dynamic> data;
  final bool isMe;
  final Set<String> selectedMessageIds;
  final String? currentlyPlayingUrl;
  final Widget? reactionWidget;

  final Function(String, Map<String, dynamic>) onToggleSelection;
  final VoidCallback onSwipeReply;
  final VoidCallback onDoubleTapReact;
  final Function(String) onPlayAudio;
  final Function(String, String) onDownloadFile;
  final VoidCallback onCancelUpload;
  final VoidCallback onRetryUpload;
  final Function(String) onImageTap;
  final Function(String) onVideoTap;

  const MessageBubble({
    super.key,
    required this.messageId,
    required this.data,
    required this.isMe,
    required this.selectedMessageIds,
    required this.currentlyPlayingUrl,
    required this.onToggleSelection,
    required this.onSwipeReply,
    required this.onDoubleTapReact,
    required this.onPlayAudio,
    required this.onDownloadFile,
    required this.onCancelUpload,
    required this.onRetryUpload,
    required this.onImageTap,
    required this.onVideoTap,
    this.reactionWidget,
  });

  @override
  Widget build(BuildContext context) {
    String status = data["status"] ?? "sent";
    bool isMedia = data["type"] == "image" || data["type"] == "video";
    bool isUploading = data["uploading"] == true;

    return GestureDetector(
      onLongPress: () {
        if (selectedMessageIds.isEmpty && !isUploading) {
          onToggleSelection(messageId, data);
        }
      },
      onTap: selectedMessageIds.isNotEmpty && !isUploading
          ? () => onToggleSelection(messageId, data)
          : null,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0 && !isUploading) {
          onSwipeReply();
        }
      },
      onDoubleTap: () async {
        if (selectedMessageIds.isEmpty && !isUploading) {
          onDoubleTapReact();
        }
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: isMedia ? EdgeInsets.zero : const EdgeInsets.all(10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMedia
                ? Colors.transparent
                : selectedMessageIds.contains(messageId)
                    ? Colors.blueGrey
                    : isMe ? const Color(0xff25D366) : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(isMedia ? 12 : 14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (data["replyText"] != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                      border: Border(left: BorderSide(color: isMe ? Colors.white : const Color(0xff25D366), width: 4))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data["replySenderName"] ?? "User", style: TextStyle(color: isMe ? Colors.white : const Color(0xff25D366), fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(data["replyText"] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              if (data["type"] == "image")
                InkWell(
                  onTap: () => onImageTap(data["url"] ?? ""),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(imageUrl: data["url"] ?? "", height: 180, width: 250, fit: BoxFit.cover),
                  ),
                ),
              if (data["type"] == "text")
                Text(data["message"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 15)),
              
              if (reactionWidget != null) reactionWidget!,
              
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data["timestamp"] != null)
                    Text(DateFormat("hh:mm a").format((data["timestamp"] as Timestamp).toDate()), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(status == "seen" ? Icons.done_all : Icons.done, size: 14, color: status == "seen" ? Colors.blue : Colors.white70),
                  ],
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}