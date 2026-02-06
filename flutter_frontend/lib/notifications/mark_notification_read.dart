import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> markNotificationRead({
  required String notifId,
}) async {
  try {
    final db = FirebaseFirestore.instance;

    await db.collection('notifications').doc(notifId).update({
      'isRead': true,
    });
    
  } catch (e) {
    rethrow;
  }
}
