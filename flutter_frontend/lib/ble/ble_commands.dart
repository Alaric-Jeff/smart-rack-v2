import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleCommandService {
  Future<void> writeCommand(BluetoothCharacteristic char, String command) async {
    await char.write(utf8.encode(command), withoutResponse: false);
  }

  Future<void> subscribeToNotifications(
      BluetoothCharacteristic char, void Function(String) onData) async {
    await char.setNotifyValue(true);
    char.value.listen((value) {
      onData(utf8.decode(value));
    });
  }
}
