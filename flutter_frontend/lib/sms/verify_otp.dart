import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> verifyOtp({
  required String phoneNumber,
  required String otp,
}) async {
  final url = Uri.parse('https://sms-otp-worker.saldc-cloudflare.workers.dev');

  final Map<String, dynamic> requestBody = {
    'action': 'verify',
    'phone_number': phoneNumber,
    'otp': otp,
  };

  final body = jsonEncode(requestBody);

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return responseData;
    } else {
      return {
        'status': 'error',
        'message': 'HTTP ${response.statusCode}: ${responseData['message'] ?? response.body}'
      };
    }
  } catch (e) {
    return {'status': 'error', 'message': e.toString()};
  }
}