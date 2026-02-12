import 'package:cloud_firestore/cloud_firestore.dart';

/// Returns a real-time stream of notifications for a device,
/// ordered by time descending (newest first).
Stream<QuerySnapshot> getNotificationStream({
  required String deviceId,
}) {
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('deviceId', isEqualTo: deviceId)
      .orderBy('createdAt', descending: true)
      .snapshots();
}