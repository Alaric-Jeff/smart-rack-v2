import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Worker URL
  static const String workerUrl = 'https://my-worker.saldc-cloudflare.workers.dev';

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _emailSent = false;
  bool _isVerified = false;
  String _userEmail = '';
  String? _resultToken;

  Timer? _pollingTimer;

  // Colors
  final Color _backgroundColor = const Color(0xFFF5F5F5);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF1E2339);
  final Color _labelColor = const Color(0xFF5A6175);
  final Color _primaryColor = const Color(0xFF2762EA);

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // Step 1: Send verification email via worker
  Future<void> _sendVerificationEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String email = _emailController.text.trim();

      // Check if user exists in Firestore
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (result.docs.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('No account found with this email address', Colors.red);
        }
        return;
      }

      // Send verification email via worker
      final response = await http.post(
        Uri.parse('$workerUrl/send-verification'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'type': 'forgot-password',
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - please check your internet connection');
        },
      );

      // Debug logging
      debugPrint('=== WORKER REQUEST ===');
      debugPrint('URL: $workerUrl/send-verification');
      debugPrint('Email: $email');
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('======================');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('Success: ${responseData['success']}');
        debugPrint('Message: ${responseData['message']}');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _emailSent = true;
            _userEmail = email;
          });
          _showSnackBar(
            'Verification email sent! Please check your inbox and confirm.',
            Colors.green,
          );
          
          // Start polling for verification
          _startPollingForVerification();
        }
      } else {
        final errorData = json.decode(response.body);
        debugPrint('Error from worker: ${errorData['error']}');
        throw Exception(errorData['error'] ?? 'Failed to send email');
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(
          'Request timeout. Please check your internet connection.',
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Exception: $e');
        _showSnackBar(
          'Failed to send verification email. Please try again.',
          Colors.red,
        );
      }
    }
  }

  // Poll worker to check if email was verified
  void _startPollingForVerification() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        // Query Firestore for verification results
        final results = await _firestore
            .collection('verification_results')
            .where('email', isEqualTo: _userEmail)
            .where('type', isEqualTo: 'forgot-password')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (results.docs.isNotEmpty) {
          final doc = results.docs.first;
          final verified = doc['verified'] as bool;
          final resultToken = doc['resultToken'] as String;

          if (verified) {
            timer.cancel();
            if (mounted) {
              setState(() {
                _isVerified = true;
                _resultToken = resultToken;
              });
              _showSnackBar('Email verified! You can now reset your password.', Colors.green);
            }
          } else {
            // User denied the request
            timer.cancel();
            if (mounted) {
              setState(() {
                _emailSent = false;
              });
              _showSnackBar('Password reset request was denied.', Colors.red);
            }
          }
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });

    // Stop polling after 10 minutes
    Future.delayed(const Duration(minutes: 10), () {
      _pollingTimer?.cancel();
    });
  }

  // Step 2: Reset password after verification
  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String newPassword = _newPasswordController.text;

      // Get user document
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: _userEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('User not found');
      }

      final userDoc = userQuery.docs.first;
      final userId = userDoc.id;

      // Update password in Firebase Auth
      // Note: For this to work, you need to sign in the user first or use Admin SDK
      // Alternative: Store hashed password in Firestore
      
      // For now, we'll just update Firestore
      // In production, you should hash the password before storing
      await _firestore.collection('users').doc(userId).update({
        'password': newPassword, // TODO: Hash this password!
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to reset password: ${e.toString()}', Colors.red);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Password Reset Successful'),
            ],
          ),
          content: const Text(
            'Your password has been reset successfully. You can now log in with your new password.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to login
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2762EA),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Go to Login'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textColor),
          onPressed: () {
            _pollingTimer?.cancel();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Reset Password',
          style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.08,
            vertical: 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 20,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: _buildCurrentStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (!_emailSent) {
      return _buildEmailForm();
    } else if (_emailSent && !_isVerified) {
      return _buildWaitingForVerification();
    } else {
      return _buildResetPasswordForm();
    }
  }

  // Step 1 UI: Email Input Form
  Widget _buildEmailForm() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(
              Icons.lock_reset,
              size: 64,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Enter your email address and we\'ll send you a verification email.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _labelColor,
              ),
            ),
          ),
          const SizedBox(height: 30),

          Text(
            'EMAIL ADDRESS',
            style: TextStyle(
              color: _labelColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: _textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'kirby@example.com',
              hintStyle: TextStyle(color: _labelColor.withOpacity(0.7)),
              prefixIcon: Icon(Icons.email_outlined, color: _labelColor),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _labelColor.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Email address is required';
              }
              if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendVerificationEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : const Text(
                      'SEND VERIFICATION EMAIL',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Back to Login',
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 2 UI: Waiting for Email Verification
  Widget _buildWaitingForVerification() {
    return Column(
      children: [
        Center(
          child: Icon(
            Icons.mark_email_unread,
            size: 64,
            color: _primaryColor,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Check Your Email',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'We sent a verification email to:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _labelColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _userEmail,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
        ),
        const SizedBox(height: 30),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Waiting for email verification...\n\nPlease click "YES, IT WAS ME" in the email to continue.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _textColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _sendVerificationEmail,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'RESEND EMAIL',
              style: TextStyle(
                color: _primaryColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: TextButton(
            onPressed: () {
              _pollingTimer?.cancel();
              setState(() {
                _emailSent = false;
              });
            },
            child: Text(
              'Change Email Address',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Step 3 UI: Password Reset Form
  Widget _buildResetPasswordForm() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(
              Icons.vpn_key,
              size: 64,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Set New Password',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Enter your new password below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _labelColor,
              ),
            ),
          ),
          const SizedBox(height: 30),

          // New Password
          Text(
            'NEW PASSWORD',
            style: TextStyle(
              color: _labelColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _newPasswordController,
            obscureText: !_isPasswordVisible,
            style: TextStyle(color: _textColor, fontSize: 14),
            inputFormatters: [
              LengthLimitingTextInputFormatter(50),
            ],
            decoration: InputDecoration(
              hintText: 'Enter new password',
              hintStyle: TextStyle(color: _labelColor.withOpacity(0.7)),
              prefixIcon: Icon(Icons.lock_outline, color: _labelColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: _labelColor,
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _labelColor.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters long';
              }
              if (!RegExp(r'[A-Z]').hasMatch(value)) {
                return 'Password must contain at least one uppercase letter';
              }
              if (!RegExp(r'[0-9]').hasMatch(value)) {
                return 'Password must contain at least one number';
              }
              if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                return 'Password must contain at least one special character';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password
          Text(
            'CONFIRM PASSWORD',
            style: TextStyle(
              color: _labelColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_isPasswordVisible,
            style: TextStyle(color: _textColor, fontSize: 14),
            inputFormatters: [
              LengthLimitingTextInputFormatter(50),
            ],
            decoration: InputDecoration(
              hintText: 'Confirm new password',
              hintStyle: TextStyle(color: _labelColor.withOpacity(0.7)),
              prefixIcon: Icon(Icons.lock_outline, color: _labelColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: _labelColor,
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _labelColor.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : const Text(
                      'RESET PASSWORD',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}