import 'package:cloud_firestore/cloud_firestore.dart';

/// Returns a real-time stream of the unread notification count for a device.
Stream<int> getUnreadCountStream({
  required String deviceId,
}) {
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('deviceId', isEqualTo: deviceId)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
}

/// One-time fetch of unread count for a device.
Future<int> getUnreadCount({
  required String deviceId,
}) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('notifications')
      .where('deviceId', isEqualTo: deviceId)
      .where('isRead', isEqualTo: false)
      .get();

  return snapshot.docs.length;
}