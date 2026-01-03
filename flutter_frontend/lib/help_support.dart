import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  const Text("Back", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 20),
              const Text("Help & Support", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
              const Text("Troubleshoot connection issues", style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 32),

              // --- Troubleshooting Steps ---
              const Text("Common Fixes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
              const SizedBox(height: 16),

              _buildStepCard(
                number: "1",
                title: "Check Power",
                description: "Ensure your Smart Rack is plugged in and the green LED indicator is blinking.",
                icon: Icons.power,
              ),
              _buildStepCard(
                number: "2",
                title: "Enable Permissions",
                description: "This app requires Bluetooth and Location permissions to scan for devices.",
                icon: Icons.bluetooth,
              ),
              _buildStepCard(
                number: "3",
                title: "Move Closer",
                description: "Keep your phone within 2 meters (6 feet) of the device during the pairing process.",
                icon: Icons.wifi_tethering,
              ),
              _buildStepCard(
                number: "4",
                title: "Reset Device",
                description: "Press and hold the physical 'Reset' button on the Smart Rack for 5 seconds until it beeps.",
                icon: Icons.restart_alt,
              ),

              const SizedBox(height: 32),

              // --- Contact Support ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  children: [
                    const Text("Still having trouble?", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                    const SizedBox(height: 8),
                    const Text("Our support team is here to help.", style: TextStyle(fontSize: 13, color: Color(0xFF5A6175))),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Add email launch logic (url_launcher)
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening email client...")));
                        },
                        icon: const Icon(Icons.email_outlined, size: 18, color: Colors.white),
                        label: const Text("CONTACT SUPPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2962FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({required String number, required String title, required String description, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF2962FF), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFF1E2339), shape: BoxShape.circle),
                      child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E2339))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF5A6175), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}