import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Marks all unread notifications as read using batch operations
/// 
/// Usage:
/// ```dart
/// await markAllNotificationsRead();
/// ```
Future<void> markAllNotificationsRead() async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    throw Exception('User not authenticated');
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  // Get only unread notifications
  final QuerySnapshot snapshot = await firestore
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .where('isRead', isEqualTo: false)
      .get();

  if (snapshot.docs.isEmpty) return;

  // Update in batches (Firestore batch limit is 500 operations)
  WriteBatch batch = firestore.batch();
  int operationCount = 0;

  for (var doc in snapshot.docs) {
    batch.update(doc.reference, {'isRead': true});
    operationCount++;

    // Commit batch if we reach 500 operations
    if (operationCount == 500) {
      await batch.commit();
      batch = firestore.batch();
      operationCount = 0;
    }
  }

  // Commit remaining operations
  if (operationCount > 0) {
    await batch.commit();
  }
}

/// Marks specific notifications as read by their IDs
/// 
/// Usage:
/// ```dart
/// await markNotificationsReadByIds(
///   notificationIds: ['notif1', 'notif2', 'notif3']
/// );
/// ```
Future<void> markNotificationsReadByIds({
  required List<String> notificationIds,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      throw Exception('User not authenticated');
    }

    if (notificationIds.isEmpty) {
      print('No notification IDs provided');
      return;
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Update in batches (Firestore batch limit is 500 operations)
    WriteBatch batch = firestore.batch();
    int operationCount = 0;

    for (String notifId in notificationIds) {
      final docRef = firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notifId);

      batch.update(docRef, {'isRead': true});
      operationCount++;

      // Commit batch if we reach 500 operations
      if (operationCount == 500) {
        await batch.commit();
        batch = firestore.batch();
        operationCount = 0;
      }
    }

    // Commit remaining operations
    if (operationCount > 0) {
      await batch.commit();
    }

    print('Marked ${notificationIds.length} notifications as read');
  } catch (e) {
    print('Error marking notifications as read: $e');
    rethrow;
  }
}

/// Marks specific notifications as unread by their IDs
/// 
/// Usage:
/// ```dart
/// await markNotificationsUnreadByIds(
///   notificationIds: ['notif1', 'notif2', 'notif3']
/// );
/// ```
Future<void> markNotificationsUnreadByIds({
  required List<String> notificationIds,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      throw Exception('User not authenticated');
    }

    if (notificationIds.isEmpty) {
      print('No notification IDs provided');
      return;
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    WriteBatch batch = firestore.batch();
    int operationCount = 0;

    for (String notifId in notificationIds) {
      final docRef = firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notifId);

      batch.update(docRef, {'isRead': false});
      operationCount++;

      if (operationCount == 500) {
        await batch.commit();
        batch = firestore.batch();
        operationCount = 0;
      }
    }

    if (operationCount > 0) {
      await batch.commit();
    }

    print('Marked ${notificationIds.length} notifications as unread');
  } catch (e) {
    print('Error marking notifications as unread: $e');
    rethrow;
  }
}

/// Marks all notifications from a specific device as read
/// 
/// Usage:
/// ```dart
/// await markDeviceNotificationsRead(deviceId: '00:1A:2B:3C:4D:5E');
/// ```
Future<void> markDeviceNotificationsRead({
  required String deviceId,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Get unread notifications for this device
    final QuerySnapshot snapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('deviceId', isEqualTo: deviceId)
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) {
      print('No unread notifications for device: $deviceId');
      return;
    }

    WriteBatch batch = firestore.batch();
    int operationCount = 0;

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
      operationCount++;

      if (operationCount == 500) {
        await batch.commit();
        batch = firestore.batch();
        operationCount = 0;
      }
    }

    if (operationCount > 0) {
      await batch.commit();
    }

    print('Marked ${snapshot.docs.length} notifications as read for device: $deviceId');
  } catch (e) {
    print('Error marking device notifications as read: $e');
    rethrow;
  }
}