import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaMessageWidget extends StatelessWidget {
  final String type;
  final String url;
  final String? fileName;
  final VoidCallback? onTap;

  const MediaMessageWidget({
    super.key,
    required this.type,
    required this.url,
    this.fileName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case "image":
        return GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: url,
              height: 220,
              width: 220,
              fit: BoxFit.cover,
              placeholder: (c, s) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (c, s, e) =>
                  const Icon(Icons.broken_image),
            ),
          ),
        );

      case "video":
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 70,
              ),
            ),
          ),
        );

      case "audio":
        return Container(
          padding: const EdgeInsets.all(10),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "Voice Message",
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        );

      case "document":
        return ListTile(
          leading: const Icon(
            Icons.insert_drive_file,
            color: Colors.red,
          ),
          title: Text(
            fileName ?? "Document",
            style: const TextStyle(color: Colors.white),
          ),
          onTap: onTap,
        );

      default:
        return const SizedBox();
    }
  }
}