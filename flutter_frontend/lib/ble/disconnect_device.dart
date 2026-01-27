import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class BleDisconnectService {
  Future<bool> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      return true;
    } on FlutterBluePlusException catch (e) {
      print('BLE disconnection error: ${e.code} - ${e.description}');
      return false;
    } catch (e) {
      print('Disconnection error: $e');
      return false;
    }
  }

  Stream<BluetoothConnectionState> getConnectionState(BluetoothDevice device) {
    return device.connectionState;
  }
}