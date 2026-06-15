import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/status_model.dart';
import '../services/status_service.dart';

class StatusViewerScreen extends StatefulWidget {
  final StatusModel status;

  const StatusViewerScreen({
    super.key,
    required this.status,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  VideoPlayerController? _videoController;
  double progress = 0;
  Timer? timer;

  bool get isVideo => widget.status.mediaType == "video";

  @override
  void initState() {
    super.initState();
    _markViewed();

    if (isVideo) {
      _initializeVideo();
    } else {
      _startImageTimer();
    }
  }

  Future<void> _markViewed() async {
    // FIX 1 & 2: Calling static method properly from StatusService and passing the correct status ID
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await StatusService.markViewed(widget.status.id, currentUser.uid);
    }
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.status.mediaUrl));

    await _videoController!.initialize();
    _videoController!.play();

    _videoController!.addListener(() {
      if (!mounted) return;

      final duration = _videoController!.value.duration.inMilliseconds;
      final position = _videoController!.value.position.inMilliseconds;

      if (duration > 0) {
        setState(() {
          progress = position / duration;
        });
      }

      if (_videoController!.value.position >= _videoController!.value.duration) {
        Navigator.pop(context);
      }
    });

    setState(() {});
  }

  void _startImageTimer() {
    timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (!mounted) return;

        setState(() {
          progress += 0.02; // 5 seconds total duration for image
        });

        if (progress >= 1) {
          timer.cancel();
          Navigator.pop(context);
        }
      },
    );
  }

  Future<void> _deleteStatus() async {
    await StatusService.deleteStatus(
      widget.status.id,
      widget.status.mediaUrl,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Status Deleted"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMyStatus = widget.status.uid == myUid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            /// 1. Media Layer
            Positioned.fill(
              child: isVideo
                  ? (_videoController != null && _videoController!.value.isInitialized)
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoController!.value.size.width,
                            height: _videoController!.value.size.height,
                            child: VideoPlayer(_videoController!),
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                  : CachedNetworkImage(
                      imageUrl: widget.status.mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                      errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white, size: 50)),
                    ),
            ),

            /// 2. Progress Bar
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                color: Colors.white,
                backgroundColor: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            /// 3. Top Bar (Profile Photo & Name)
            Positioned(
              top: 25,
              left: 15,
              right: 15,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade700,
                    child: widget.status.photoUrl != null && widget.status.photoUrl!.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: widget.status.photoUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Text(
                                widget.status.name.isNotEmpty ? widget.status.name[0].toUpperCase() : "U",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        : Text(
                            widget.status.name.isNotEmpty ? widget.status.name[0].toUpperCase() : "U",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(width: 10),
                  
                  Expanded(
                    child: Text(
                      widget.status.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)], 
                      ),
                    ),
                  ),

                  if (isMyStatus)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: _deleteStatus,
                    ),
                ],
              ),
            ),

            /// 4. Caption Layer
            if (widget.status.caption.isNotEmpty)
              Positioned(
                bottom: 80,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  decoration: BoxDecoration(
                    // FIX 3: Replaced deprecated withOpacity with withValues(alpha)
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.status.caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

            /// 5. Viewer Count (Bottom Left)
            if (isMyStatus)
              Positioned(
                bottom: 25,
                left: 20,
                child: Row(
                  children: [
                    const Icon(Icons.remove_red_eye, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      "${widget.status.viewers.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}