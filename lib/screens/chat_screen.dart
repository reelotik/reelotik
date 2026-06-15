import 'package:flutter/material.dart';
import 'settings_screen.dart';
import 'recent_chats_tab.dart';
import 'contacts_screen.dart';
import 'community_tab.dart';
import 'updates_tab.dart';
import 'calls_tab.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // addListener aur setState ko hata diya gaya hai kyunki ab AnimatedBuilder khud state handle karega
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),

      appBar: AppBar(
        backgroundColor: const Color(0xff111827),
        elevation: 0,
        automaticallyImplyLeading: false,

        title: const Text(
          "Reelotik",
          style: TextStyle(
            color: Color(0xff25D366),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            icon: const Icon(
              Icons.camera_alt,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {},
          ),

          IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ChatSearchDelegate(),
              );
            },
          ),

          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: Colors.white,
              size: 24,
            ),
            onSelected: (value) {
              if (value == "settings") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: "settings",
                child: Text("Profile & Settings"),
              ),
            ],
          ),
        ],

        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xff25D366),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xff25D366),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Chats"),
            Tab(text: "Community"),
            Tab(text: "Updates"),
            Tab(text: "Calls"),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: const [
          RecentChatsTab(),
          CommunityTab(),
          UpdatesTab(), // Agar yahan apna FAB hai toh Scaffold level par conflict nahi karega
          CallsTab(),
        ],
      ),

      // AnimatedBuilder ke through smooth aur instant FAB transitions
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          return _tabController.index == 0
              ? FloatingActionButton(
                  backgroundColor: const Color(0xff25D366),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContactsScreen(),
                      ),
                    );
                  },
                  child: const Icon(Icons.chat, color: Colors.white),
                )
              : const SizedBox.shrink(); // Instant hide jab hum doosre tab par swipe karein
        },
      ),
      // Yeh position ensure karegi ki FAB ekdam sahi jagah aaye
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// Fixed and Complete ChatSearchDelegate
class ChatSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Center(
      child: Text("Search: $query"),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Center(
      child: Text("Search: $query"),
    );
  }
}