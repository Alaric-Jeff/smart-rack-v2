import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Get unread notification count stream for a specific device
/// Returns a stream that updates in real-time
/// 
/// Usage:
/// ```dart
/// Stream<int> countStream = getUnreadCountStream(
///   deviceId: '00:1A:2B:3C:4D:5E'
/// );
/// 
/// StreamBuilder<int>(
///   stream: countStream,
///   builder: (context, snapshot) {
///     int count = snapshot.data ?? 0;
///     return Badge(label: Text('$count'));
///   }
/// );
/// ```
Stream<int> getUnreadCountStream({
  required String deviceId,
}) {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    return Stream.value(0);
  }

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('deviceId', isEqualTo: deviceId)
      .snapshots()
      .map((snapshot) {
        // Count notifications where current user is NOT in readBy array
        return snapshot.docs.where((doc) {
          final readBy = List<String>.from(doc['readBy'] ?? []);
          return !readBy.contains(user.uid);
        }).length;
      });
}

/// Get unread notification count for multiple devices
/// 
/// Usage:
/// ```dart
/// Stream<int> countStream = getUnreadCountStreamForDevices(
///   deviceIds: ['device1', 'device2', 'device3']
/// );
/// ```
Stream<int> getUnreadCountStreamForDevices({
  required List<String> deviceIds,
}) {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null || deviceIds.isEmpty) {
    return Stream.value(0);
  }

  // Firestore 'whereIn' supports up to 10 items
  if (deviceIds.length > 10) {
    // For >10 devices, you'd need to merge multiple streams
    // For now, throw an exception
    throw Exception('Maximum 10 devices supported. Use chunking for more.');
  }

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('deviceId', whereIn: deviceIds)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.where((doc) {
          final readBy = List<String>.from(doc['readBy'] ?? []);
          return !readBy.contains(user.uid);
        }).length;
      });
}

/// Get unread count for a specific device (one-time fetch, not a stream)
/// 
/// Usage:
/// ```dart
/// int count = await getUnreadCount(deviceId: '00:1A:2B:3C:4D:5E');
/// print('You have $count unread notifications');
/// ```
Future<int> getUnreadCount({
  required String deviceId,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    return 0;
  }

  final snapshot = await FirebaseFirestore.instance
      .collection('notifications')
      .where('deviceId', isEqualTo: deviceId)
      .get();

  return snapshot.docs.where((doc) {
    final readBy = List<String>.from(doc['readBy'] ?? []);
    return !readBy.contains(user.uid);
  }).length;
}

/// Get unread count for multiple devices (one-time fetch)
/// 
/// Usage:
/// ```dart
/// int count = await getUnreadCountForDevices(
///   deviceIds: ['device1', 'device2']
/// );
/// ```
Future<int> getUnreadCountForDevices({
  required List<String> deviceIds,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null || deviceIds.isEmpty) {
    return 0;
  }

  if (deviceIds.length > 10) {
    throw Exception('Maximum 10 devices supported');
  }

  final snapshot = await FirebaseFirestore.instance
      .collection('notifications')
      .where('deviceId', whereIn: deviceIds)
      .get();

  return snapshot.docs.where((doc) {
    final readBy = List<String>.from(doc['readBy'] ?? []);
    return !readBy.contains(user.uid);
  }).length;
}

/// Get unread count by priority for a device
/// 
/// Usage:
/// ```dart
/// int criticalCount = await getUnreadCountByPriority(
///   deviceId: '00:1A:2B:3C:4D:5E',
///   priority: 'critical'
/// );
/// ```
Future<int> getUnreadCountByPriority({
  required String deviceId,
  required String priority, // "low", "medium", "high", "critical"
}) async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    return 0;
  }

  final snapshot = await FirebaseFirestore.instance
      .collection('notifications')
      .where('deviceId', isEqualTo: deviceId)
      .where('priority', isEqualTo: priority)
      .get();

  return snapshot.docs.where((doc) {
    final readBy = List<String>.from(doc['readBy'] ?? []);
    return !readBy.contains(user.uid);
  }).length;
}

/// Get unread count by category for a device
/// 
/// Usage:
/// ```dart
/// int weatherCount = await getUnreadCountByCategory(
///   deviceId: '00:1A:2B:3C:4D:5E',
///   category: 'weather'
/// );
/// ```
Future<int> getUnreadCountByCategory({
  required String deviceId,
  required String category, // "weather", "system", "device", "manual"
}) async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    return 0;
  }

  final snapshot = await FirebaseFirestore.instance
      .collection('notifications')
      .where('deviceId', isEqualTo: deviceId)
      .where('category', isEqualTo: category)
      .get();

  return snapshot.docs.where((doc) {
    final readBy = List<String>.from(doc['readBy'] ?? []);
    return !readBy.contains(user.uid);
  }).length;
}

/// Check if a specific notification is read by current user
/// 
/// Usage:
/// ```dart
/// bool isRead = isNotificationRead(notificationDoc);
/// ```
bool isNotificationRead(DocumentSnapshot notification) {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    return false;
  }

  final readBy = List<String>.from(notification['readBy'] ?? []);
  return readBy.contains(user.uid);
}

/// Get unread count breakdown by priority
/// Returns a map with counts for each priority level
/// 
/// Usage:
/// ```dart
/// Map<String, int> breakdown = await getUnreadCountBreakdown(
///   deviceId: '00:1A:2B:3C:4D:5E'
/// );
/// print('Critical: ${breakdown['critical']}');
/// print('High: ${breakdown['high']}');
/// ```
Future<Map<String, int>> getUnreadCountBreakdown({
  required String deviceId,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    return {
      'critical': 0,
      'high': 0,
      'medium': 0,
      'low': 0,
    };
  }

  final snapshot = await FirebaseFirestore.instance
      .collection('notifications')
      .where('deviceId', isEqualTo: deviceId)
      .get();

  final unreadDocs = snapshot.docs.where((doc) {
    final readBy = List<String>.from(doc['readBy'] ?? []);
    return !readBy.contains(user.uid);
  });

  int critical = 0;
  int high = 0;
  int medium = 0;
  int low = 0;

  for (var doc in unreadDocs) {
    final priority = doc['priority'] ?? 'medium';
    switch (priority) {
      case 'critical':
        critical++;
        break;
      case 'high':
        high++;
        break;
      case 'medium':
        medium++;
        break;
      case 'low':
        low++;
        break;
    }
  }

  return {
    'critical': critical,
    'high': high,
    'medium': medium,
    'low': low,
  };
}