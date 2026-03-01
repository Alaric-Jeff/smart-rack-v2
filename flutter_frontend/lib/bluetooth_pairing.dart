import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import './ble/connect_device.dart';
import './ble/disconnect_device.dart';
import './ble/scan_device.dart';
import 'ble/stop_scan_device.dart';

class BluetoothPairingScreen extends StatefulWidget {
  const BluetoothPairingScreen({super.key});

  @override
  State<BluetoothPairingScreen> createState() => _BluetoothPairingScreenState();
}

class _BluetoothPairingScreenState extends State<BluetoothPairingScreen>
    with SingleTickerProviderStateMixin {
  // --- Services ---
  final BleStartScanService _scanService = BleStartScanService();
  final BleStopScanService _stopScanService = BleStopScanService();
  final BleConnectService _connectService = BleConnectService();
  final BleDisconnectService _disconnectService = BleDisconnectService();

  // --- State ---
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _connectingDeviceId;
  List<ScanResult> _scanResults = [];

  // --- Subscriptions ---
  StreamSubscription<BluetoothAdapterState>? _adapterStateSub;
  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<bool>? _isScanningSSub;

  // --- Animation ---
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Request permissions first, then start listeners
    _requestPermissions().then((_) => _initBluetooth());
  }

  // --- REQUEST RUNTIME PERMISSIONS ---
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final allGranted = statuses.values.every(
        (s) => s == PermissionStatus.granted,
      );

      if (!allGranted && mounted) {
        _showSnackBar(
          "Some permissions were denied. Bluetooth may not work correctly.",
          Colors.orange,
        );
      }
    }
  }

  // --- INIT BLUETOOTH LISTENERS ---
  void _initBluetooth() {
    // Listen to Bluetooth adapter state
    _adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() => _adapterState = state);
        if (state != BluetoothAdapterState.on) {
          setState(() {
            _scanResults = [];
            _isScanning = false;
          });
        }
      }
    });

    // Also read current adapter state immediately (avoids timing issue)
    FlutterBluePlus.adapterState.first.then((state) {
      if (mounted) setState(() => _adapterState = state);
    });

    // Listen to scan results
    _scanResultsSub = _scanService.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results
              .where((r) => r.device.platformName.isNotEmpty)
              .toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
        });
      }
    });

    // Listen to scanning state
    _isScanningSSub = _scanService.isScanning.listen((scanning) {
      if (mounted) setState(() => _isScanning = scanning);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _adapterStateSub?.cancel();
    _scanResultsSub?.cancel();
    _isScanningSSub?.cancel();
    _stopScanService.stopScan();
    super.dispose();
  }

  // --- SCAN ---
  Future<void> _startScan() async {
    if (_adapterState != BluetoothAdapterState.on) {
      _showSnackBar("Please enable Bluetooth first.", Colors.orange);
      return;
    }
    setState(() => _scanResults = []);
    await _scanService.startScan(timeoutSeconds: 8);
  }

  Future<void> _stopScan() async {
    await _stopScanService.stopScan();
  }

  // --- CONNECT ---
  Future<void> _connect(BluetoothDevice device) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _connectingDeviceId = device.remoteId.str;
    });

    final success = await _connectService.connectToDevice(device);

    if (mounted) {
      setState(() {
        _isConnecting = false; 
        _connectingDeviceId = null;
        if (success) _connectedDevice = device;
      });

      if (success) {
        _showSnackBar(
            "Connected to ${device.platformName}", const Color(0xFF2563EB));
      } else {
        _showSnackBar(
            "Failed to connect to ${device.platformName}", Colors.red);
      }
    }
  }

  // --- DISCONNECT ---
  Future<void> _disconnect() async {
    if (_connectedDevice == null) return;

    final deviceName = _connectedDevice!.platformName;
    final success =
        await _disconnectService.disconnectDevice(_connectedDevice!);

    if (mounted) {
      if (success) {
        setState(() => _connectedDevice = null);
        _showSnackBar("Disconnected from $deviceName", Colors.grey.shade700);
      } else {
        _showSnackBar("Failed to disconnect.", Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- SIGNAL STRENGTH ICON ---
  IconData _rssiIcon(int rssi) {
    if (rssi >= -60) return Icons.signal_wifi_4_bar;
    if (rssi >= -75) return Icons.network_wifi_3_bar;
    if (rssi >= -85) return Icons.network_wifi_2_bar;
    return Icons.network_wifi_1_bar;
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -60) return const Color(0xFF10B981);
    if (rssi >= -75) return const Color(0xFFF59E0B);
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final bool bluetoothOn = _adapterState == BluetoothAdapterState.on;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E2339), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Bluetooth Connection",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E2339),
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Bluetooth Status Card ---
              _buildBluetoothStatusCard(bluetoothOn),
              const SizedBox(height: 24),

              // --- Connected Device (if any) ---
              if (_connectedDevice != null) ...[
                _buildConnectedDeviceCard(),
                const SizedBox(height: 24),
              ],

              // --- Scan Section ---
              if (bluetoothOn) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Available Devices",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2339),
                      ),
                    ),
                    if (_isScanning)
                      TextButton.icon(
                        onPressed: _stopScan,
                        icon: const Icon(Icons.stop_circle_outlined,
                            size: 16, color: Colors.red),
                        label: const Text("Stop",
                            style: TextStyle(
                                color: Colors.red, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          backgroundColor: Colors.red.shade50,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Scan Results
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: _isScanning && _scanResults.isEmpty
                      ? _buildScanningPlaceholder()
                      : _scanResults.isEmpty
                          ? _buildEmptyState()
                          : _buildDeviceList(),
                ),

                const SizedBox(height: 20),

                // --- Scan Button ---
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _startScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Icon(Icons.bluetooth_searching_rounded,
                            size: 20, color: Colors.white),
                    label: Text(
                      _isScanning ? "Scanning..." : "Scan for Devices",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScanning
                          ? const Color(0xFF2563EB).withOpacity(0.6)
                          : const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],

              // --- Bluetooth OFF hint ---
              if (!bluetoothOn) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.bluetooth_disabled_rounded,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        "Bluetooth is Disabled",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2339),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Please enable Bluetooth in your device settings to scan and connect to your Smart Rack device.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Re-check permissions in case they were denied
                            await _requestPermissions();
                            _initBluetooth();
                          },
                          icon: const Icon(Icons.refresh_rounded,
                              size: 18, color: Colors.white),
                          label: const Text(
                            "Refresh Status",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- Bluetooth Status Card ---
  Widget _buildBluetoothStatusCard(bool bluetoothOn) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bluetoothOn ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: bluetoothOn
              ? const Color(0xFF2563EB).withOpacity(0.2)
              : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: bluetoothOn ? _pulseAnimation.value : 1.0,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bluetoothOn
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth_rounded,
                color: bluetoothOn ? Colors.white : Colors.grey.shade500,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bluetoothOn ? "Bluetooth is On" : "Bluetooth is Off",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: bluetoothOn
                        ? const Color(0xFF1E2339)
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  bluetoothOn
                      ? "Ready to scan and connect"
                      : "Enable Bluetooth in your device settings",
                  style: TextStyle(
                    fontSize: 12,
                    color: bluetoothOn
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bluetoothOn
                  ? const Color(0xFF2563EB).withOpacity(0.1)
                  : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              bluetoothOn ? "ON" : "OFF",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: bluetoothOn
                    ? const Color(0xFF2563EB)
                    : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Connected Device Card ---
  Widget _buildConnectedDeviceCard() {
    final device = _connectedDevice!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Connected Device",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E2339),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.bluetooth_connected_rounded,
                    color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.platformName.isNotEmpty
                          ? device.platformName
                          : "Unknown Device",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2339),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          device.remoteId.str,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _disconnect,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade300)),
                ),
                child: const Text(
                  "Disconnect",
                  style: TextStyle(
                    color: Color(0xFF1E2339),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Device List ---
  Widget _buildDeviceList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _scanResults.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Colors.grey.shade100,
        indent: 72,
        endIndent: 20,
      ),
      itemBuilder: (context, index) {
        final result = _scanResults[index];
        final device = result.device;
        final isConnected =
            _connectedDevice?.remoteId.str == device.remoteId.str;
        final isThisConnecting = _connectingDeviceId == device.remoteId.str;

        return _buildDeviceTile(
          device: device,
          rssi: result.rssi,
          isConnected: isConnected,
          isConnecting: isThisConnecting,
        );
      },
    );
  }

  Widget _buildDeviceTile({
    required BluetoothDevice device,
    required int rssi,
    required bool isConnected,
    required bool isConnecting,
  }) {
    final name =
        device.platformName.isNotEmpty ? device.platformName : "Unknown Device";
    final isESP = name.toLowerCase().contains('esp') ||
        name.toLowerCase().contains('laundry') ||
        name.toLowerCase().contains('ld');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isConnected
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isESP ? Icons.developer_board_rounded : Icons.bluetooth_rounded,
              color: isConnected
                  ? const Color(0xFF10B981)
                  : const Color(0xFF1E2339),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2339),
                        ),
                      ),
                    ),
                    if (isESP) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "ESP32",
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(_rssiIcon(rssi), size: 13, color: _rssiColor(rssi)),
                    const SizedBox(width: 4),
                    Text(
                      "$rssi dBm",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        device.remoteId.str,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isConnected)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: const Text(
                "Connected",
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (isConnecting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
                strokeWidth: 2.5,
              ),
            )
          else
            ElevatedButton(
              onPressed: () => _connect(device),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                "Connect",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Scanning Placeholder ---
  Widget _buildScanningPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: Color(0xFF2563EB),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Scanning for nearby devices...",
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            "Make sure your device's Bluetooth is enabled",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // --- Empty State ---
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F6FA),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bluetooth_disabled_rounded,
                size: 32, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Devices Found",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2339),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Tap \"Scan for Devices\" to discover nearby Bluetooth devices.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}