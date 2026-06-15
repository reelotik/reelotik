import 'package:cloud_firestore/cloud_firestore.dart';

class StatusModel {
  final String id;
  final String uid;
  final String name;
  final String? photoUrl;
  final String mediaUrl;
  final String mediaType;
  final Timestamp timestamp;
  final List<dynamic> viewers;
  final Map<String, dynamic> viewTimes; // NEW: Har viewer ka time track karne ke liye
  final String privacy;
  final String caption;

  StatusModel({
    required this.id,
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.mediaUrl,
    required this.mediaType,
    required this.timestamp,
    required this.viewers,
    required this.viewTimes,
    required this.privacy,
    required this.caption,
  });

  factory StatusModel.fromMap(Map<String, dynamic> map, String docId) {
    return StatusModel(
      id: docId,
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'],
      mediaUrl: map['mediaUrl'] ?? '',
      mediaType: map['mediaType'] ?? 'image',
      timestamp: map['timestamp'] is Timestamp ? map['timestamp'] : Timestamp.now(),
      viewers: map['viewers'] ?? [],
      viewTimes: map['viewTimes'] ?? {}, // NEW
      privacy: map['privacy'] ?? 'everyone',
      caption: map['caption'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'photoUrl': photoUrl,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'timestamp': timestamp,
      'viewers': viewers,
      'viewTimes': viewTimes, // NEW
      'privacy': privacy,
      'caption': caption,
    };
  }
}