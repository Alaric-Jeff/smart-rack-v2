//signup.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Note: Ensure you removed 'terms_and_condtions.dart' import if you are using the modal now,
// or keep it if you still have the file.
import 'home.dart';

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
  bool _canResendEmail = true;
  int _resendCooldownSeconds = 0;

  // Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Firebase Auth & Firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Google Sign In
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Colors
  final Color _backgroundColor = const Color(0xFFF5F5F5);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF1E2339);
  final Color _labelColor = const Color(0xFF5A6175);
  final Color _primaryColor = const Color(0xFF2762EA);

  @override
  void initState() {
    super.initState();
    // Add listener to email controller for auto-complete
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    final text = _emailController.text;
    
    // Logic kept as per your original placeholder (empty for now to avoid bugs)
    if (text.isNotEmpty && !text.contains('@')) {
       // logic here
    }
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_onEmailChanged); // Clean up listener
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- NEW FEATURE: Helper to append @gmail.com ---
  void _appendGmail() {
    final currentText = _emailController.text;
    // Only append if not empty and doesn't have @ symbol yet
    if (currentText.isNotEmpty && !currentText.contains('@')) {
      setState(() {
        _emailController.text = '$currentText@gmail.com';
        // Move cursor to end
        _emailController.selection = TextSelection.fromPosition(
          TextPosition(offset: _emailController.text.length),
        );
      });
    }
  }

  // --- NEW FEATURE: Terms & Conditions Modal ---
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Terms & Conditions", style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Scrollbar(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("1. Acceptance", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("By creating an account, you agree to comply with all terms regarding the use of the Smart Rack system."),
                SizedBox(height: 12),
                Text("2. User Responsibilities", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account."),
                SizedBox(height: 12),
                Text("3. Hardware Usage", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("The Smart Rack app controls physical hardware. Please ensure the rack area is clear before operating remotely. We are not liable for damage caused by improper use."),
                SizedBox(height: 12),
                Text("4. Data Privacy", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("We collect your email and device usage statistics to improve the service. We do not sell your personal data."),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _isChecked = true); // Auto-check the box when they agree
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("I Agree"),
          ),
        ],
      ),
    );
  }

  // ✨ Enhanced Manual Signup with Email Verification
  Future<void> _handleSignup() async {
    if (!_isChecked) {
      _showSnackBar('Please agree to the Terms and Conditions to continue', Colors.red);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix the errors in the form before submitting', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Create Firebase Auth user
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      String uuid = userCredential.user!.uid;

      // Step 2: Send email verification
      await userCredential.user!.sendEmailVerification();

      // Step 3: Create user document in Firestore with emailVerified flag
      await _firestore.collection('users').doc(uuid).set({
        'uuid': uuid,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'displayName': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'email': _emailController.text.trim(),
        'contactNumber': null,
        'signInProvider': 'manual',
        'photoUrl': null,
        'address': null,
        'devices': [],
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isLoading = false);
        _showEmailVerificationDialog(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMessage = 'An error occurred during signup';
        
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'This email address is already registered. Please use a different email or try logging in.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address format is invalid. Please check and try again.';
            break;
          case 'weak-password':
            errorMessage = 'The password provided is too weak. Please use a stronger password.';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Email/password accounts are currently disabled. Please contact support.';
            break;
          default:
            errorMessage = e.message ?? 'Signup failed. Please try again.';
        }
        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        
        try {
          await _auth.currentUser?.delete();
        } catch (deleteError) {
          debugPrint('Failed to delete user after Firestore error: $deleteError');
        }
        
        _showSnackBar('An unexpected error occurred. Please try again later.', Colors.red);
      }
    }
  }

  // Email Verification Dialog
  void _showEmailVerificationDialog(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.mark_email_unread, color: _primaryColor, size: 28),
                  const SizedBox(width: 10),
                  const Text('Verify Your Email'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'We\'ve sent a verification email to:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please check your inbox and click the verification link to activate your account.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _canResendEmail
                      ? () async {
                          try {
                            await user.sendEmailVerification();
                            
                            // Start cooldown and update dialog
                            setState(() {
                              _canResendEmail = false;
                              _resendCooldownSeconds = 60;
                            });
                            
                            _showSnackBar('Verification email resent successfully', Colors.green);
                            
                            // Countdown timer that updates both main state and dialog state
                            Future.doWhile(() async {
                              await Future.delayed(const Duration(seconds: 1));
                              if (mounted) {
                                setState(() {
                                  _resendCooldownSeconds--;
                                  if (_resendCooldownSeconds <= 0) {
                                    _canResendEmail = true;
                                  }
                                });
                                setDialogState(() {}); // Update dialog UI
                              }
                              return _resendCooldownSeconds > 0 && mounted;
                            });
                          } on FirebaseAuthException catch (e) {
                            if (e.code == 'too-many-requests') {
                              _showSnackBar('Too many requests. Please wait before trying again.', Colors.orange);
                            } else {
                              _showSnackBar('Failed to resend email. Please try again later.', Colors.red);
                            }
                          }
                        }
                      : null,
                  child: Text(
                    _canResendEmail
                        ? 'Resend Email'
                        : 'Resend in ${_resendCooldownSeconds}s',
                    style: TextStyle(
                      color: _canResendEmail ? _primaryColor : Colors.grey,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await user.reload();
                      User? refreshedUser = _auth.currentUser;
                      
                      if (refreshedUser != null && refreshedUser.emailVerified) {
                        await _firestore.collection('users').doc(refreshedUser.uid).update({
                          'emailVerified': true,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        
                        Navigator.of(dialogContext).pop();
                        _showSnackBar('Email verified! Account created successfully.', Colors.green);
                        
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                          );
                        }
                      } else {
                        _showSnackBar('Email not verified yet. Please check your inbox and click the verification link.', Colors.orange);
                      }
                    } catch (e) {
                      _showSnackBar('Failed to verify email status. Please try again.', Colors.red);
                      debugPrint('Verification check error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('I\'ve Verified'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✨ Enhanced Google Sign Up with Auto-Login
  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        String uuid = user.uid;
        
        DocumentSnapshot existingUser = await _firestore.collection('users').doc(uuid).get();
        
        if (existingUser.exists) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showSnackBar('Welcome back! Signing you in...', Colors.green);
            
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
          return;
        }

        String displayName = user.displayName ?? googleUser.displayName ?? 'Google User';
        List<String> nameParts = displayName.split(' ');
        String firstName = nameParts.isNotEmpty ? nameParts[0] : '';
        String lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        await _firestore.collection('users').doc(uuid).set({
          'uuid': uuid,
          'displayName': displayName,
          'firstName': firstName,
          'lastName': lastName,
          'email': user.email,
          'contactNumber': null,
          'signInProvider': 'google.com',
          'photoUrl': user.photoURL ?? googleUser.photoUrl,
          'address': null,
          'devices': [],
          'emailVerified': user.emailVerified,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Google sign-up successful! Welcome!', Colors.green);
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        
        String errorMessage = 'Google authentication failed';
        switch (e.code) {
          case 'account-exists-with-different-credential':
            errorMessage = 'An account with this email already exists using a different sign-in method.';
            break;
          case 'invalid-credential':
            errorMessage = 'Invalid credentials provided. Please try again.';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Google sign-in is currently disabled. Please contact support.';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled. Please contact support.';
            break;
          default:
            errorMessage = e.message ?? 'Google authentication failed. Please try again.';
        }
        
        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        
        try {
          await _googleSignIn.signOut();
          
          if (_auth.currentUser != null) {
            DocumentSnapshot check = await _firestore
                .collection('users')
                .doc(_auth.currentUser!.uid)
                .get();
            
            if (!check.exists) {
              await _auth.currentUser?.delete();
            }
          }
        } catch (cleanupError) {
          debugPrint('Cleanup error: $cleanupError');
        }
        
        _showSnackBar('An unexpected error occurred. Please try again.', Colors.red);
        debugPrint('Google SSO Error: $e');
      }
    }
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
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 20,
                    offset: Offset(0, 5),
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
                              if (value == null || value.isEmpty) {
                                return 'First name is required';
                              }
                              
                              String trimmed = value.trim();
                              
                              if (trimmed.length < 3) {
                                return 'Must be at least 3 characters';
                              }
                              if (trimmed.length > 50) {
                                return 'Must not exceed 50 characters';
                              }
                              
                              // Check for numbers
                              if (RegExp(r'[0-9]').hasMatch(trimmed)) {
                                return 'Numbers are not allowed';
                              }
                              
                              // Check for double spaces
                              if (trimmed.contains('  ')) {
                                return 'Multiple spaces are not allowed';
                              }
                              
                              // Check for invalid special characters
                              if (RegExp(r'[!@#$%^&*(),.?":{}|<>+=\[\]\\\/;`~_]').hasMatch(trimmed)) {
                                return 'Special characters are not allowed';
                              }
                              
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
                              if (value == null || value.isEmpty) {
                                return 'Last name is required';
                              }
                              
                              String trimmed = value.trim();
                              
                              if (trimmed.length < 3) {
                                return 'Must be at least 3 characters';
                              }
                              if (trimmed.length > 50) {
                                return 'Must not exceed 50 characters';
                              }
                              
                              // Check for numbers
                              if (RegExp(r'[0-9]').hasMatch(trimmed)) {
                                return 'Numbers are not allowed';
                              }
                              
                              // Check for double spaces
                              if (trimmed.contains('  ')) {
                                return 'Multiple spaces are not allowed';
                              }
                              
                              // Check for invalid special characters
                              if (RegExp(r'[!@#$%^&*(),.?":{}|<>+=\[\]\\\/;`~_]').hasMatch(trimmed)) {
                                return 'Special characters are not allowed';
                              }
                              
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Email with @gmail.com helper (UPDATED SECTION)
                    _buildLabelAndField(
                      label: 'EMAIL',
                      hint: 'kirby@example.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      suffix: IconButton(
                        icon: const Text(
                          '@gmail.com',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: _appendGmail,
                        tooltip: 'Quick add @gmail.com',
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
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 8) {
                          return 'Must be at least 8 characters';
                        }
                        if (value.length > 50) {
                          return 'Must not exceed 50 characters';
                        }
                        if (!RegExp(r'[A-Z]').hasMatch(value)) {
                          return 'Must contain at least one uppercase letter';
                        }
                        if (!RegExp(r'[a-z]').hasMatch(value)) {
                          return 'Must contain at least one lowercase letter';
                        }
                        if (!RegExp(r'[0-9]').hasMatch(value)) {
                          return 'Must contain at least one number';
                        }
                        if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                          return 'Must contain at least one special character';
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
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Checkbox & Terms (UPDATED SECTION)
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
                                  text: 'Terms and Conditions',
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.blueAccent,
                                  ),
                                  // Calls the new modal function instead of navigation
                                  recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
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
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
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

                    // Google SSO Button
                    _buildBigSocialButton(
                      "Google", 
                      'assets/google.png', 
                      Icons.g_mobiledata, 
                      _handleGoogleSignUp
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

  // Updated to accept 'suffix' widget for the @gmail button
  Widget _buildLabelAndField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? Function(String?)? validator,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityChanged,
    TextInputType? keyboardType,
    Widget? suffix, // Optional custom suffix
  }) {
    // Determine suffix icon: either custom suffix, password toggle, or null
    Widget? effectiveSuffix;
    if (suffix != null) {
      effectiveSuffix = suffix;
    } else if (isPassword) {
      effectiveSuffix = IconButton(
        icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off,
            color: _labelColor, size: 20),
        onPressed: onVisibilityChanged,
      );
    }

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
            suffixIcon: effectiveSuffix,
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
            errorMaxLines: 2,
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