import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/status_model.dart';

class StatusService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> uploadStatus({
    required File file,
    required String mediaType, 
    String caption = "", 
    String privacy = "everyone", 
    Function(double)? onProgress, 
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final userDoc = await _firestore.collection("users").doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.${mediaType == "video" ? "mp4" : "jpg"}";
      final storageRef = _storage.ref().child("status").child(user.uid).child(fileName);

      UploadTask uploadTask = storageRef.putFile(file);
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (onProgress != null) onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      });

      await uploadTask;
      final mediaUrl = await storageRef.getDownloadURL();

      await _firestore.collection("status").add({
        "uid": user.uid,
        "name": userData["fullName"] ?? "User",
        "photoUrl": userData["photoUrl"] ?? "",
        "mediaUrl": mediaUrl,
        "mediaType": mediaType,
        "caption": caption, 
        "privacy": privacy, 
        "timestamp": FieldValue.serverTimestamp(),
        "viewers": [],
        "viewTimes": {},
      });
    } catch (e) { throw Exception("Upload Failed: $e"); }
  }

  static Future<void> uploadTextStatus({
    required String text,
    required String colorValueString,
    String privacy = "everyone",
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final userDoc = await _firestore.collection("users").doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      await _firestore.collection("status").add({
        "uid": user.uid,
        "name": userData["fullName"] ?? "User",
        "photoUrl": userData["photoUrl"] ?? "",
        "mediaUrl": colorValueString, 
        "mediaType": "text", 
        "caption": text, 
        "privacy": privacy,
        "timestamp": FieldValue.serverTimestamp(),
        "viewers": [],
        "viewTimes": {},
      });
    } catch (e) { throw Exception("Text Upload Failed: $e"); }
  }

  static Stream<List<StatusModel>> getStatuses({List<String> blockedUsers = const [], List<String> myContactsUids = const []}) {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    final currentUserUid = _auth.currentUser?.uid;
    return _firestore.collection("status").where("timestamp", isGreaterThan: Timestamp.fromDate(yesterday)).snapshots().map((snapshot) {
      List<StatusModel> allStatuses = snapshot.docs.map((doc) => StatusModel.fromMap(doc.data(), doc.id)).toList();
      allStatuses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return allStatuses.where((status) {
        if (blockedUsers.contains(status.uid)) return false;
        if (status.uid == currentUserUid) return false;
        if (status.privacy == "nobody") return false;
        if (status.privacy == "contacts" && !myContactsUids.contains(status.uid)) return false;
        return true;
      }).toList();
    });
  }

  static Stream<List<StatusModel>> getMyStatuses() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection("status").where("uid", isEqualTo: user.uid).snapshots().map((snapshot) {
      List<StatusModel> myStatuses = snapshot.docs.map((doc) => StatusModel.fromMap(doc.data(), doc.id)).toList();
      myStatuses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return myStatuses;
    });
  }

  static Future<void> markViewed(String statusId, String ownerUid) async {
    final user = _auth.currentUser;
    if (user == null || user.uid == ownerUid) return; 
    // NEW: Save viewer Uid and exact view Time
    await _firestore.collection("status").doc(statusId).update({
      "viewers": FieldValue.arrayUnion([user.uid]),
      "viewTimes.${user.uid}": FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteStatus(String statusId, String mediaUrl) async {
    try {
      await _firestore.collection("status").doc(statusId).delete();
      if (mediaUrl.isNotEmpty && mediaUrl.startsWith("http")) await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
    } catch (e) { throw Exception("Delete Failed: $e"); }
  }

  static Future<List<Map<String, dynamic>>> getViewerDetails(String statusId) async {
    final doc = await _firestore.collection("status").doc(statusId).get();
    if (!doc.exists) return [];
    
    List<dynamic> viewerUids = doc.data()?["viewers"] ?? [];
    Map<String, dynamic> viewTimes = doc.data()?["viewTimes"] ?? {};
    if (viewerUids.isEmpty) return [];

    List<Map<String, dynamic>> viewerDetails = [];
    for (String uid in viewerUids) {
      final userDoc = await _firestore.collection("users").doc(uid).get();
      if (userDoc.exists) {
        viewerDetails.add({
          "uid": uid,
          "name": userDoc.data()?["fullName"] ?? "Unknown",
          "photoUrl": userDoc.data()?["photoUrl"] ?? "",
          "time": viewTimes[uid], // NEW: Fetch view time
        });
      }
    }
    // Sort by most recently viewed
    viewerDetails.sort((a, b) {
      if (a["time"] == null || b["time"] == null) return 0;
      return (b["time"] as Timestamp).compareTo(a["time"] as Timestamp);
    });
    return viewerDetails;
  }

  static Map<String, List<StatusModel>> groupStatusesByUser(List<StatusModel> statuses) {
    Map<String, List<StatusModel>> grouped = {};
    for (var status in statuses) {
      if (!grouped.containsKey(status.uid)) grouped[status.uid] = [];
      grouped[status.uid]!.add(status);
    }
    grouped.forEach((key, list) => list.sort((a, b) => a.timestamp.compareTo(b.timestamp)));
    return grouped;
  }

  static Future<void> cleanupExpiredStatuses() async {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    try {
      final snapshot = await _firestore.collection("status").where("timestamp", isLessThanOrEqualTo: Timestamp.fromDate(yesterday)).get();
      for (var doc in snapshot.docs) {
        await deleteStatus(doc.id, doc.data()["mediaUrl"] ?? "");
      }
    } catch (e) {}
  }

  static Future<void> replyToStatus({
    required String statusId,
    required String receiverUid,
    required String replyMessage,
    required String mediaUrl, 
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    List<String> ids = [currentUser.uid, receiverUid];
    ids.sort();
    String chatRoomId = ids.join("_");

    await _firestore.collection("chats").doc(chatRoomId).collection("messages").add({
      "senderId": currentUser.uid,
      "receiverId": receiverUid,
      "message": replyMessage,
      "repliedToStatusId": statusId,
      "repliedToMediaUrl": mediaUrl,
      "timestamp": FieldValue.serverTimestamp(),
      "isRead": false,
    });
  }
}