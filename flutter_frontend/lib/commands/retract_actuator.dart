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

    // Block if already retracting or retracted
    if (actuator != null) {
      final currentState = actuator['state'] as String?;
      if (currentState == 'moving_retract' || currentState == 'retracted') {
        print('Actuator is already retracting or retracted');
        return;
      }
    }

    // Just write the target — ESP32 polls this and reacts
    // Do NOT touch 'state' here — only ESP32 writes state
    await docRef.set({
      'actuator': {
        'target': 'retract',
        'lastCommandAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'user',
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('Retract command written to Firestore');
  } catch (e) {
    print('Error in retract_actuator: $e');
    rethrow;
  }
}