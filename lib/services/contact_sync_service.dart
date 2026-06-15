import 'package:cloud_firestore/cloud_firestore.dart';

class ContactSyncService {
  // In-memory cache to prevent excessive Firestore reads
  static final Map<String, String> cache = {};

  static Future<String> getDisplayName(String uid) async {
    // 1. Check if name is already in cache
    if (cache.containsKey(uid)) {
      return cache[uid]!;
    }

    try {
      // 2. Fetch from Firestore
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      // 3. Handle non-existent document
      if (!doc.exists) return "Unknown";

      // 4. Extract name (Using "name" as per your requirement)
      final name = doc.data()?["name"] ?? "User";

      // 5. Save to cache
      cache[uid] = name;

      return name;
    } catch (e) {
      // Return fallback if network fails
      return "User";
    }
  }

  // Optional: Function to clear cache if user updates profile
  static void clearCache() {
    cache.clear();
  }
}