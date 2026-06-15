import 'package:flutter/material.dart';

class MessageStatusWidget extends StatelessWidget {
  final bool isSent;
  final bool isDelivered;
  final bool isSeen;

  const MessageStatusWidget({
    super.key,
    this.isSent = true,
    this.isDelivered = false,
    this.isSeen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isSeen) {
      return const Icon(
        Icons.done_all,
        size: 16,
        color: Colors.blue,
      );
    }

    if (isDelivered) {
      return const Icon(
        Icons.done_all,
        size: 16,
        color: Colors.grey,
      );
    }

    return const Icon(
      Icons.done,
      size: 16,
      color: Colors.grey,
    );
  }
}