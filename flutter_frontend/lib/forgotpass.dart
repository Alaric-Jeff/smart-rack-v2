import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  
  // Create the Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;

  // Colors to match your theme
  final Color _backgroundColor = const Color(0xFFF5F5F5);
  final Color _primaryColor = const Color(0xFF2962FF); // Updated to your Blue
  final Color _textColor = const Color(0xFF1E2339);
  final Color _labelColor = const Color(0xFF5A6175);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // --- REAL BACKEND LOGIC ---
  Future<void> _handleResetPassword() async {
    // 1. Validate the text field
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 2. Send the official Firebase Reset Link
        await _auth.sendPasswordResetEmail(email: _emailController.text.trim());

        if (mounted) {
          // 3. Show Success Dialog
          // We use a Dialog instead of a SnackBar so the user stops 
          // and reads the instruction to check their email.
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Check Your Email", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Text(
                "We have sent a secure password reset link to:\n${_emailController.text}\n\nPlease check your inbox (and spam folder) and click the link to create a new password.",
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to login screen
                  },
                  child: Text("OK", style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        // 4. Handle Specific Firebase Errors
        String errorMessage = "An error occurred. Please try again.";
        
        if (e.code == 'user-not-found') {
          errorMessage = "No registered user found with this email.";
        } else if (e.code == 'invalid-email') {
          errorMessage = "The email address is not valid.";
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        // Handle generic errors
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        // Stop loading spinner
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. RESPONSIVE: Get screen dimensions
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          // 2. RESPONSIVE: Dynamic padding based on device width
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08, vertical: 20),
          child: ConstrainedBox(
            // 3. TABLET/WIDE PHONE SUPPORT: Limits the width
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back, size: 18, color: _textColor),
                              const SizedBox(width: 8),
                              Text(
                                'Back',
                                style: TextStyle(
                                  color: _textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title & Instructions
                        Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your email to receive a reset link',
                          style: TextStyle(color: _labelColor, fontSize: 14),
                        ),
                        const SizedBox(height: 32),

                        // Email Field
                        Text(
                          'EMAIL',
                          style: TextStyle(
                            color: _labelColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: _textColor),
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            hintStyle: TextStyle(color: _labelColor.withOpacity(0.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
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
                                borderSide: const BorderSide(color: Colors.red, width: 2)
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter your email';
                            if (!value.contains('@')) return 'Enter a valid email address';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Send Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleResetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              disabledBackgroundColor: _primaryColor.withOpacity(0.6),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    'SEND RESET LINK',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}