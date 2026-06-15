import 'package:flutter/material.dart';

class ReactionBarWidget extends StatelessWidget {
  final Function(String emoji) onReaction;

  const ReactionBarWidget({
    super.key,
    required this.onReaction,
  });

  @override
  Widget build(BuildContext context) {
    final reactions = [
      "❤️",
      "😂",
      "🔥",
      "👍",
      "😮",
      "😢",
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceEvenly,
        children: reactions.map((emoji) {
          return InkWell(
            onTap: () => onReaction(emoji),
            child: Text(
              emoji,
              style: const TextStyle(
                fontSize: 28,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}