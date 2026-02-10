import 'package:cloud_firestore/cloud_firestore.dart';

Future<String?> get_actuator_state({
  required String deviceId,
}) async {
  try {
    final _db = FirebaseFirestore.instance;

    final deviceRef =
        await _db.collection('devices').doc(deviceId).get();

    if (!deviceRef.exists) {
      throw Exception('Device not found');
    }

    final deviceData = deviceRef.data();
    if (deviceData == null) {
      throw Exception('Device data is null');
    }

    final actuator = deviceData['actuator'] as Map<String, dynamic>?;

    final state = actuator?['state'] as String?;

    if (state == 'extended' || state == 'retracted') {
      return state;
    }

    // Anything else means actuator is moving or unknown
    throw Exception('Actuator state is not stable yet: $state');
  } catch (e) {
    rethrow;
  }
}
