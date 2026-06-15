import 'package:flutter/material.dart';

class EmojiPickerWidget extends StatelessWidget {
  final Function(String) onEmojiSelected;

  const EmojiPickerWidget({
    super.key,
    required this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    final emojis = [
      "😀","😂","🤣","😍","❤️",
      "👍","🔥","😭","😎","🥳",
      "😡","🙏","💯","🎉","🤔"
    ];

    return SizedBox(
      height: 250,
      child: GridView.builder(
        itemCount: emojis.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
        ),
        itemBuilder: (_, index) {
          return InkWell(
            onTap: () {
              onEmojiSelected(emojis[index]);
            },
            child: Center(
              child: Text(
                emojis[index],
                style: const TextStyle(
                  fontSize: 30,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}