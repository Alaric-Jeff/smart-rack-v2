import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'signup.dart';
import 'forgotpass.dart';
import 'terms_and_condtions.dart';
import 'home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SmartRackApp());
}

class SmartRackApp extends StatelessWidget {
  const SmartRackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'sans-serif'),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isObscure = true;
  bool _isLoading = false;

  // Firebase Auth & Firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Google Sign In
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ✨ Enhanced Login with Email Verification Check
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Sign in with Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user == null) {
        throw Exception('Authentication failed. Please try again.');
      }

      // 2. Check if email is verified
      await user.reload(); // Refresh user data to get latest verification status
      user = _auth.currentUser; // Get updated user object

      if (user != null && !user.emailVerified) {
        // Email not verified - sign out and show verification dialog
        await _auth.signOut();
        
        if (mounted) {
          setState(() => _isLoading = false);
          _showEmailVerificationRequiredDialog(user);
        }
        return;
      }

      // 3. Check if User Document exists in Firestore
      String uid = user!.uid;
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();

      // Auto-fix: Create missing Firestore document
      if (!userDoc.exists) {
        debugPrint("User authenticated but missing Firestore doc. Creating one now...");
        
        await _firestore.collection('users').doc(uid).set({
          'email': user.email ?? _emailController.text.trim(),
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'displayName': user.displayName ?? 'User',
          'role': 'user',
          'emailVerified': user.emailVerified,
        });
        
        debugPrint("Missing document created successfully.");
      } else {
        // Update emailVerified status in Firestore if it's out of sync
        if (userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          if (userData['emailVerified'] != user.emailVerified) {
            await _firestore.collection('users').doc(uid).update({
              'emailVerified': user.emailVerified,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Welcome back!', Colors.green);

        // Navigate to home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMessage = 'Login failed';

        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No account found with this email address. Please check your email or sign up.';
            break;
          case 'wrong-password':
            errorMessage = 'Incorrect password. Please try again or reset your password.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address format is invalid. Please check and try again.';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled. Please contact support for assistance.';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many failed login attempts. Please try again later or reset your password.';
            break;
          case 'invalid-credential':
            errorMessage = 'Invalid email or password. Please verify your credentials and try again.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network connection failed. Please check your internet connection and try again.';
            break;
          default:
            errorMessage = e.message ?? 'An unexpected error occurred during login. Please try again.';
        }
        
        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('An unexpected error occurred. Please check your connection and try again.', Colors.red);
        debugPrint('Login error: $e');
      }
    }
  }

  // Email Verification Required Dialog
  void _showEmailVerificationRequiredDialog(User user) {
    // Store email and password for re-authentication
    final String userEmail = user.email ?? _emailController.text.trim();
    final String userPassword = _passwordController.text.trim();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.mark_email_unread, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Email Verification Required',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please verify your email address before logging in.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text(
                'A verification email was sent to:',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 6),
              Text(
                userEmail,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2762EA),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Check your inbox and click the verification link.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  // Re-authenticate to send verification email
                  UserCredential reAuthCred = await _auth.signInWithEmailAndPassword(
                    email: userEmail,
                    password: userPassword,
                  );
                  
                  if (reAuthCred.user != null) {
                    await reAuthCred.user!.sendEmailVerification();
                    await _auth.signOut(); // Sign out again after sending
                    _showSnackBar('Verification email sent successfully. Please check your inbox.', Colors.green);
                  }
                } on FirebaseAuthException catch (e) {
                  if (e.code == 'too-many-requests') {
                    _showSnackBar('Too many requests. Please wait a few minutes before trying again.', Colors.orange);
                  } else {
                    _showSnackBar('Failed to send verification email. Please try again later.', Colors.red);
                  }
                } catch (e) {
                  _showSnackBar('Failed to send verification email. Please try again later.', Colors.red);
                  debugPrint('Resend email error: $e');
                }
              },
              child: const Text('Resend Email'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Re-authenticate to check verification status
                  UserCredential reAuthCred = await _auth.signInWithEmailAndPassword(
                    email: userEmail,
                    password: userPassword,
                  );
                  
                  await reAuthCred.user?.reload();
                  User? refreshedUser = _auth.currentUser;
                  
                  if (refreshedUser != null && refreshedUser.emailVerified) {
                    // Update Firestore
                    await _firestore.collection('users').doc(refreshedUser.uid).update({
                      'emailVerified': true,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    
                    Navigator.of(context).pop();
                    _showSnackBar('Email verified successfully! Logging you in...', Colors.green);
                    
                    // Navigate to home screen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  } else {
                    // Sign out if still not verified
                    await _auth.signOut();
                    _showSnackBar('Email not verified yet. Please check your inbox and click the verification link.', Colors.orange);
                  }
                } on FirebaseAuthException catch (e) {
                  await _auth.signOut();
                  _showSnackBar('Unable to verify email status. Please try again.', Colors.red);
                  debugPrint('Verification check error: ${e.code}');
                } catch (e) {
                  await _auth.signOut();
                  _showSnackBar('Unable to verify email status. Please try again.', Colors.red);
                  debugPrint('Verification check error: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2762EA),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('I\'ve Verified'),
            ),
          ],
        );
      },
    );
  }

  // Google SSO Login with Email Verification Check
  Future<void> _handleGoogleSignIn() async {
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
        // Check if user exists in Firestore
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (!userDoc.exists) {
          // User signed in with Google but hasn't signed up yet
          await _auth.signOut();
          await _googleSignIn.signOut();
          
          if (mounted) {
            setState(() => _isLoading = false);
            _showSnackBar('No account found. Please sign up first to create your account.', Colors.orange);
          }
          return;
        }

        // Google accounts are automatically verified, update Firestore if needed
        if (userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          if (userData['emailVerified'] != true) {
            await _firestore.collection('users').doc(user.uid).update({
              'emailVerified': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Welcome back!', Colors.green);
          
          // Navigate to home screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        
        String errorMessage = 'Google sign-in failed';
        switch (e.code) {
          case 'account-exists-with-different-credential':
            errorMessage = 'An account with this email already exists using a different sign-in method. Please use your original sign-in method.';
            break;
          case 'invalid-credential':
            errorMessage = 'Invalid credentials provided. Please try again.';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Google sign-in is currently disabled. Please contact support.';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled. Please contact support for assistance.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network connection failed. Please check your internet connection and try again.';
            break;
          default:
            errorMessage = e.message ?? 'Google sign-in failed. Please try again.';
        }
        
        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('An unexpected error occurred. Please try again later.', Colors.red);
        debugPrint('Google sign-in error: $e');
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
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.08,
            vertical: 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                const SizedBox(height: 40),

                Image.asset('assets/logo.png', height: 90),
                const SizedBox(height: 10),
                const Text(
                  'Smart Rack',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Smart Laundry Drying System',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 30),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Log In',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        const Text(
                          'EMAIL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFF5A6175),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Enter your email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Email is required';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        const Text(
                          'PASSWORD',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFF5A6175),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _isObscure,
                          decoration: InputDecoration(
                            hintText: 'Enter password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isObscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _isObscure = !_isObscure),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password is required';
                            return null;
                          },
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text('Forgot password?'),
                          ),
                        ),

                        const SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2762EA),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[400],
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'LOG IN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

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

                        // Google Sign In Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/google.png',
                                  height: 24,
                                  errorBuilder: (ctx, err, stack) => const Icon(
                                    Icons.g_mobiledata,
                                    size: 24,
                                    color: Color(0xFF2762EA),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Sign in with Google',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? "),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CreateAccountScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Footer
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: 'By signing in, you agree to our ',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    children: [
                      TextSpan(
                        text: 'Terms and Conditions',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TermsAndConditionsScreen(),
                              ),
                            );
                          },
                      ),
                    ],
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