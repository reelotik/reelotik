import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_member_contact_screen.dart'; // ✅ Added Import

class GroupMembersScreen extends StatefulWidget {
  final String groupId;
  const GroupMembersScreen({super.key, required this.groupId});

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // --- Actions ---
  Future<void> promoteAdmin(String uid) async {
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      "admins": FieldValue.arrayUnion([uid])
    });
  }

  Future<void> demoteAdmin(String uid) async {
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      "admins": FieldValue.arrayRemove([uid])
    });
  }

  Future<void> removeMember(String uid) async {
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      "members": FieldValue.arrayRemove([uid]),
      "admins": FieldValue.arrayRemove([uid])
    });
  }

  Future<void> transferOwnership(String uid) async {
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      "createdBy": uid,
      "admins": FieldValue.arrayUnion([uid])
    });
  }

  // --- Dialogs ---
  void showConfirmDialog(String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xff1f2937),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () { Navigator.pop(context); onConfirm(); }, child: const Text("Confirm", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection("groups").doc(widget.groupId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(backgroundColor: Color(0xff0D1117), body: Center(child: CircularProgressIndicator(color: Colors.green)));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final List members = data["members"] ?? [];
        final List admins = data["admins"] ?? [];
        final ownerId = data["createdBy"] ?? "";
        final isAdmin = admins.contains(myUid) || ownerId == myUid;

        return Scaffold(
          backgroundColor: const Color(0xff0D1117),
          appBar: AppBar(
            backgroundColor: const Color(0xff1f2937),
            title: const Text("Members"),
            actions: [
              // ✅ Added Add Member Button
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddMemberContactScreen(
                          groupId: widget.groupId,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search members...",
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.green),
                    filled: true,
                    fillColor: const Color(0xff1f2937),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("${members.length} Members", style: const TextStyle(color: Colors.white54)),
                ),
              ),

              Expanded(
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final uid = members[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection("users").doc(uid).get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) return const SizedBox();
                        final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                        final name = userData["fullName"] ?? "User";
                        
                        if (_searchQuery.isNotEmpty && !name.toLowerCase().contains(_searchQuery)) {
                          return const SizedBox.shrink();
                        }

                        return ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.green.shade800, child: const Icon(Icons.person)),
                          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            uid == ownerId ? "Owner" : (admins.contains(uid) ? "Admin" : "Member"),
                            style: TextStyle(
                              color: uid == ownerId ? Colors.orange : (admins.contains(uid) ? Colors.green : Colors.grey),
                            ),
                          ),
                          trailing: isAdmin && uid != myUid && uid != ownerId ? PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            onSelected: (value) {
                              if (value == "promote") promoteAdmin(uid);
                              if (value == "demote") demoteAdmin(uid);
                              if (value == "remove") showConfirmDialog("Remove Member", "Are you sure you want to remove $name?", () => removeMember(uid));
                              if (value == "owner") showConfirmDialog("Transfer Ownership", "Make $name the new owner?", () => transferOwnership(uid));
                            },
                            itemBuilder: (_) => [
                              if (!admins.contains(uid)) const PopupMenuItem(value: "promote", child: Text("Promote to Admin")),
                              if (admins.contains(uid)) const PopupMenuItem(value: "demote", child: Text("Remove Admin Status")),
                              const PopupMenuItem(value: "remove", child: Text("Remove Member", style: TextStyle(color: Colors.red))),
                              if (ownerId == myUid) const PopupMenuItem(value: "owner", child: Text("Transfer Ownership", style: TextStyle(color: Colors.orange))),
                            ],
                          ) : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}