import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Deletes all notifications for the current user using batch operations
/// 
/// Usage:
/// ```dart
/// await clearAllNotifications();
/// ```
Future<void> clearAllNotifications() async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    throw Exception('User not authenticated');
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  // Get all notification documents
  final QuerySnapshot snapshot = await firestore
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .get();

  if (snapshot.docs.isEmpty) return;

  // Delete in batches (Firestore batch limit is 500 operations)
  WriteBatch batch = firestore.batch();
  int operationCount = 0;

  for (var doc in snapshot.docs) {
    batch.delete(doc.reference);
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

/// Deletes all notifications associated with a specific device
/// 
/// Usage:
/// ```dart
/// await clearAllNotificationsByDevice(deviceId: '00:1A:2B:3C:4D:5E');
/// ```
Future<void> clearAllNotificationsByDevice({
  required String deviceId,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Query notifications for this specific device
    final QuerySnapshot snapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('deviceId', isEqualTo: deviceId)
        .get();

    if (snapshot.docs.isEmpty) {
      print('No notifications found for device: $deviceId');
      return;
    }

    print('Found ${snapshot.docs.length} notifications for device: $deviceId');

    // Delete in batches (Firestore batch limit is 500 operations)
    WriteBatch batch = firestore.batch();
    int operationCount = 0;

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
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

    print('Successfully deleted ${snapshot.docs.length} notifications for device: $deviceId');
  } catch (e) {
    print('Error clearing device notifications: $e');
    rethrow;
  }
}