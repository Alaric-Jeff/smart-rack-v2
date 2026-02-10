import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> extend_actuator({
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
      if (currentState == 'moving_extend' || currentState == 'extended') {
        print('Actuator is already extending or extended');
        return;
      }
    }

    // Use set with merge to avoid update errors
    await docRef.set({
      'actuator': {
        'target': 'extend',
        'state': actuator?['state'] ?? 'retracted',
        'lastCommandAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'user',
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // KEY FIX: Use merge instead of update

    print('Extend actuator command sent successfully');
  } catch (e) {
    print('Error in extend_actuator: $e');
    rethrow;
  }
}