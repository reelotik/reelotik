import 'package:flutter/material.dart';

class ReplyPreviewWidget extends StatelessWidget {
  final String message;
  final VoidCallback onCancel;

  const ReplyPreviewWidget({
    super.key,
    required this.message,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white10,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            color: const Color(0xff25D366),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  "Replying",
                  style: TextStyle(
                    color: Color(0xff25D366),
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: onCancel,
            icon: const Icon(
              Icons.close,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}