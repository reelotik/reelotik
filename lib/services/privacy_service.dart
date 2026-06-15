import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrivacyService {
  static final uid = FirebaseAuth.instance.currentUser!.uid;

  static Future<void> updateSetting(
    String field,
    dynamic value,
  ) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .set({
      field: value,
    }, SetOptions(merge: true));
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getSettings() {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();
  }
}