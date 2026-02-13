import 'package:firebase_database/firebase_database.dart';

Future<void> retract_actuator({required String deviceId}) async {
  try {
    await FirebaseDatabase.instance
        .ref('devices/$deviceId/actuator')
        .update({
      'target': 'retracted',
      'lastCommandAt': ServerValue.timestamp,
    });
  } catch (e) {
    throw Exception('Failed to retract actuator: $e');
  }
}