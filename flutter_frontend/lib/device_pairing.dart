import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'help_support.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State variables
  bool _isPaired = false;
  bool _isLoading = true;
  String _deviceName = "";
  String _deviceMacId = "";
  String _currentDeviceDocId = ""; // Track current device document ID
  List<Map<String, dynamic>> _pairedDevices = []; // Store all paired devices
  
  // Controllers for the Modal
  final TextEditingController _macIdController = TextEditingController();
  final TextEditingController _pairingCodeController = TextEditingController();

  // Error states
  String? _macIdError;
  String? _pairingCodeError;

  @override
  void initState() {
    super.initState();
    _checkExistingPairing();
  }

  @override
  void dispose() {
    _macIdController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  // Check if user already has paired devices
  Future<void> _checkExistingPairing() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        final List<dynamic> deviceIds = userData?['devices'] ?? [];
        final String? currentDevice = userData?['currentDeviceConnected'];
        
        if (deviceIds.isNotEmpty) {
          // Fetch all paired devices
          List<Map<String, dynamic>> devices = [];
          
          for (String deviceDocId in deviceIds) {
            final deviceDoc = await _firestore.collection('devices').doc(deviceDocId).get();
            if (deviceDoc.exists) {
              devices.add({
                'docId': deviceDocId,
                'data': deviceDoc.data(),
              });
            }
          }
          
          if (devices.isNotEmpty) {
            // Use currentDeviceConnected if available, otherwise first device
            String activeDeviceId;
            if (currentDevice != null && deviceIds.contains(currentDevice)) {
              activeDeviceId = currentDevice;
            } else {
              activeDeviceId = devices[0]['docId'];
              // Update Firestore with first device as current
              await _firestore.collection('users').doc(user.uid).update({
                'currentDeviceConnected': activeDeviceId,
              });
            }
            
            final activeDevice = devices.firstWhere(
              (d) => d['docId'] == activeDeviceId,
              orElse: () => devices[0],
            );
            
            setState(() {
              _pairedDevices = devices;
              _isPaired = true;
              _currentDeviceDocId = activeDevice['docId'];
              _deviceMacId = activeDevice['data']['macId'] ?? activeDevice['docId'];
              _deviceName = "Smart Rack ($_deviceMacId)";
              _isLoading = false;
            });
            return;
          }
        }
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error checking pairing: $e');
      setState(() => _isLoading = false);
    }
  }

  // Show pairing modal for NEW device
  void _showPairingModal() {
    // Reset errors
    _macIdError = null;
    _pairingCodeError = null;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      const Text(
                        "Pair New Device",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2339),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          _macIdController.clear();
                          _pairingCodeController.clear();
                          Navigator.pop(context);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Enter the MAC ID found on your hardware and the 6-digit pairing code.",
                    style: TextStyle(fontSize: 13, color: Color(0xFF5A6175)),
                  ),
                  const SizedBox(height: 24),

                  // MAC ID Input
                  _buildModalInput(
                    "MAC ID",
                    "e.g. mac-id-001",
                    _macIdController,
                    errorText: _macIdError,
                    onChanged: (value) {
                      setDialogState(() {
                        _macIdError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Pairing Code Input
                  _buildModalInput(
                    "Pairing Code",
                    "6-digit code",
                    _pairingCodeController,
                    errorText: _pairingCodeError,
                    isNumeric: true,
                    maxLength: 6,
                    onChanged: (value) {
                      setDialogState(() {
                        _pairingCodeError = null;
                        
                        if (value.isNotEmpty && value.length < 6) {
                          _pairingCodeError = "Code must be exactly 6 digits";
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 32),

                  // Connect Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Validate inputs
                        bool hasError = false;
                        
                        setDialogState(() {
                          _macIdError = null;
                          _pairingCodeError = null;

                          if (_macIdController.text.trim().isEmpty) {
                            _macIdError = "MAC ID is required";
                            hasError = true;
                          }

                          if (_pairingCodeController.text.trim().isEmpty) {
                            _pairingCodeError = "Pairing code is required";
                            hasError = true;
                          } else if (_pairingCodeController.text.length != 6) {
                            _pairingCodeError = "Code must be exactly 6 digits";
                            hasError = true;
                          }
                        });

                        if (hasError) return;

                        Navigator.pop(context);
                        await _attemptPairing(
                          _macIdController.text.trim(),
                          _pairingCodeController.text.trim(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2962FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                        shadowColor: const Color(0xFF2962FF).withOpacity(0.3),
                      ),
                      child: const Text(
                        "CONNECT DEVICE",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ✅ NEW: Show device switcher modal (for already paired devices)
  void _showDeviceSwitcher() {
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
                  const Text(
                    "Switch Device",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2339),
                    ),
                  ),
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
                "Select a device to switch to:",
                style: TextStyle(fontSize: 13, color: Color(0xFF5A6175)),
              ),
              const SizedBox(height: 20),

              // List of paired devices
              ..._pairedDevices.map((device) {
                final String docId = device['docId'];
                final Map<String, dynamic> data = device['data'];
                final String macId = data['macId'] ?? docId;
                final bool isActive = docId == _currentDeviceDocId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF2962FF).withOpacity(0.1) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? const Color(0xFF2962FF) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.devices,
                      color: isActive ? const Color(0xFF2962FF) : Colors.grey,
                    ),
                    title: Text(
                      "Smart Rack ($macId)",
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: const Color(0xFF1E2339),
                      ),
                    ),
                    subtitle: Text(
                      isActive ? "Currently Active" : "Tap to switch",
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? const Color(0xFF2962FF) : Colors.grey,
                      ),
                    ),
                    trailing: isActive 
                        ? const Icon(Icons.check_circle, color: Color(0xFF2962FF))
                        : null,
                    onTap: isActive ? null : () {
                      _switchToDevice(docId, macId);
                      Navigator.pop(context);
                    },
                  ),
                );
              }).toList(),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Pair New Device Button
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showPairingModal();
                },
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2962FF)),
                label: const Text(
                  "Pair a New Device",
                  style: TextStyle(
                    color: Color(0xFF2962FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ NEW: Switch to an already-paired device (no re-authentication needed)
  void _switchToDevice(String deviceDocId, String macId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update Firestore with new current device
      await _firestore.collection('users').doc(user.uid).update({
        'currentDeviceConnected': deviceDocId,
      });

      setState(() {
        _currentDeviceDocId = deviceDocId;
        _deviceMacId = macId;
        _deviceName = "Smart Rack ($macId)";
      });
      
      _showSnackBar('Switched to $macId', Colors.green);
    } catch (e) {
      _showSnackBar('Error switching device: ${e.toString()}', Colors.red);
      debugPrint('Switch error: $e');
    }
  }

  // Attempt device pairing (for NEW devices)
  Future<void> _attemptPairing(String macId, String pairingCode) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = _auth.currentUser;
      if (user == null) {
        Navigator.pop(context);
        _showSnackBar('User not authenticated', Colors.red);
        return;
      }

      // Query by macId field
      final deviceQuery = await _firestore
          .collection('devices')
          .where('macId', isEqualTo: macId)
          .limit(1)
          .get();

      if (deviceQuery.docs.isEmpty) {
        Navigator.pop(context);
        _showSnackBar('Device not found. Please check the MAC ID.', Colors.red);
        return;
      }

      // Get the device document
      final deviceDoc = deviceQuery.docs.first;
      final deviceData = deviceDoc.data();
      final String deviceDocId = deviceDoc.id;

      // Check if already paired
      if (_pairedDevices.any((d) => d['docId'] == deviceDocId)) {
        Navigator.pop(context);
        _showSnackBar('Device already paired', Colors.orange);
        return;
      }

      // Verify pairing code
      final String storedPairingCode = deviceData['pairingCode']?.toString() ?? '';

      if (storedPairingCode != pairingCode) {
        Navigator.pop(context);
        _showSnackBar('Incorrect pairing code. Please try again.', Colors.red);
        return;
      }

      // Add device to user's devices array
      await _firestore.collection('users').doc(user.uid).update({
        'devices': FieldValue.arrayUnion([deviceDocId]),
        'currentDeviceConnected': deviceDocId, // Set as current device
      });

      // Add to local list
      _pairedDevices.add({
        'docId': deviceDocId,
        'data': deviceData,
      });

      // Update state
      setState(() {
        _isPaired = true;
        _currentDeviceDocId = deviceDocId;
        _deviceMacId = macId;
        _deviceName = "Smart Rack ($macId)";
      });

      Navigator.pop(context);
      _showSnackBar('Device paired successfully!', Colors.green);

      _macIdController.clear();
      _pairingCodeController.clear();
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar('Error pairing device: ${e.toString()}', Colors.red);
      debugPrint('Pairing error: $e');
    }
  }

  // Disconnect device (removes from user's paired devices)
  Future<void> _disconnectDevice() async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disconnect Device?'),
        content: Text('Are you sure you want to disconnect "$_deviceName"? You will need to re-enter the pairing code to connect again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DISCONNECT'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Remove device from user's devices array
      await _firestore.collection('users').doc(user.uid).update({
        'devices': FieldValue.arrayRemove([_currentDeviceDocId]),
      });

      // Remove from local list
      _pairedDevices.removeWhere((d) => d['docId'] == _currentDeviceDocId);

      if (_pairedDevices.isEmpty) {
        // No devices left - clear current device flag
        await _firestore.collection('users').doc(user.uid).update({
          'currentDeviceConnected': null,
        });
        
        setState(() {
          _isPaired = false;
          _deviceName = "";
          _deviceMacId = "";
          _currentDeviceDocId = "";
        });
      } else {
        // Switch to first available device
        final firstDevice = _pairedDevices[0];
        final newDeviceId = firstDevice['docId'];
        final newMacId = firstDevice['data']['macId'] ?? newDeviceId;
        
        // Update Firestore with new current device
        await _firestore.collection('users').doc(user.uid).update({
          'currentDeviceConnected': newDeviceId,
        });
        
        setState(() {
          _currentDeviceDocId = newDeviceId;
          _deviceMacId = newMacId;
          _deviceName = "Smart Rack ($newMacId)";
        });
      }

      _showSnackBar('Device disconnected', Colors.orange);
    } catch (e) {
      _showSnackBar('Error disconnecting: ${e.toString()}', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                  const Text(
                    "Back",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "Settings",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2339),
                ),
              ),
              const Text(
                "Manage devices",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              const Text(
                "Device Connection",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2339),
                ),
              ),
              const SizedBox(height: 12),

              // Main Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isPaired ? _buildPairedView() : _buildUnpairedView(),
              ),

              if (!_isPaired) ...[
                const SizedBox(height: 30),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpSupportScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Trouble connecting? Get Help",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Unpaired view
  Widget _buildUnpairedView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.devices_other, color: Colors.orange, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          "No devices paired yet.",
          style: TextStyle(fontSize: 14, color: Color(0xFF5A6175)),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _showPairingModal,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2962FF),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "PAIR DEVICE",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // Paired view
  Widget _buildPairedView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.green, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          _deviceName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E2339),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "Connected • $_deviceMacId",
            style: const TextStyle(
              fontSize: 12,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Show device count if multiple
        if (_pairedDevices.length > 1) ...[
          const SizedBox(height: 8),
          Text(
            "${_pairedDevices.length} devices paired",
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5A6175),
            ),
          ),
        ],
        
        const SizedBox(height: 32),

        // Disconnect Button
        SizedBox(
          width: 200,
          height: 45,
          child: OutlinedButton(
            onPressed: _disconnectDevice,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red.shade200),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "DISCONNECT",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ✅ FIXED: Switch Device Button now shows switcher modal
        TextButton.icon(
          onPressed: _showDeviceSwitcher,
          icon: const Icon(
            Icons.swap_horiz,
            size: 18,
            color: Color(0xFF2962FF),
          ),
          label: const Text(
            "Switch Device",
            style: TextStyle(
              color: Color(0xFF2962FF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Helper for Modal Inputs
  Widget _buildModalInput(
    String label,
    String hint,
    TextEditingController controller, {
    String? errorText,
    bool isNumeric = false,
    int? maxLength,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5A6175),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          maxLength: maxLength,
          inputFormatters: isNumeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            errorText: errorText,
            counterText: "",
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2962FF),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}