import 'package:cloud_firestore/cloud_firestore.dart';

/// Deletes all notifications for a specific device from the global notifications/ collection
Future<void> clearAllNotifications({
  required String deviceId,
}) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final QuerySnapshot snapshot = await firestore
      .collection('notifications')
      .where('deviceId', isEqualTo: deviceId)
      .get();

  if (snapshot.docs.isEmpty) return;

  WriteBatch batch = firestore.batch();
  int operationCount = 0;

  for (var doc in snapshot.docs) {
    batch.delete(doc.reference);
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