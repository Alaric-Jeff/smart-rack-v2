import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleConnectService {
  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (_) {
    }
  }
}