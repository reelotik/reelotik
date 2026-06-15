import 'package:cloud_firestore/cloud_firestore.dart';

class MessageStatusService {
  static Future<void> markDelivered({
    required String groupId,
    required String messageId,
    required String uid,
  }) async {
    await FirebaseFirestore.instance
        .collection("groups")
        .doc(groupId)
        .collection("messages")
        .doc(messageId)
        .update({
      "deliveredTo":
          FieldValue.arrayUnion([uid]),
    });
  }

  static Future<void> markSeen({
    required String groupId,
    required String messageId,
    required String uid,
  }) async {
    await FirebaseFirestore.instance
        .collection("groups")
        .doc(groupId)
        .collection("messages")
        .doc(messageId)
        .update({
      "seenBy":
          FieldValue.arrayUnion([uid]),
    });
  }
}