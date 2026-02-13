import 'package:firebase_database/firebase_database.dart';

Future<void> extend_actuator({required String deviceId}) async {
  try {
    await FirebaseDatabase.instance
        .ref('devices/$deviceId/actuator')
        .update({
      'target': 'extended',
      'lastCommandAt': ServerValue.timestamp,
    });
  } catch (e) {
    throw Exception('Failed to extend actuator: $e');
  }
}