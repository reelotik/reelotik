import 'package:flutter/material.dart';

class AttachmentSheet extends StatelessWidget {
  final VoidCallback onImage;
  final VoidCallback onVideo;
  final VoidCallback onAudio;
  final VoidCallback onDocument;

  const AttachmentSheet({
    super.key,
    required this.onImage,
    required this.onVideo,
    required this.onAudio,
    required this.onDocument,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          _item(Icons.image, "Image", onImage),
          _item(Icons.video_library, "Video", onVideo),
          _item(Icons.mic, "Audio", onAudio),
          _item(Icons.description, "Document", onDocument),
        ],
      ),
    );
  }

  Widget _item(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              child: Icon(icon),
            ),
            const SizedBox(height: 8),
            Text(title),
          ],
        ),
      ),
    );
  }
}