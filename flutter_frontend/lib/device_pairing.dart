import 'package:flutter/material.dart';
import 'dart:async';
import 'help_support.dart'; // <--- IMPORT ADDED

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  // --- STATE VARIABLES ---
  bool _isPaired = false;
  String _deviceName = "";
  String _deviceIp = "";
  
  // Controllers for the Modal
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _pairingCodeController = TextEditingController();

  @override
  void dispose() {
    _deviceIdController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  // --- LOGIC: SHOW PAIRING MODAL ---
  void _showPairingModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Pair New Device", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Enter the Device ID found on your hardware and the unique pairing code.",
                style: TextStyle(fontSize: 13, color: Color(0xFF5A6175)),
              ),
              const SizedBox(height: 24),

              // Inputs
              _buildModalInput("Device ID", "e.g. DRY-2024-X", _deviceIdController),
              const SizedBox(height: 16),
              _buildModalInput("Pairing Code", "e.g. PAIR123", _pairingCodeController),

              const SizedBox(height: 32),

              // Connect Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close the modal
                    _simulateConnectionProcess(); // Start the loading/connection logic
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2962FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                    shadowColor: const Color(0xFF2962FF).withOpacity(0.3),
                  ),
                  child: const Text("CONNECT DEVICE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- LOGIC: SIMULATE CONNECTION (LOADING) ---
  Future<void> _simulateConnectionProcess() async {
    // 1. Show Loading Spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // 2. Simulate Network/Handshake Delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    // 3. Update UI to Paired State (Backend Ready)
    setState(() {
      _isPaired = true;
      // If user typed nothing, use defaults. If typed, use input.
      _deviceName = "Smart Rack (${_deviceIdController.text.isEmpty ? 'DRY-2024-X' : _deviceIdController.text})";
      _deviceIp = "192.168.1.45"; // In real app, this comes from the device handshake
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Device Connected Successfully!"), backgroundColor: Colors.green),
    );
  }

  // --- LOGIC: DISCONNECT ---
  void _disconnectDevice() {
    setState(() {
      _isPaired = false;
      _deviceName = "";
      _deviceIp = "";
      _deviceIdController.clear();
      _pairingCodeController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Device Disconnected"), backgroundColor: Colors.redAccent),
    );
  }

  // --- LOGIC: SWITCH DEVICE (NEW) ---
  void _switchDevice() {
    // 1. Disconnect current (Reset backend variables)
    setState(() {
      _isPaired = false;
      _deviceName = "";
      _deviceIp = "";
      _deviceIdController.clear(); // Clear inputs for fresh entry
      _pairingCodeController.clear();
    });

    // 2. Immediately open the Pairing Modal
    // We add a tiny delay to let the UI refresh first, making the transition smoother
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _showPairingModal();
    });
  }

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
              // Header
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
              const Text("Settings", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
              const Text("Manage devices", style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 32),
              const Text("Device Connection", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
              const SizedBox(height: 12),

              // Main Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: _isPaired ? _buildPairedView() : _buildUnpairedView(),
              ),

              if (!_isPaired) ...[
                const SizedBox(height: 30),
                Center(
                  child: TextButton(
                    onPressed: () {
                      // --- NEW NAVIGATION LOGIC ---
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
                      );
                    },
                    child: const Text("Trouble connecting? Get Help", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  // View 1: Unpaired
  Widget _buildUnpairedView() {
    return Column(
      children: [
        const Text("No devices paired yet.", style: TextStyle(fontSize: 14, color: Color(0xFF5A6175))),
        const SizedBox(height: 24),
        TextButton(
          onPressed: _showPairingModal, 
          child: const Text("Pair Device", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2962FF))),
        ),
      ],
    );
  }

  // View 2: Paired (With Switch Device Button)
  Widget _buildPairedView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.check, color: Colors.green, size: 32),
        ),
        const SizedBox(height: 16),
        Text(_deviceName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text("Connected • $_deviceIp", style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 32),
        
        // --- BUTTONS ---
        SizedBox(
          width: 200,
          height: 45,
          child: OutlinedButton(
            onPressed: _disconnectDevice,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red, 
              side: BorderSide(color: Colors.red.shade200), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            child: const Text("DISCONNECT", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        
        // --- SWITCH DEVICE BUTTON (NEW) ---
        TextButton.icon(
          onPressed: _switchDevice, // Calls the switch logic
          icon: const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF2962FF)),
          label: const Text("Switch Device", style: TextStyle(color: Color(0xFF2962FF), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // Helper for Modal Inputs
  Widget _buildModalInput(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5A6175))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2962FF), width: 1.5)),
          ),
        ),
      ],
    );
  }
}