import 'package:flutter/material.dart';

class TypingIndicatorWidget extends StatelessWidget {
  final String userName;

  const TypingIndicatorWidget({
    super.key,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      child: Text(
        "$userName is typing...",
        style: const TextStyle(
          color: Color(0xff25D366),
          fontSize: 12,
        ),
      ),
    );
  }
}