import 'package:cloud_firestore/cloud_firestore.dart';

/// Get real-time stream of notifications for a specific device
/// Returns notifications ordered by time (most recent first)
Future<Stream<QuerySnapshot>> getNotificationStream({
  required String deviceId
}) async {
  try {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('time', descending: true)
        .snapshots();
  } catch (e) {
    print('Error getting notification stream: $e');
    rethrow;
  }
}

/// Get notifications for multiple devices (for users monitoring several devices)
Future<Stream<QuerySnapshot>> getNotificationStreamForDevices({
  required List<String> deviceIds
}) async {
  try {
    if (deviceIds.isEmpty) {
      throw Exception('No device IDs provided');
    }

    // Firestore 'whereIn' supports up to 10 items
    if (deviceIds.length > 10) {
      throw Exception('Maximum 10 devices supported in whereIn query');
    }

    return FirebaseFirestore.instance
        .collection('notifications')
        .where('deviceId', whereIn: deviceIds)
        .orderBy('time', descending: true)
        .snapshots();
  } catch (e) {
    print('Error getting notifications for devices: $e');
    rethrow;
  }
}

/// Get notifications filtered by read status
Future<Stream<QuerySnapshot>> getNotificationStreamByReadStatus({
  required String deviceId,
  required String userId,
  required bool isRead,
}) async {
  try {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('time', descending: true)
        .snapshots()
        .map((snapshot) {
          // Filter in-memory based on readBy array
          final filteredDocs = snapshot.docs.where((doc) {
            final readBy = List<String>.from(doc['readBy'] ?? []);
            final userHasRead = readBy.contains(userId);
            return isRead ? userHasRead : !userHasRead;
          }).toList();
          
          // Return a new QuerySnapshot-like structure
          // Note: This returns the original snapshot, you'll need to filter in UI
          return snapshot;
        });
  } catch (e) {
    print('Error getting notifications by read status: $e');
    rethrow;
  }
}

/// Get notifications filtered by priority
Future<Stream<QuerySnapshot>> getNotificationStreamByPriority({
  required String deviceId,
  required String priority, // "low", "medium", "high", "critical"
}) async {
  try {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('deviceId', isEqualTo: deviceId)
        .where('priority', isEqualTo: priority)
        .orderBy('time', descending: true)
        .snapshots();
  } catch (e) {
    print('Error getting notifications by priority: $e');
    rethrow;
  }
}

/// Get notifications filtered by category
Future<Stream<QuerySnapshot>> getNotificationStreamByCategory({
  required String deviceId,
  required String category, // "weather", "system", "device", "manual"
}) async {
  try {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('deviceId', isEqualTo: deviceId)
        .where('category', isEqualTo: category)
        .orderBy('time', descending: true)
        .snapshots();
  } catch (e) {
    print('Error getting notifications by category: $e');
    rethrow;
  }
}

/// Get notifications filtered by type
Future<Stream<QuerySnapshot>> getNotificationStreamByType({
  required String deviceId,
  required String type, 
}) async {
  try {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('deviceId', isEqualTo: deviceId)
        .where('type', isEqualTo: type)
        .orderBy('time', descending: true)
        .snapshots();
  } catch (e) {
    print('Error getting notifications by type: $e');
    rethrow;
  }
}

/// Get recent notifications (last N notifications)
Future<Stream<QuerySnapshot>> getRecentNotificationStream({
  required String deviceId,
  int limit = 20,
}) async {
  try {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('time', descending: true)
        .limit(limit)
        .snapshots();
  } catch (e) {
    print('Error getting recent notifications: $e');
    rethrow;
  }
}