import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> deleteNotification({
  required String id,
}) async {
  try {
    final db = FirebaseFirestore.instance;
    await db.collection('notifications').doc(id).delete();
  } catch (e) {
    rethrow;
  }
}