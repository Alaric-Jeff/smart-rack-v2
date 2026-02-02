import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';
import './sms/send_otp.dart';
import './sms/verify_otp.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;
  bool _isFetchingPhone = true;
  
  String? _phoneNumber;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Fetch phone number then send OTP
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPhoneNumberAndSendOTP();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  // --- FETCH PHONE NUMBER FROM FIRESTORE ---
  Future<void> _fetchPhoneNumberAndSendOTP() async {
    setState(() => _isFetchingPhone = true);

    try {
      final user = _auth.currentUser;
      
      if (user == null) {
        setState(() {
          _errorMessage = "No user logged in";
          _isFetchingPhone = false;
        });
        return;
      }

      // Fetch user document from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        setState(() {
          _errorMessage = "User profile not found";
          _isFetchingPhone = false;
        });
        return;
      }

      final data = userDoc.data();
      final contactNumber = data?['contactNumber'] as String?;

      if (contactNumber == null || contactNumber.isEmpty) {
        setState(() {
          _errorMessage = "No phone number registered. Please update your profile.";
          _isFetchingPhone = false;
        });
        return;
      }

      // Successfully fetched phone number
      setState(() {
        _phoneNumber = contactNumber;
        _isFetchingPhone = false;
      });

      // Now send OTP
      _sendOTP();

    } catch (e) {
      debugPrint("❌ Error fetching phone number: $e");
      setState(() {
        _errorMessage = "Failed to fetch phone number: ${e.toString()}";
        _isFetchingPhone = false;
      });
    }
  }

  // --- SEND OTP VIA SMS ---
  Future<void> _sendOTP() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) {
      _showErrorDialog(
        "Missing Phone Number",
        "Unable to send verification code. Please update your profile with a valid phone number.",
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      // Call your sendOtp function
      final result = await sendOtp(phoneNumber: _phoneNumber!);

      if (mounted) {
        setState(() => _isSendingOtp = false);

        if (result['status'] == 'success') {
          setState(() => _otpSent = true);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.security, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Verification code sent to $_phoneNumber",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );

          debugPrint("✅ OTP sent successfully to $_phoneNumber");
        } else {
          // Failed to send OTP
          _showErrorDialog(
            "Failed to Send Code",
            result['message'] ?? 'Unable to send verification code. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingOtp = false);
        debugPrint("❌ Send OTP Error: $e");
        _showErrorDialog(
          "Error",
          "An error occurred while sending the verification code: ${e.toString()}",
        );
      }
    }
  }

  // --- VERIFY OTP ---
  Future<void> _verifyCode() async {
    String otpCode = _otpController.text.trim();

    if (otpCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a 6-digit code"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_phoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Phone number not found"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call your verifyOtp function
      final result = await verifyOtp(
        phoneNumber: _phoneNumber!,
        otp: otpCode,
      );

      if (mounted) {
        if (result['status'] == 'success') {
          // OTP verified successfully
          await _markPhoneAsVerified();
          _showSuccessAndNavigate();
        } else {
          // Verification failed
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Invalid code. Please try again."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint("❌ Verify OTP Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Verification error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- MARK PHONE AS VERIFIED IN FIRESTORE ---
  Future<void> _markPhoneAsVerified() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'isPhoneVerified': true,
          'phoneVerifiedAt': FieldValue.serverTimestamp(),
        });
        debugPrint("✅ Phone marked as verified in Firestore");
      }
    } catch (e) {
      debugPrint("❌ Error updating Firestore: $e");
      // Don't block navigation even if Firestore update fails
    }
  }

  void _showSuccessAndNavigate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Phone verified successfully!"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    // Navigate to Home after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false, // Clear navigation stack
      );
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text("GO BACK", style: TextStyle(color: Colors.grey)),
          ),
          if (title.contains("Failed"))
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _sendOTP(); // Retry sending OTP
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF)),
              child: const Text("RETRY", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while fetching phone number
    if (_isFetchingPhone) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Two-Factor Authentication"),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                "Fetching your phone number...",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Show error if phone number couldn't be fetched
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Two-Factor Authentication"),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  "Error",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      "GO BACK",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Main OTP screen
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Two-Factor Authentication"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, size: 80, color: Color(0xFF2962FF)),
            const SizedBox(height: 24),
            const Text(
              "Verification Required",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _otpSent
                  ? "Enter the 6-digit code sent to $_phoneNumber"
                  : "Sending verification code to $_phoneNumber...",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // OTP INPUT FIELD
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              enabled: _otpSent && !_isLoading,
              inputFormatters: [
                LengthLimitingTextInputFormatter(6),
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: "000000",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // VERIFY BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isLoading || _isSendingOtp || !_otpSent) ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text(
                        "VERIFY LOGIN",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // RESEND CODE BUTTON
            TextButton(
              onPressed: (_isSendingOtp || _isLoading) ? null : _sendOTP,
              child: _isSendingOtp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      "Resend Code",
                      style: TextStyle(color: Color(0xFF2962FF)),
                    ),
            ),

            const SizedBox(height: 20),

            // SMS CHECK REMINDER
            if (_otpSent)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Please check your SMS inbox for the verification code.",
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}