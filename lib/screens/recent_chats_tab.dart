import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; 
import 'package:flutter_contacts/flutter_contacts.dart'; 
import 'chat_detail_screen.dart';
import 'group_chat_screen.dart'; 

class RecentChatsTab extends StatefulWidget {
  const RecentChatsTab({super.key});

  @override
  State<RecentChatsTab> createState() => _RecentChatsTabState();
}

class _RecentChatsTabState extends State<RecentChatsTab> {
  Map<String, String> _contactMap = {};
  bool _isSyncingContacts = true;
  
  Set<String> selectedChats = {}; 
  Set<String> selectedGroups = {}; 

  String searchQuery = "";
  
  final Map<String, Map<String, dynamic>> _userCache = {};
  Timer? _debounce;
  
  bool _showingArchived = false;

  List<String> _myBlockedUsers = [];
  StreamSubscription<DocumentSnapshot>? _currentUserSub;

  @override
  void initState() {
    super.initState();
    _syncContactsToMemory();
    _listenToCurrentUser();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _currentUserSub?.cancel(); 
    super.dispose();
  }

  void _listenToCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserSub = FirebaseFirestore.instance.collection("users").doc(user.uid).snapshots().listen((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _myBlockedUsers = List<String>.from(doc.data()?["blockedUsers"] ?? []);
          });
        }
      });
    }
  }

  Future<void> _syncContactsToMemory() async {
    if (await FlutterContacts.requestPermission()) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      Map<String, String> tempMap = {};
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          String normalized = phone.number.replaceAll(RegExp(r'\D'), '');
          if (normalized.length >= 10) normalized = normalized.substring(normalized.length - 10);
          tempMap[normalized] = contact.displayName;
        }
      }
      if (mounted) setState(() { _contactMap = tempMap; _isSyncingContacts = false; });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() { searchQuery = query; });
    });
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {}); 
  }

  void _clearSelection() {
    setState(() {
      selectedChats.clear();
      selectedGroups.clear();
    });
  }

  void _togglePinSelected(String uid, bool currentlyPinned) {
    for (var id in selectedChats) {
      String collection = selectedGroups.contains(id) ? "groups" : "chats";
      FirebaseFirestore.instance.collection(collection).doc(id).update({
        "pinnedBy": currentlyPinned ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid])
      });
    }
    _clearSelection();
  }

  void _toggleArchiveSelected(String uid, bool currentlyArchived) {
    for (var id in selectedChats) {
      String collection = selectedGroups.contains(id) ? "groups" : "chats";
      FirebaseFirestore.instance.collection(collection).doc(id).update({
        "archivedBy": currentlyArchived ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid])
      });
    }
    _clearSelection();
  }

  void _toggleMuteSelected(String uid, bool currentlyMuted) {
    for (var id in selectedChats) {
      String collection = selectedGroups.contains(id) ? "groups" : "chats";
      FirebaseFirestore.instance.collection(collection).doc(id).update({
        "mutedBy": currentlyMuted ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid])
      });
    }
    _clearSelection();
  }

  void _deleteSelectedChats(String uid) {
    for (var id in selectedChats) {
      String collection = selectedGroups.contains(id) ? "groups" : "chats";
      FirebaseFirestore.instance.collection(collection).doc(id).update({"deletedFor": FieldValue.arrayUnion([uid])});
    }
    _clearSelection();
  }

  void _toggleFavorite(String chatId, String uid) {
    FirebaseFirestore.instance.collection("chats").doc(chatId).update({"favorites": FieldValue.arrayUnion([uid])});
    _clearSelection();
  }
  
  void _clearChat(String chatId, String uid) {
    FirebaseFirestore.instance.collection("chats").doc(chatId).update({
      "clearedAt.$uid": FieldValue.serverTimestamp()
    });
    _clearSelection();
  }

  void _toggleBlockUser(String currentUserUid, String otherUserId, bool isCurrentlyBlocked) {
    FirebaseFirestore.instance.collection("users").doc(currentUserUid).update({
      "blockedUsers": isCurrentlyBlocked ? FieldValue.arrayRemove([otherUserId]) : FieldValue.arrayUnion([otherUserId])
    });
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text("Login Required", style: TextStyle(color: Colors.white)));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("chats")
          .where("participants", arrayContains: currentUser.uid)
          .snapshots(),
      builder: (context, chatSnapshot) {
        
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("groups")
              .where("members", arrayContains: currentUser.uid)
              .snapshots(),
          builder: (context, groupSnapshot) {

            if ((chatSnapshot.connectionState == ConnectionState.waiting && !chatSnapshot.hasData) ||
                (groupSnapshot.connectionState == ConnectionState.waiting && !groupSnapshot.hasData)) {
              return const Scaffold(
                backgroundColor: Color(0xff0D1117),
                body: Center(child: CircularProgressIndicator(color: Color(0xff25D366)))
              );
            }

            // ✅ FIX: Explicit typing to resolve error
            final List<QueryDocumentSnapshot> allChats = chatSnapshot.data?.docs ?? [];
            final List<QueryDocumentSnapshot> allGroups = groupSnapshot.data?.docs ?? [];
            
            bool isFirstPinned = false;
            bool isFirstArchived = false;
            bool isFirstMuted = false;
            
            bool isSelectedBlocked = false;
            String selectedOtherUserId = "";

            if (selectedChats.isNotEmpty) {
              try {
                final firstId = selectedChats.first;
                final isFirstGroup = selectedGroups.contains(firstId);
                
                final firstDoc = isFirstGroup 
                    ? allGroups.firstWhere((doc) => doc.id == firstId)
                    : allChats.firstWhere((doc) => doc.id == firstId);
                    
                final data = firstDoc.data() as Map<String, dynamic>;
                isFirstPinned = List<String>.from(data["pinnedBy"] ?? []).contains(currentUser.uid);
                isFirstArchived = List<String>.from(data["archivedBy"] ?? []).contains(currentUser.uid);
                isFirstMuted = List<String>.from(data["mutedBy"] ?? []).contains(currentUser.uid);
                
                if (!isFirstGroup) {
                  final parts = List<String>.from(data["participants"] ?? []);
                  parts.remove(currentUser.uid);
                  if (parts.isNotEmpty) {
                    selectedOtherUserId = parts.first;
                    isSelectedBlocked = _myBlockedUsers.contains(selectedOtherUserId);
                  }
                }
              } catch (_) {}
            }

            return PopScope(
              canPop: selectedChats.isEmpty && !_showingArchived,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) {
                  if (selectedChats.isNotEmpty) {
                    _clearSelection();
                  } else if (_showingArchived) {
                    setState(() => _showingArchived = false);
                  }
                }
              },
              child: Scaffold(
                backgroundColor: const Color(0xff0D1117),
                
                appBar: selectedChats.isNotEmpty 
                  ? AppBar(
                      backgroundColor: const Color(0xff1f2937),
                      title: Text("${selectedChats.length} Selected", style: const TextStyle(color: Colors.white)),
                      actions: [
                        IconButton(
                          icon: Icon(isFirstPinned ? Icons.push_pin_outlined : Icons.push_pin, color: Colors.white), 
                          onPressed: () => _togglePinSelected(currentUser.uid, isFirstPinned)
                        ),
                        IconButton(
                          icon: Icon(isFirstArchived ? Icons.unarchive : Icons.archive, color: Colors.white), 
                          onPressed: () => _toggleArchiveSelected(currentUser.uid, isFirstArchived)
                        ),
                        IconButton(
                          icon: Icon(isFirstMuted ? Icons.volume_up : Icons.volume_off, color: Colors.white), 
                          onPressed: () => _toggleMuteSelected(currentUser.uid, isFirstMuted)
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white), 
                          onPressed: () => _deleteSelectedChats(currentUser.uid)
                        ),
                        if (selectedChats.length == 1 && !selectedGroups.contains(selectedChats.first))
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            onSelected: (value) async {
                              final chatId = selectedChats.first;
                              if (value == "fav") {
                                 _toggleFavorite(chatId, currentUser.uid);
                              } else if (value == "clear") {
                                 _clearChat(chatId, currentUser.uid);
                              } else if (value == "block_toggle") {
                                 _toggleBlockUser(currentUser.uid, selectedOtherUserId, isSelectedBlocked);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: "fav", child: Text("Add to Favorites")),
                              const PopupMenuItem(value: "clear", child: Text("Clear Chat")),
                              PopupMenuItem(value: "block_toggle", child: Text(isSelectedBlocked ? "Unblock" : "Block")),
                            ],
                          ),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _clearSelection),
                      ],
                    ) 
                  : _showingArchived
                    ? AppBar(
                        backgroundColor: const Color(0xff1f2937),
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => setState(() => _showingArchived = false),
                        ),
                        title: const Text("Archived Chats", style: TextStyle(color: Colors.white)),
                      )
                    : null,
                body: Column(
                  children: [
                    if (selectedChats.isEmpty && !_showingArchived)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TextField(
                          onChanged: _onSearchChanged,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Search chats...",
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(Icons.search, color: Colors.white54),
                            filled: true,
                            fillColor: const Color(0xff1f2937),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    
                    Expanded(
                      child: RefreshIndicator(
                        color: const Color(0xff25D366),
                        backgroundColor: const Color(0xff1f2937),
                        onRefresh: _handleRefresh,
                        child: Builder(
                          builder: (context) {
                            
                            List<Map<String, dynamic>> displayChats = [];
                            List<Map<String, dynamic>> archivedChats = [];

                            void processDocs(List<QueryDocumentSnapshot> docs, bool isGroup) {
                              for (var doc in docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                final deletedFor = List<String>.from(data["deletedFor"] ?? []);
                                final archivedBy = List<String>.from(data["archivedBy"] ?? []);
                                
                                if (deletedFor.contains(currentUser.uid)) continue;

                                final itemMap = {
                                  "isGroup": isGroup,
                                  "doc": doc,
                                  "time": data["lastMessageTime"] as Timestamp? ?? Timestamp(0, 0),
                                  "pinned": List<String>.from(data["pinnedBy"] ?? []).contains(currentUser.uid)
                                };

                                if (archivedBy.contains(currentUser.uid)) {
                                  archivedChats.add(itemMap);
                                } else {
                                  displayChats.add(itemMap);
                                }
                              }
                            }

                            processDocs(allChats, false); 
                            processDocs(allGroups, true);

                            List<Map<String, dynamic>> activeList = _showingArchived ? archivedChats : displayChats;

                            activeList.sort((a, b) {
                              if (a["pinned"] && !b["pinned"]) return -1;
                              if (!a["pinned"] && b["pinned"]) return 1;
                              return (b["time"] as Timestamp).compareTo(a["time"] as Timestamp); 
                            });

                            if (activeList.isEmpty && _showingArchived) {
                              return _buildEmptyState("No Archived Chats");
                            } else if (activeList.isEmpty && displayChats.isEmpty && archivedChats.isEmpty) {
                              return _buildEmptyState("No Chats Yet");
                            }

                            return ListView.builder(
                              itemCount: activeList.length + (!_showingArchived && archivedChats.isNotEmpty ? 1 : 0),
                              itemBuilder: (context, index) {
                                
                                if (!_showingArchived && archivedChats.isNotEmpty) {
                                  if (index == 0) {
                                    return ListTile(
                                      leading: const Icon(Icons.archive, color: Colors.white54),
                                      title: const Text("Archived", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      trailing: Text(archivedChats.length.toString(), style: const TextStyle(color: Color(0xff25D366), fontWeight: FontWeight.bold)),
                                      onTap: () => setState(() => _showingArchived = true),
                                    );
                                  }
                                  index -= 1; 
                                }

                                final itemData = activeList[index];
                                final isGroup = itemData["isGroup"] as bool;
                                final doc = itemData["doc"] as QueryDocumentSnapshot;

                                if (isGroup) {
                                  return _buildGroupTile(context, doc, currentUser);
                                } 
                                
                                final chatData = doc.data() as Map<String, dynamic>;
                                final chatId = doc.id;
                                
                                final participants = List<String>.from(chatData["participants"] ?? []);
                                participants.remove(currentUser.uid);
                                if (participants.isEmpty) return const SizedBox.shrink();
                                final otherUserId = participants.first;

                                if (_userCache.containsKey(otherUserId)) {
                                  return _buildChatTile(context, chatId, chatData, otherUserId, _userCache[otherUserId]!, currentUser);
                                } else {
                                  return FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance.collection("users").doc(otherUserId).get(),
                                    builder: (context, userSnap) {
                                      if (!userSnap.hasData) return const SizedBox.shrink();
                                      final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                                      _userCache[otherUserId] = userData;
                                      return _buildChatTile(context, chatId, chatData, otherUserId, userData, currentUser);
                                    },
                                  );
                                }
                              },
                            );
                          }
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildEmptyState(String message) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.white24),
              const SizedBox(height: 20),
              Text(message, style: const TextStyle(color: Colors.white54, fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupTile(BuildContext context, QueryDocumentSnapshot groupDoc, User currentUser) {
    final groupData = groupDoc.data() as Map<String, dynamic>;
    final groupId = groupDoc.id;
    final groupName = groupData["name"] ?? groupData["groupName"] ?? "Group";

    if (searchQuery.isNotEmpty && !groupName.toLowerCase().contains(searchQuery.toLowerCase())) {
      return const SizedBox.shrink();
    }

    final unreadMap = Map<String, dynamic>.from(groupData["unreadCount"] ?? {});
    final unreadCount = (unreadMap[currentUser.uid] as num?)?.toInt() ?? 0;
    
    final lastMsgTimeRaw = groupData["lastMessageTime"] as Timestamp?;
    String formattedTime = lastMsgTimeRaw != null ? DateFormat('hh:mm a').format(lastMsgTimeRaw.toDate()) : "";
    
    bool isSelected = selectedChats.contains(groupId);
    bool isPinned = List<String>.from(groupData["pinnedBy"] ?? []).contains(currentUser.uid);
    bool isMuted = List<String>.from(groupData["mutedBy"] ?? []).contains(currentUser.uid);

    String lastMessage = groupData["lastMessage"] ?? "";

    return ListTile(
      tileColor: isSelected ? Colors.white.withValues(alpha: 0.15) : (unreadCount > 0 ? const Color(0xff1A2E22) : Colors.transparent),
      onLongPress: () {
        setState(() {
          if (isSelected) {
            selectedChats.remove(groupId);
            selectedGroups.remove(groupId);
          } else {
            selectedChats.add(groupId);
            selectedGroups.add(groupId);
          }
        });
      },
      onTap: () {
        if (selectedChats.isNotEmpty) {
          setState(() {
            if (isSelected) {
              selectedChats.remove(groupId);
              selectedGroups.remove(groupId);
            } else {
              selectedChats.add(groupId);
              selectedGroups.add(groupId);
            }
          });
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: groupId, groupName: groupName)));
        }
      },
      leading: const CircleAvatar(
        backgroundColor: Color(0xff25D366),
        child: Icon(Icons.group, color: Colors.white),
      ),
      title: Row(
        children: [
          Text(groupName, style: TextStyle(color: Colors.white, fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600)),
          if (isMuted) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.volume_off, color: Colors.white38, size: 14)),
          if (isPinned) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.push_pin, color: Colors.white38, size: 14)),
        ],
      ),
      subtitle: Text(
        lastMessage,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: unreadCount > 0 ? const Color(0xff25D366) : Colors.white70),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(formattedTime, style: TextStyle(color: unreadCount > 0 ? const Color(0xff25D366) : Colors.white38, fontSize: 12)),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xff25D366), shape: BoxShape.circle),
              child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, String chatId, Map<String, dynamic> chatData, String otherUserId, Map<String, dynamic> userData, User currentUser) {
    final unreadMap = Map<String, dynamic>.from(chatData["unreadCount"] ?? {});
    final unreadCount = (unreadMap[currentUser.uid] as num?)?.toInt() ?? 0;
    final lastMsgTimeRaw = chatData["lastMessageTime"] as Timestamp?;
    String formattedTime = lastMsgTimeRaw != null ? DateFormat('hh:mm a').format(lastMsgTimeRaw.toDate()) : "";
    
    final phoneRaw = (userData["phone"] as String?) ?? (userData["phoneNumber"] as String?) ?? "";
    String? contactName;
    
    if (phoneRaw.isNotEmpty && !_isSyncingContacts) {
      String normPhone = phoneRaw.replaceAll(RegExp(r'\D'), '');
      if (normPhone.length >= 10) normPhone = normPhone.substring(normPhone.length - 10);
      contactName = _contactMap[normPhone];
    }

    final displayName = contactName ?? (phoneRaw.isNotEmpty ? phoneRaw : "Unknown");
    
    if (searchQuery.isNotEmpty && !displayName.toLowerCase().contains(searchQuery.toLowerCase())) {
      return const SizedBox.shrink();
    }

    bool isSelected = selectedChats.contains(chatId);
    bool isPinned = List<String>.from(chatData["pinnedBy"] ?? []).contains(currentUser.uid);
    bool isMuted = List<String>.from(chatData["mutedBy"] ?? []).contains(currentUser.uid);
    bool isOnline = userData["isOnline"] ?? false;
    
    bool isBlocked = _myBlockedUsers.contains(otherUserId);

    String msgType = chatData["lastMessageType"] ?? "text";
    String lastMessage = chatData["lastMessage"] ?? "";
    IconData? msgIcon;
    if (msgType == "image" || msgType == "photo") {
      msgIcon = Icons.camera_alt;
    } else if (msgType == "video") msgIcon = Icons.videocam;
    else if (msgType == "audio" || msgType == "voice") msgIcon = Icons.mic;
    else if (msgType == "document") msgIcon = Icons.insert_drive_file;

    return ListTile(
      tileColor: isSelected ? Colors.white.withValues(alpha: 0.15) : (unreadCount > 0 ? const Color(0xff1A2E22) : Colors.transparent),
      onLongPress: () {
        setState(() { isSelected ? selectedChats.remove(chatId) : selectedChats.add(chatId); });
      },
      onTap: () {
        if (selectedChats.isNotEmpty) {
          setState(() { isSelected ? selectedChats.remove(chatId) : selectedChats.add(chatId); });
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(name: displayName, userId: otherUserId)));
        }
      },
      leading: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xff25D366),
            backgroundImage: (userData["photoUrl"] != null && userData["photoUrl"].isNotEmpty) ? NetworkImage(userData["photoUrl"]) : null,
            child: (userData["photoUrl"] == null || userData["photoUrl"].isEmpty) ? const Icon(Icons.person, color: Colors.white) : null,
          ),
          if (isOnline)
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: const Color(0xff25D366), shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff0D1117), width: 2)
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Text(displayName, style: TextStyle(color: Colors.white, fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600)),
          if (isBlocked) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.block, color: Colors.redAccent, size: 14)),
          if (isMuted) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.volume_off, color: Colors.white38, size: 14)),
          if (isPinned) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.push_pin, color: Colors.white38, size: 14)),
        ],
      ),
      subtitle: Row(
        children: [
          if (msgIcon != null) ...[
            Icon(msgIcon, size: 14, color: unreadCount > 0 ? const Color(0xff25D366) : Colors.white54),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              lastMessage,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: unreadCount > 0 ? const Color(0xff25D366) : Colors.white70),
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(formattedTime, style: TextStyle(color: unreadCount > 0 ? const Color(0xff25D366) : Colors.white38, fontSize: 12)),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xff25D366), shape: BoxShape.circle),
              child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}