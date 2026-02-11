import 'package:cloud_firestore/cloud_firestore.dart';

/// Marks all notifications for a specific device as read
Future<void> markAllRead({
  required String deviceId,
}) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final QuerySnapshot snapshot = await firestore
      .collection('notifications')
      .where('deviceId', isEqualTo: deviceId)
      .where('isRead', isEqualTo: false)
      .get();

  if (snapshot.docs.isEmpty) return;

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
}