import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMessageService {
  static final _db = FirebaseFirestore.instance;

  // ==========================================
  // 1. ADD OR REMOVE REACTION
  // ==========================================
  static Future<void> addReaction({
    required String groupId,
    required String messageId,
    required String userId, // Jis user ne react kiya hai uski ID
    required String emoji,
  }) async {
    // Agar user same emoji par dobara click kare (empty pass ho), toh reaction delete hoga
    if (emoji.isEmpty) {
      await _db
          .collection("groups")
          .doc(groupId)
          .collection("messages")
          .doc(messageId)
          .update({
        "reactions.$userId": FieldValue.delete(),
      });
    } else {
      // Naya reaction save hoga, userId as key ensure karega ki 1 user ka 1 hi reaction ho
      await _db
          .collection("groups")
          .doc(groupId)
          .collection("messages")
          .doc(messageId)
          .update({
        "reactions.$userId": emoji,
      });
    }
  }

  // ==========================================
  // 2. TOGGLE STAR MESSAGE (Per User)
  // ==========================================
  static Future<void> toggleStarMessage({
    required String groupId,
    required String messageId,
    required String userId,
    required bool isCurrentlyStarred,
  }) async {
    await _db
        .collection("groups")
        .doc(groupId)
        .collection("messages")
        .doc(messageId)
        .update({
      // Array use kar rahe hain taaki group me har koi apne liye message star kar sake
      "starredBy": isCurrentlyStarred
          ? FieldValue.arrayRemove([userId]) // Agar pehle se starred hai, toh Un-star karo
          : FieldValue.arrayUnion([userId]), // Nahi toh Star karo
    });
  }

  // ==========================================
  // 3. FORWARD MESSAGE
  // ==========================================
  static Future<void> forwardMessage({
    required String targetGroupId,
    required Map<String, dynamic> originalMessage,
    required String currentUserId,
  }) async {
    // Message forward karte waqt purana data (reactions, purana sender) clean karna zaroori hai
    final forwardedMessage = {
      "text": originalMessage["text"] ?? "",
      "type": originalMessage["type"] ?? "text",
      "url": originalMessage["url"],
      "fileName": originalMessage["fileName"],
      "senderId": currentUserId, // Ab tum sender ho
      "timestamp": FieldValue.serverTimestamp(), // Naya time
      "status": "sent",
      "isForwarded": true, // "Forwarded" tag UI me dikhane ke liye
      "reactions": {}, // Naye group me reactions zero se start honge
      "seenBy": [currentUserId], // Read receipts reset
      "deletedFor": [], // Delete list reset
    };

    // Firebase null values ko reject karta hai, isliye nulls remove kar dete hain
    forwardedMessage.removeWhere((key, value) => value == null);

    await _db
        .collection("groups")
        .doc(targetGroupId)
        .collection("messages")
        .add(forwardedMessage);
  }
}