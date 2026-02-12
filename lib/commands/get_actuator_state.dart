import 'package:cloud_firestore/cloud_firestore.dart';

Future<String?> get_actuator_state({
  required String deviceId,
}) async {
  try {
    final db = FirebaseFirestore.instance;
    final snapshot = await db.collection('devices').doc(deviceId).get();

    if (!snapshot.exists) {
      throw Exception('Device not found');
    }

    final data = snapshot.data();
    if (data == null) throw Exception('Device data is null');

    final actuator = data['actuator'] as Map<String, dynamic>?;
    final state = actuator?['state'] as String?;

    if (state == 'extended' || state == 'retracted') {
      return state;
    }

    // moving_extend / moving_retract / null = not stable
    throw Exception('Actuator state is not stable yet: $state');
  } catch (e) {
    rethrow;
  }
}