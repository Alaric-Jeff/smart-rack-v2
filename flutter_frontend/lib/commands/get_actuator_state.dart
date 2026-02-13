import 'package:firebase_database/firebase_database.dart';

Future<String> get_actuator_state({required String deviceId}) async {
  try {
    final snapshot = await FirebaseDatabase.instance
        .ref('devices/$deviceId/actuator/state')
        .get();
    
    if (snapshot.exists) {
      return snapshot.value as String;
    }
    return 'retracted'; // Default
  } catch (e) {
    throw Exception('Failed to get actuator state: $e');
  }
}