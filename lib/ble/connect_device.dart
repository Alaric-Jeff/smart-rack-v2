import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class BleConnectService {
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Stop scan error: $e');
    }

    try {
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
        license: License.free,
      );
      return true;
    } on FlutterBluePlusException catch (e) {
      print('BLE connection error: ${e.code} - ${e.description}');
      return false;
    } on TimeoutException catch (e) {
      print('Connection timeout: $e');
      return false;
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }
}