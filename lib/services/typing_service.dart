import 'package:cloud_firestore/cloud_firestore.dart';

class TypingService {
  static Future<void> startTyping({
    required String groupId,
    required String uid,
  }) async {
    await FirebaseFirestore.instance
        .collection("groups")
        .doc(groupId)
        .update({
      "typingUsers.$uid":
          Timestamp.now(),
    });
  }

  static Future<void> stopTyping({
    required String groupId,
    required String uid,
  }) async {
    await FirebaseFirestore.instance
        .collection("groups")
        .doc(groupId)
        .update({
      "typingUsers.$uid":
          FieldValue.delete(),
    });
  }
}