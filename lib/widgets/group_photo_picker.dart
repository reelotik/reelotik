import 'package:flutter/material.dart';

class GroupPhotoPicker extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onChange;
  final VoidCallback onView;

  const GroupPhotoPicker({
    super.key,
    required this.imageUrl,
    required this.onChange,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onView,
          child: CircleAvatar(
            radius: 60,
            backgroundImage:
                imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
            child: imageUrl.isEmpty
                ? const Icon(
                    Icons.groups,
                    size: 50,
                  )
                : null,
          ),
        ),

        Positioned(
          right: 0,
          bottom: 0,
          child: InkWell(
            onTap: onChange,
            child: Container(
              padding:
                  const EdgeInsets.all(8),
              decoration:
                  const BoxDecoration(
                color: Color(0xff25D366),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}