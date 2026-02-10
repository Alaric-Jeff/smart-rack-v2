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

    // Check current state if actuator exists
    if (actuator != null) {
      final currentState = actuator['state'];
      if (currentState == 'moving_retract' || currentState == 'retracted') {
        print('Actuator is already retracting or retracted');
        return;
      }
    }

    // Use set with merge to avoid update errors
    await docRef.set({
      'actuator': {
        'target': 'retract',
        'state': actuator?['state'] ?? 'extended',
        'lastCommandAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'user',
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // KEY FIX: Use merge instead of update

    print('Retract actuator command sent successfully');
  } catch (e) {
    print('Error in retract_actuator: $e');
    rethrow;
  }
}