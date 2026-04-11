import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'help_support.dart';
import 'qr_scanner_screen.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isPaired = false;
  bool _isLoading = true;
  String _deviceName = "";
  String _deviceMacId = "";
  String _currentDeviceDocId = "";
  List<Map<String, dynamic>> _pairedDevices = [];

  @override
  void initState() {
    super.initState();
    _checkExistingPairing();
  }

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
          List<Map<String, dynamic>> devices = [];

          for (String deviceDocId in deviceIds) {
            final deviceDoc =
                await _firestore.collection('devices').doc(deviceDocId).get();
            if (deviceDoc.exists) {
              devices.add({
                'docId': deviceDocId,
                'data': deviceDoc.data(),
              });
            }
          }

          if (devices.isNotEmpty) {
            String activeDeviceId;
            if (currentDevice != null && deviceIds.contains(currentDevice)) {
              activeDeviceId = currentDevice;
            } else {
              activeDeviceId = devices[0]['docId'];
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
              _deviceMacId =
                  activeDevice['data']['macId'] ?? activeDevice['docId'];
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

  // ── QR scan is the only entry point for pairing ──────────────────────────
  Future<void> _startQRScan() async {
    // qr_scanner_screen already validates JSON and keys before returning
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (result == null || !mounted) return;

    debugPrint('QR result received in pairing: "$result"');

    try {
      final Map<String, dynamic> data =
          jsonDecode(result) as Map<String, dynamic>;

      debugPrint('Parsed keys: ${data.keys.toList()}');

      final String? macId = data['macId'] as String?;
      final String? pairingCode = data['pairingCode']?.toString();

      debugPrint('macId=$macId  pairingCode=$pairingCode');

      if (macId == null || pairingCode == null) {
        _showSnackBar(
          'QR missing fields. Keys found: ${data.keys.toList()}',
          Colors.red,
        );
        return;
      }

      await _attemptPairing(macId, pairingCode);
    } catch (e) {
      debugPrint('QR parse error: $e');
      _showSnackBar('QR parse error: $e', Colors.red);
    }
  }

  // Show device switcher modal
  void _showDeviceSwitcher() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              ..._pairedDevices.map((device) {
                final String docId = device['docId'];
                final Map<String, dynamic> data = device['data'];
                final String macId = data['macId'] ?? docId;
                final bool isActive = docId == _currentDeviceDocId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF2962FF).withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF2962FF)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.devices,
                      color: isActive
                          ? const Color(0xFF2962FF)
                          : Colors.grey,
                    ),
                    title: Text(
                      "Smart Rack ($macId)",
                      style: TextStyle(
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                        color: const Color(0xFF1E2339),
                      ),
                    ),
                    subtitle: Text(
                      isActive ? "Currently Active" : "Tap to switch",
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive
                            ? const Color(0xFF2962FF)
                            : Colors.grey,
                      ),
                    ),
                    trailing: isActive
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFF2962FF))
                        : null,
                    onTap: isActive
                        ? null
                        : () {
                            _switchToDevice(docId, macId);
                            Navigator.pop(context);
                          },
                  ),
                );
              }),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startQRScan();
                },
                icon: const Icon(Icons.qr_code_scanner,
                    color: Color(0xFF2962FF)),
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

  void _switchToDevice(String deviceDocId, String macId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

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

      debugPrint('Querying Firestore for macId: "$macId"');

      final deviceQuery = await _firestore
          .collection('devices')
          .where('macId', isEqualTo: macId)
          .limit(1)
          .get();

      debugPrint('Query result count: ${deviceQuery.docs.length}');

      if (deviceQuery.docs.isEmpty) {
        Navigator.pop(context);
        _showSnackBar(
            'Device not found. Check MAC ID: "$macId"', Colors.red);
        return;
      }

      final deviceDoc = deviceQuery.docs.first;
      final deviceData = deviceDoc.data();
      final String deviceDocId = deviceDoc.id;

      debugPrint('Found device doc: $deviceDocId');
      debugPrint('Stored pairingCode: ${deviceData['pairingCode']}');

      if (_pairedDevices.any((d) => d['docId'] == deviceDocId)) {
        Navigator.pop(context);
        _showSnackBar('Device already paired', Colors.orange);
        return;
      }

      final String storedPairingCode =
          deviceData['pairingCode']?.toString() ?? '';

      debugPrint(
          'Comparing: stored="$storedPairingCode" vs scanned="$pairingCode"');

      if (storedPairingCode != pairingCode) {
        Navigator.pop(context);
        _showSnackBar('Incorrect pairing code.', Colors.red);
        return;
      }

      await _firestore.collection('users').doc(user.uid).update({
        'devices': FieldValue.arrayUnion([deviceDocId]),
        'currentDeviceConnected': deviceDocId,
      });

      _pairedDevices.add({
        'docId': deviceDocId,
        'data': deviceData,
      });

      setState(() {
        _isPaired = true;
        _currentDeviceDocId = deviceDocId;
        _deviceMacId = macId;
        _deviceName = "Smart Rack ($macId)";
      });

      Navigator.pop(context);
      _showSnackBar('Device paired successfully!', Colors.green);
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar('Error: ${e.toString()}', Colors.red);
      debugPrint('Pairing error: $e');
    }
  }

  Future<void> _disconnectDevice() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disconnect Device?'),
        content: Text(
            'Are you sure you want to disconnect "$_deviceName"? You will need to re-scan the QR code to connect again.'),
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

      await _firestore.collection('users').doc(user.uid).update({
        'devices': FieldValue.arrayRemove([_currentDeviceDocId]),
      });

      _pairedDevices.removeWhere((d) => d['docId'] == _currentDeviceDocId);

      if (_pairedDevices.isEmpty) {
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
        final firstDevice = _pairedDevices[0];
        final newDeviceId = firstDevice['docId'];
        final newMacId = firstDevice['data']['macId'] ?? newDeviceId;

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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
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
              Row(
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Back",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
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

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 40, horizontal: 24),
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
                child:
                    _isPaired ? _buildPairedView() : _buildUnpairedView(),
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
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12),
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

  Widget _buildUnpairedView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.qr_code_scanner,
              color: Colors.orange, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          "No devices paired yet.",
          style: TextStyle(fontSize: 14, color: Color(0xFF5A6175)),
        ),
        const SizedBox(height: 8),
        const Text(
          "Scan the QR code on your Smart Rack\nto get started.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF9095A1)),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startQRScan,
            icon: const Icon(Icons.qr_code, color: Colors.white),
            label: const Text(
              "SCAN QR CODE",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2962FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

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
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

        if (_pairedDevices.length > 1) ...[
          const SizedBox(height: 8),
          Text(
            "${_pairedDevices.length} devices paired",
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF5A6175)),
          ),
        ],

        const SizedBox(height: 32),

        SizedBox(
          width: 200,
          height: 45,
          child: OutlinedButton(
            onPressed: _disconnectDevice,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red.shade200),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              "DISCONNECT",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),

        TextButton.icon(
          onPressed: _showDeviceSwitcher,
          icon: const Icon(Icons.swap_horiz,
              size: 18, color: Color(0xFF2962FF)),
          label: const Text(
            "Switch Device",
            style: TextStyle(
                color: Color(0xFF2962FF),
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}