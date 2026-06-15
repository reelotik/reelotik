import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'chat_detail_screen.dart'; 
import 'create_group_screen.dart'; // ✅ NEW: Import for Create Group Screen

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> contacts = [];
  bool loading = true;
  final TextEditingController searchController = TextEditingController();
  String searchText = "";

  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  Future<void> loadContacts() async {
    try {
      // 🌟 Updated to the latest API parameters
      if (await FlutterContacts.requestPermission(readonly: true)) {
        contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: true,
        );
      }
    } catch (e) {
      debugPrint("Error fetching contacts: $e");
    }
    
    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Search logic with safe null check
    final filteredContacts = contacts.where((c) {
      final name = c.displayName ?? '';
      return name.toLowerCase().contains(searchText.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xff0D1117), 
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 40, 12, 10), 
            child: TextField(
              controller: searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search contacts...",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                filled: true,
                fillColor: const Color(0xff1f2937),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => searchText = value),
            ),
          ),
          
          // Contacts List
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : ListView.builder(
                    // ✅ Item count is increased by 1 to accommodate "New Group" tile
                    itemCount: filteredContacts.length + 1,
                    itemBuilder: (context, index) {
                      
                      // ✅ 1. "New Group" Tile hamesha top par rahega (index 0)
                      if (index == 0) {
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xff25D366),
                            child: Icon(
                              Icons.group,
                              color: Colors.white,
                            ),
                          ),
                          title: const Text(
                            "New Group",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateGroupScreen(),
                              ),
                            );
                          },
                        );
                      }

                      // ✅ 2. Baki contacts ke liye index ko -1 karenge
                      final contact = filteredContacts[index - 1];
                      
                      return ListTile(
                        onTap: () async {
                          if (contact.phones.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("No phone number found")),
                            );
                            return;
                          }

                          // Null fallback for safety
                          String phone = contact.phones.first.number ?? "";
                          
                          if (phone.isEmpty) return; 

                          phone = phone
                              .replaceAll(" ", "")
                              .replaceAll("-", "")
                              .replaceAll("(", "")
                              .replaceAll(")", "");

                          if (!phone.startsWith("+91")) {
                            if (phone.startsWith("91")) {
                              phone = "+$phone";
                            } else {
                              phone = "+91$phone";
                            }
                          }

                          try {
                            final userQuery = await FirebaseFirestore.instance
                                .collection("users")
                                .where("phone", isEqualTo: phone)
                                .limit(1)
                                .get();

                            if (userQuery.docs.isEmpty) {
                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("This contact is not registered on Reelotik"),
                                ),
                              );
                              return;
                            }

                            final userData = userQuery.docs.first.data();

                            if (!context.mounted) return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatDetailScreen(
                                  name: userData["fullName"] ?? "User",
                                  userId: userData["uid"],
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        },

                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade800,
                          // Safe initialization check
                          child: Text(
                            ((contact.displayName ?? '').isNotEmpty)
                                ? (contact.displayName ?? '')[0].toUpperCase()
                                : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Title safe fallback
                        title: Text(
                          contact.displayName ?? "Unknown",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        // Subtitle safe fallback
                        subtitle: Text(
                          contact.phones.isNotEmpty
                              ? (contact.phones.first.number ?? "No Number")
                              : "No Number",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}