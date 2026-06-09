import 'package:flutter/material.dart';

class StoryWidget extends StatelessWidget {
  final String username;

  const StoryWidget({
    super.key,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.pink,
                width: 3,
              ),
            ),
            child: const CircleAvatar(
              radius: 30,
              child: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 70,
            child: Text(
              username,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}