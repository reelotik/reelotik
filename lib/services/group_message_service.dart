import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMessageService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> addReaction({
    required String groupId,
    required String messageId,
    required String emoji,
  }) async {
    await _db
        .collection("groups")
        .doc(groupId)
        .collection("messages")
        .doc(messageId)
        .update({
      "reactions.${DateTime.now().millisecondsSinceEpoch}":
          emoji,
    });
  }

  static Future<void> starMessage({
    required String groupId,
    required String messageId,
  }) async {
    await _db
        .collection("groups")
        .doc(groupId)
        .collection("messages")
        .doc(messageId)
        .update({
      "starred": true,
    });
  }

  static Future<void> forwardMessage({
    required String targetGroupId,
    required Map<String, dynamic> message,
  }) async {
    await _db
        .collection("groups")
        .doc(targetGroupId)
        .collection("messages")
        .add(message);
  }
}