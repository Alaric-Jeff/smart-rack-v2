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

    // Update actuator with complete schema
    // This will auto-create the actuator map if it doesn't exist
    await docRef.update({
      'actuator': {
        'target': 'extend',
        'state': actuator?['state'] ?? 'retracted', // Keep current state or default to retracted
        'lastCommandAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'user', // Set source as user since command came from mobile
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('Extend actuator command sent successfully');
  } catch (e) {
    print('Error in extend_actuator: $e');
    rethrow;
  }
}