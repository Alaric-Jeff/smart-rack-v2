import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'home.dart'; // Ensure this points to your HomeScreen

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _otpController = TextEditingController();
  String _generatedCode = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Generate code immediately when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateAndSendOTP();
    });
  }

  // --- 1. GENERATE & SHOW CODE ---
  void _generateAndSendOTP() {
    // Generate a random 6-digit number
    var rng = Random();
    String code = (rng.nextInt(900000) + 100000).toString(); // e.g. "452819"
    
    setState(() {
      _generatedCode = code;
    });

    // SIMULATED NOTIFICATION (Using a Top SnackBar for Demo)
    // This removes the dependency on an external 'NotificationService' file
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.security, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text("SmartRack Login Code: $code", style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 10), // Stays for 10 seconds so you can copy it
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Also print to console for debugging
    debugPrint("🔐 2FA LOGIN CODE: $code");
  }

  // --- 2. VERIFY CODE ---
  void _verifyCode() {
    if (_otpController.text.trim() == _generatedCode) {
      _showSuccessAndNavigate();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Incorrect Code. Please try again."), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessAndNavigate() {
    setState(() => _isLoading = true);
    
    // Simulate a short delay for smooth UX
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()), // Navigate to Home
        (route) => false, // Remove back button history
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Two-Factor Authentication"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false, // Hide back button (Locked screen)
        actions: [
          // Allow logging out/canceling if they are stuck
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
            const Text(
              "Enter the 6-digit code sent to your notifications to continue.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            
            // OTP INPUT FIELD
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                LengthLimitingTextInputFormatter(6),
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
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
                onPressed: _isLoading ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("VERIFY LOGIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 20),
            TextButton(
              onPressed: _generateAndSendOTP,
              child: const Text("Resend Code", style: TextStyle(color: Color(0xFF2962FF))),
            ),
          ],
        ),
      ),
    );
  }
}