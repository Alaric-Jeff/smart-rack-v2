import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> deleteImage({
  required String userId
}) async {
  final _db = FirebaseFirestore.instance;

  final userRef = await _db.collection('users').doc(userId).get();

  if(!userRef.exists){
    throw Exception('User not found');
  }

  final userData = userRef.data();

  if(userData == null || userData['image_public_id'] == null){
    throw Exception('No image to delete');
  }

  final publicId = userData['image_public_id'] as String;
  final url = Uri.parse("https://cloudinary-sign-worker.saldc-cloudflare.workers.dev");

  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'action': 'delete',
        'publicId': publicId,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception('Delete failed: ${error['message'] ?? 'Unknown error'}');
    }

    final result = jsonDecode(response.body);

    if (result['status'] != 'success') {
      throw Exception('Delete failed: ${result['message'] ?? 'Unknown error'}');
    }

    await _db.collection('users').doc(userId).set({
      'image_public_id': FieldValue.delete(),
      'image_url': FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('Image deleted successfully');
  } catch (e) {
    print('Error deleting image: $e');
    rethrow;
  }
}