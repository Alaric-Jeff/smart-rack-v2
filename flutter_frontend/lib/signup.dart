import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'terms_and_condtions.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isChecked = false;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Google Sign In
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // API Configuration
  static const String _baseUrl = 'http://localhost:3000';
  
  // Testing Mode - Set to true to skip backend calls during SSO testing
  static const bool _testingMode = true;

  // Colors
  final Color _backgroundColor = const Color(0xFFF5F5F5);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF1E2339);
  final Color _labelColor = const Color(0xFF5A6175);
  final Color _primaryColor = const Color(0xFF2762EA);

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Manual Signup
  Future<void> _handleSignup() async {
    if (!_isChecked) {
      _showSnackBar('You must agree to the Terms and Conditions', Colors.red);
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Step 1: Create Firebase Auth user
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Get Firebase UID
        String uuid = userCredential.user!.uid;

        // Step 2: Call your backend API
        final response = await http.post(
          Uri.parse('$_baseUrl/user/signup/manual'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'uuid': uuid,
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
          }),
        );

        if (mounted) {
          setState(() => _isLoading = false);

          if (response.statusCode == 200 || response.statusCode == 201) {
            _showSnackBar('Account created successfully!', Colors.green);
            // Navigate to home or next screen
            // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
          } else {
            // If backend fails, delete the Firebase user
            await userCredential.user?.delete();
            final errorData = jsonDecode(response.body);
            _showSnackBar('Error: ${errorData['message'] ?? 'Signup failed'}', Colors.red);
          }
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          String errorMessage = 'An error occurred';
          
          switch (e.code) {
            case 'email-already-in-use':
              errorMessage = 'This email is already registered';
              break;
            case 'invalid-email':
              errorMessage = 'Invalid email address';
              break;
            case 'weak-password':
              errorMessage = 'Password is too weak';
              break;
            case 'operation-not-allowed':
              errorMessage = 'Email/password accounts are not enabled';
              break;
            default:
              errorMessage = e.message ?? 'Signup failed';
          }
          _showSnackBar(errorMessage, Colors.red);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Network error: ${e.toString()}', Colors.red);
        }
      }
    }
  }

  // Google Sign Up
  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);

    try {
      // Step 1: Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Step 2: Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 3: Sign in to Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        if (_testingMode) {
          // TESTING MODE: Just show success without calling backend
          if (mounted) {
            setState(() => _isLoading = false);
            _showSnackBar(
              '✅ Google SSO Test Success!\nUID: ${user.uid}\nName: ${user.displayName ?? 'N/A'}\nEmail: ${user.email ?? 'N/A'}',
              Colors.green,
            );
            debugPrint('=== GOOGLE SSO TEST DATA ===');
            debugPrint('UUID: ${user.uid}');
            debugPrint('Display Name: ${user.displayName ?? googleUser.displayName ?? 'Google User'}');
            debugPrint('Email: ${user.email}');
            debugPrint('Photo URL: ${user.photoURL ?? googleUser.photoUrl}');
            debugPrint('Sign In Provider: google.com');
            debugPrint('==========================');
          }
        } else {
          // PRODUCTION MODE: Call backend API
          final response = await http.post(
            Uri.parse('$_baseUrl/user/signup/sso'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uuid': user.uid,
              'displayName': user.displayName ?? googleUser.displayName ?? 'Google User',
              'signInProvider': 'google.com',
              if (user.photoURL != null || googleUser.photoUrl != null)
                'photoUrl': user.photoURL ?? googleUser.photoUrl,
            }),
          );

          if (mounted) {
            setState(() => _isLoading = false);

            if (response.statusCode == 200 || response.statusCode == 201) {
              _showSnackBar('Google sign-up successful!', Colors.green);
              // Navigate to home screen
              // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
            } else {
              // If backend fails, delete the Firebase user and sign out
              await user.delete();
              await _googleSignIn.signOut();
              final errorData = jsonDecode(response.body);
              _showSnackBar('Error: ${errorData['message'] ?? 'Sign-up failed'}', Colors.red);
            }
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Google sign-up failed: ${e.message}', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
    }
  }

  // Facebook Sign Up
  Future<void> _handleFacebookSignUp() async {
    setState(() => _isLoading = true);

    try {
      // Step 1: Sign in with Facebook
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        final AccessToken? accessToken = result.accessToken;
        
        if (accessToken != null) {
          // Step 2: Create Firebase credential
          final OAuthCredential facebookAuthCredential = 
              FacebookAuthProvider.credential(accessToken.token);

          // Step 3: Sign in to Firebase
          UserCredential userCredential = 
              await _auth.signInWithCredential(facebookAuthCredential);
          User? user = userCredential.user;

          if (user != null) {
            // Step 4: Get user data from Facebook
            final userData = await FacebookAuth.instance.getUserData();
            
            if (_testingMode) {
              // TESTING MODE: Just show success without calling backend
              if (mounted) {
                setState(() => _isLoading = false);
                _showSnackBar(
                  '✅ Facebook SSO Test Success!\nUID: ${user.uid}\nName: ${userData['name'] ?? 'N/A'}\nEmail: ${userData['email'] ?? 'N/A'}',
                  Colors.green,
                );
                debugPrint('=== FACEBOOK SSO TEST DATA ===');
                debugPrint('UUID: ${user.uid}');
                debugPrint('Display Name: ${userData['name'] ?? user.displayName ?? 'Facebook User'}');
                debugPrint('Email: ${userData['email'] ?? user.email}');
                debugPrint('Photo URL: ${userData['picture']?['data']?['url']}');
                debugPrint('Sign In Provider: facebook.com');
                debugPrint('Full User Data: $userData');
                debugPrint('============================');
              }
            } else {
              // PRODUCTION MODE: Call backend API
              final response = await http.post(
                Uri.parse('$_baseUrl/user/signup/sso'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'uuid': user.uid,
                  'displayName': userData['name'] ?? user.displayName ?? 'Facebook User',
                  'signInProvider': 'facebook.com',
                  if (userData['picture'] != null && userData['picture']['data'] != null)
                    'photoUrl': userData['picture']['data']['url'],
                }),
              );

              if (mounted) {
                setState(() => _isLoading = false);

                if (response.statusCode == 200 || response.statusCode == 201) {
                  _showSnackBar('Facebook sign-up successful!', Colors.green);
                  // Navigate to home screen
                  // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
                } else {
                  // If backend fails, delete the Firebase user and log out
                  await user.delete();
                  await FacebookAuth.instance.logOut();
                  final errorData = jsonDecode(response.body);
                  _showSnackBar('Error: ${errorData['message'] ?? 'Sign-up failed'}', Colors.red);
                }
              }
            }
          }
        }
      } else if (result.status == LoginStatus.cancelled) {
        setState(() => _isLoading = false);
        _showSnackBar('Facebook sign-up cancelled', Colors.orange);
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Facebook sign-up failed: ${result.message}', Colors.red);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Facebook sign-up failed: ${e.message}', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Create Account',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textColor),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Names Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildLabelAndField(
                            label: 'FIRST NAME',
                            hint: 'First',
                            controller: _firstNameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Required';
                              if (value.length < 3) return 'Min 3 chars';
                              if (value.length > 27) return 'Max 27 chars';
                              if (!RegExp(r'^[A-Za-z]+$').hasMatch(value)) return 'Letters only';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildLabelAndField(
                            label: 'LAST NAME',
                            hint: 'Last',
                            controller: _lastNameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Required';
                              if (value.length < 3) return 'Min 3 chars';
                              if (value.length > 27) return 'Max 27 chars';
                              if (!RegExp(r'^[A-Za-z]+$').hasMatch(value)) return 'Letters only';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Email
                    _buildLabelAndField(
                      label: 'EMAIL',
                      hint: 'kirby@example.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your email';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Password
                    _buildLabelAndField(
                      label: 'PASSWORD',
                      hint: 'Create a strong password',
                      controller: _passwordController,
                      isPassword: true,
                      isVisible: _isPasswordVisible,
                      onVisibilityChanged: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Password is required';
                        if (value.length < 8) return 'Min 8 characters';
                        if (value.length > 50) return 'Max 50 characters';
                        if (!RegExp(r'^(?=.*[0-9])(?=.*[!@#$%^&*])[A-Za-z0-9!@#$%^&*]+$').hasMatch(value)) {
                          return 'Must have number & special char';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Confirm Password
                    _buildLabelAndField(
                      label: 'CONFIRM PASSWORD',
                      hint: 'Confirm your password',
                      controller: _confirmPasswordController,
                      isPassword: true,
                      isVisible: _isPasswordVisible,
                      onVisibilityChanged: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please confirm your password';
                        if (value != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Checkbox & Terms Navigation
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _isChecked,
                            activeColor: _primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (bool? value) => setState(() => _isChecked = value ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              text: 'I agree to the ',
                              style: TextStyle(color: _labelColor, fontSize: 13),
                              children: [
                                TextSpan(
                                  text: 'Terms and Conditions!',
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.blueAccent,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const TermsAndConditionsScreen(),
                                        ),
                                      );
                                    },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Create Account Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('CREATE ACCOUNT',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // SSO Divider
                    Row(
                      children: [
                        Expanded(child: Divider(thickness: 0.5, color: Colors.grey[400])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('Or continue with',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ),
                        Expanded(child: Divider(thickness: 0.5, color: Colors.grey[400])),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // SSO Buttons
                    _buildBigSocialButton(
                      "Google", 
                      'assets/google.png', 
                      Icons.g_mobiledata, 
                      _handleGoogleSignUp
                    ),
                    const SizedBox(height: 10),
                    _buildBigSocialButton(
                      "Facebook", 
                      'assets/facebook.png', 
                      Icons.facebook, 
                      _handleFacebookSignUp
                    ),

                    const SizedBox(height: 15),

                    // Login Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?',
                            style: TextStyle(color: _labelColor, fontSize: 13)),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Log In',
                              style: TextStyle(
                                  color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildLabelAndField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? Function(String?)? validator,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityChanged,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: _labelColor, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: isPassword ? !isVisible : false,
          keyboardType: keyboardType,
          style: TextStyle(color: _textColor, fontSize: 14),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _labelColor.withOpacity(0.7), fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            isDense: true,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off,
                        color: _labelColor, size: 20),
                    onPressed: onVisibilityChanged,
                  )
                : null,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _labelColor.withOpacity(0.3))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBigSocialButton(
      String text, String imagePath, IconData fallbackIcon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: OutlinedButton(
        onPressed: _isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath,
                height: 20,
                errorBuilder: (ctx, err, stack) =>
                    Icon(fallbackIcon, size: 20, color: const Color(0xFF2762EA))),
            const SizedBox(width: 10),
            Text(text,
                style:
                    const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}