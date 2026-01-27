import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleConnectService {
  Future<void> connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    try {
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
        license: License.free, 
      );
    } catch (_) {
    }
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (_) {

    }
  }
}