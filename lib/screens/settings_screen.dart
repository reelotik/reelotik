import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),

      appBar: AppBar(
        backgroundColor: const Color(0xff075E54),
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white),
        ),
      ),

      body: ListView(
        children: [

          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 35,
                  ),
                ),

                SizedBox(width: 15),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sharma Ji",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Reelotik User",
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 10),

          buildTile(
            Icons.person_outline,
            "Account",
          ),

          buildTile(
            Icons.lock_outline,
            "Privacy",
          ),

          buildTile(
            Icons.chat_outlined,
            "Chats",
          ),

          buildTile(
            Icons.notifications_none,
            "Notifications",
          ),

          buildTile(
            Icons.storage,
            "Storage & Data",
          ),

          buildTile(
            Icons.monetization_on,
            "Coin Wallet",
          ),

          buildTile(
            Icons.help_outline,
            "Help",
          ),

          buildTile(
            Icons.info_outline,
            "About",
          ),

          buildTile(
            Icons.logout,
            "Logout",
          ),
        ],
      ),
    );
  }

  static Widget buildTile(
    IconData icon,
    String title,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xff075E54),
        ),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}