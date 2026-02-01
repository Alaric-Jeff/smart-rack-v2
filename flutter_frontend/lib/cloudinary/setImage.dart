import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


Future<void> setImage({
  required String userId,
  required String fileBase64,
  String? oldPublicId
}) async {
  final _db = FirebaseFirestore.instance;

  final userRef = await _db.collection('users').doc(userId).get();

  if(!userRef.exists){
    throw Exception('User not found');
  }

  final url = Uri.parse("https://cloudinary-sign-worker.saldc-cloudflare.workers.dev");

  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'action': 'set',
        'fileBase64': fileBase64,
        if (oldPublicId != null) 'oldPublicId': oldPublicId,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception('Upload failed: ${error['message'] ?? 'Unknown error'}');
    }

    final result = jsonDecode(response.body);

    if (result['status'] != 'success') {
      throw Exception('Upload failed: ${result['message'] ?? 'Unknown error'}');
    }

    final publicId = result['public_id'];
    final imageUrl = result['url'];

    await _db.collection('users').doc(userId).set({
      'image_public_id': publicId,
      'image_url': imageUrl,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('Image uploaded successfully: $imageUrl');
  } catch (e) {
    print('Error uploading image: $e');
    rethrow;
  }
}