import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleCommandService {
  Future<bool> writeCommand(BluetoothCharacteristic char, String command) async {
    try {
      await char.write(utf8.encode(command), withoutResponse: false);
      return true;
    } on FlutterBluePlusException catch (e) {
      print('BLE write error: ${e.code} - ${e.description}');
      return false;
    } catch (e) {
      print('Write command error: $e');
      return false;
    }
  }

  Future<StreamSubscription<List<int>>?> subscribeToNotifications(
      BluetoothCharacteristic char, void Function(String) onData) async {
    try {
      await char.setNotifyValue(true);
      return char.lastValueStream.listen(
        (value) {
          if (value.isNotEmpty) {
            try {
              onData(utf8.decode(value));
            } catch (e) {
              print('UTF-8 decode error: $e');
            }
          }
        },
        onError: (error) {
          print('Notification stream error: $error');
        },
      );
    } on FlutterBluePlusException catch (e) {
      print('BLE notification error: ${e.code} - ${e.description}');
      return null;
    } catch (e) {
      print('Subscription error: $e');
      return null;
    }
  }

  Future<bool> unsubscribeFromNotifications(BluetoothCharacteristic char) async {
    try {
      await char.setNotifyValue(false);
      return true;
    } on FlutterBluePlusException catch (e) {
      print('BLE unsubscribe error: ${e.code} - ${e.description}');
      return false;
    } catch (e) {
      print('Unsubscribe error: $e');
      return false;
    }
  }
}