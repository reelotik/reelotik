import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'reels_gate_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ab humein currentIndex ya pages list ki zaroorat nahi hai
      body: const ChatScreen(),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // Hamesha 0 rahega kyunki Reels naye screen pe khulta hai
        selectedItemColor: const Color(0xff25D366),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,

        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReelsGateScreen(),
              ),
            );
          }
          // Index 0 par kuch karne ki zaroorat nahi kyunki hum pehle se hi ChatScreen par hain
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: "Chats",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: "Reels",
          ),
        ],
      ),
    );
  }
}