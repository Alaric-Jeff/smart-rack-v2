import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> retract_actuator({
  required String deviceId,
}) async {
  try {
    final db = FirebaseFirestore.instance;
    final docRef = db.collection('devices').doc(deviceId);

    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw Exception('Device not found');
    }

    final data = snapshot.data()!;
    final actuator = data['actuator'] as Map<String, dynamic>?;

    if (actuator == null) {
      throw Exception('Actuator data missing');
    }

    final currentState = actuator['state'];
    if (currentState == 'moving_retract' || currentState == 'retracted') {
      return;
    }

    await docRef.set({
      'actuator': {
        'target': 'retract',
        'updatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  } catch (e) {
    rethrow;
  }
}
