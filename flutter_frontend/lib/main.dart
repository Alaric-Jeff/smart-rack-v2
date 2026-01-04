import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  // API Configuration (only for SSO if needed)
  static const String _baseUrl = 'http://localhost:3000';
  
  // Testing Mode - Set to true to skip backend calls during SSO testing
  static const bool _testingMode = true;

  // ✨ SERVERLESS Manual Login - Direct Firebase Auth
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Sign in with Firebase Auth (serverless!)
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Optional: Verify user exists in Firestore
      String uid = userCredential.user!.uid;
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        // User authenticated but no Firestore document (shouldn't happen normally)
        await _auth.signOut();
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Account data not found. Please contact support.', Colors.red);
        }
        return;
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

        // Map Firebase Auth errors to user-friendly messages
        // (matching your backend logic)
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No account found with this email';
            break;
          case 'wrong-password':
            errorMessage = 'Incorrect password';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many failed attempts. Please try again later.';
            break;
          case 'invalid-credential':
            errorMessage = 'Invalid email or password';
            break;
          default:
            errorMessage = e.message ?? 'An error occurred during login';
        }
        
        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Network error: Unable to connect', Colors.red);
      }
    }
  }

  // Google SSO Login
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
            _showSnackBar('No account found. Please sign up first.', Colors.orange);
          }
          return;
        }

        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Welcome back!', Colors.green);
          
          debugPrint('=== GOOGLE SSO LOGIN SUCCESS ===');
          debugPrint('UUID: ${user.uid}');
          debugPrint('Display Name: ${user.displayName}');
          debugPrint('Email: ${user.email}');
          debugPrint('================================');
          
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
            errorMessage = 'An account already exists with this email using a different sign-in method';
            break;
          case 'invalid-credential':
            errorMessage = 'Invalid credentials. Please try again.';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Google sign-in is not enabled';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled';
            break;
          default:
            errorMessage = e.message ?? 'Google sign-in failed';
        }
        
        _showSnackBar(errorMessage, Colors.red);
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
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
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

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsAndConditionsScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'By signing in, you agree to our Terms and Conditions',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
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