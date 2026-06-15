import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'reels_gate_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),

      body: const ChatScreen(),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        backgroundColor: const Color(0xff111827),

        selectedItemColor: const Color(0xff25D366),
        unselectedItemColor: Colors.grey,

        type: BottomNavigationBarType.fixed,

        showSelectedLabels: true,
        showUnselectedLabels: true,

        selectedFontSize: 12,
        unselectedFontSize: 12,

        elevation: 8,

        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReelsGateScreen(),
              ),
            );
          }
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.chat_bubble_outline,
              size: 24,
            ),
            activeIcon: Icon(
              Icons.chat_bubble,
              size: 24,
            ),
            label: "Chats",
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.play_circle_outline,
              size: 24,
            ),
            activeIcon: Icon(
              Icons.play_circle_fill,
              size: 24,
            ),
            label: "Reels",
          ),
        ],
      ),
    );
  }
}