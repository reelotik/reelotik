import 'package:flutter/material.dart';

class PinnedMessageBanner extends StatelessWidget {
  final String message;

  const PinnedMessageBanner({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) {
      return const SizedBox();
    }

    return Container(
      width: double.infinity,
      color: Colors.orange.shade700,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const Icon(
            Icons.push_pin,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}