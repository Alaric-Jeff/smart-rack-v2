import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  // Common colors from your branding
  final Color _textColor = const Color(0xFF1E2339);
  final Color _labelColor = const Color(0xFF5A6175);
  final Color _primaryColor = const Color(0xFF2762EA);
  final Color _backgroundColor = const Color(0xFFF8F9FB);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 40), // Smart Rack Logo
            const SizedBox(width: 10),
            Text(
              'Smart Rack',
              style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, size: 18, color: _labelColor),
              label: Text(
                'Back',
                style: TextStyle(color: _labelColor, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: _backgroundColor,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terms and Conditions',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _textColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Last updated: December 2025',
                      style: TextStyle(color: _labelColor, fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    
                    _buildSectionTitle('1. Acceptance'),
                    _buildBodyText('By using SmartDry, you agree to these Terms.'),
                    
                    _buildSectionTitle('2. Use of Service'),
                    _buildBodyText('Smart Rack provides an automated laundry drying system with smart sensors and weather monitoring.'),
                    _buildBulletPoint('You must be 18+, provide accurate information, keep your account secure, and use the service lawfully.'),
                    
                    _buildSectionTitle('3. Hardware and Device Pairing'),
                    _buildBodyText( 'Users must pair their Smart Rack hardware with the app for full functionality.'),
                    // Add content for section 3 if available in your documents
                    
                    _buildSectionTitle('4. Data Collection and Privacy'),
                    _buildBodyText('We collect sensor data (e.g., humidity, temperature, weight) to operate and improve the service.'),
                    _buildBulletPoint('We do not sell personal data. See our Privacy Policy for details.'),
                    
                    _buildSectionTitle('5. Service Availability'),
                    _buildBodyText('Service access may be interrupted due to maintenance, technical issues, connectivity problems, or unforeseen events.'),
                    
                    _buildSectionTitle('6. Liability'),
                    _buildBodyText('Smart Rack is not responsible for clothing damage, system errors, weather inaccuracies, or misuse of hardware. Use the service at your own risk.'),
                    
                    _buildSectionTitle('7. Termination'),
                    _buildBodyText('We may suspend or terminate accounts that violate these Terms. You may close your account anytime.'),
                    
                    _buildSectionTitle('8. Changes to Terms'),
                    _buildBodyText('Terms may change. Continued use means acceptance of updated Terms.'),
                    
                    _buildSectionTitle('9. Contact Information'),
                    _buildBodyText('For questions about these Terms, please contact us at:'),
                    
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Smart Rack Support', style: TextStyle(fontWeight: FontWeight.bold, color: _textColor)),
                          const SizedBox(height: 8),
                          Text('Email: support@smartrack.com', style: TextStyle(color: _labelColor)),
                          Text('Number: 63+', style: TextStyle(color: _labelColor)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        'By using Smart Rack, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _labelColor, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Divider(),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        '© 2025 Smart Rack Systems. All rights reserved.',
                        style: TextStyle(color: _labelColor, fontSize: 12),
                      ),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor),
      ),
    );
  }

  Widget _buildBodyText(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 15, color: _labelColor, height: 1.5),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• ", style: TextStyle(fontSize: 18, color: _labelColor)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: _labelColor, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}