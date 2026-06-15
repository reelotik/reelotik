import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaPreviewScreen extends StatefulWidget {
  final List<File> files; // Parameter Name Fixed here

  const MediaPreviewScreen({
    super.key,
    required this.files,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  late List<File> files;
  int currentIndex = 0;
  final TextEditingController captionController = TextEditingController();
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    files = List.from(widget.files);
    _initializeMedia(currentIndex);
  }

  void _initializeMedia(int index) {
    _videoController?.dispose();
    _videoController = null;

    if (files.isEmpty) return;

    File currentFile = files[index];
    String ext = currentFile.path.split('.').last.toLowerCase();
    bool isVideo = ext == 'mp4' || ext == 'mov' || ext == 'avi';

    if (isVideo) {
      _videoController = VideoPlayerController.file(currentFile)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController!.play();
            _videoController!.setLooping(true); 
          }
        });
    }
  }

  // YE HAI DELETE BUTTON KA LOGIC
  void _removeCurrentFile() {
    setState(() {
      files.removeAt(currentIndex);
      if (files.isEmpty) {
        Navigator.pop(context);
      } else {
        if (currentIndex >= files.length) {
          currentIndex = files.length - 1;
        }
        _initializeMedia(currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox();

    File currentFile = files[currentIndex];
    String ext = currentFile.path.split('.').last.toLowerCase();
    bool isVideo = ext == 'mp4' || ext == 'mov' || ext == 'avi';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "${currentIndex + 1} of ${files.length}", 
          style: const TextStyle(color: Colors.white, fontSize: 16)
        ),
        actions: [
          // 🔴 PROMINENT DELETE BUTTON 🔴
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 30),
              onPressed: _removeCurrentFile,
              tooltip: "Delete File",
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: files.length,
              onPageChanged: (index) {
                setState(() => currentIndex = index);
                _initializeMedia(index);
              },
              itemBuilder: (context, index) {
                if (index == currentIndex && isVideo && _videoController != null && _videoController!.value.isInitialized) {
                  return Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  );
                } else if (!isVideo) {
                  return InteractiveViewer(
                    minScale: 0.8, maxScale: 4.0,
                    child: Image.file(files[index], fit: BoxFit.contain),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator(color: Color(0xff25D366)));
                }
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: TextField(
              controller: captionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Add a caption...",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xff1f2937),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),

          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      bool isSelected = index == currentIndex;
                      bool isThumbVideo = files[index].path.split('.').last.toLowerCase() == 'mp4' || files[index].path.split('.').last.toLowerCase() == 'mov' || files[index].path.split('.').last.toLowerCase() == 'avi';
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() => currentIndex = index);
                          _initializeMedia(index);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 50,
                          decoration: BoxDecoration(
                            border: Border.all(color: isSelected ? const Color(0xff25D366) : Colors.transparent, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                isThumbVideo 
                                  ? Container(color: Colors.grey.shade900, child: const Icon(Icons.videocam, color: Colors.white54, size: 20))
                                  : Image.file(files[index], fit: BoxFit.cover),
                                if (isThumbVideo) const Positioned(bottom: 2, right: 2, child: Icon(Icons.play_circle_fill, color: Colors.white, size: 14)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  backgroundColor: const Color(0xff25D366), elevation: 0,
                  onPressed: () => Navigator.pop(context, {"files": files, "caption": captionController.text.trim()}),
                  child: const Icon(Icons.send, color: Colors.white),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}