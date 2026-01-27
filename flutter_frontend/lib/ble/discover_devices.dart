import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDiscoverService {
  List<BluetoothService>? _services;

  Future<List<BluetoothService>?> discoverServices(
      BluetoothDevice device) async {
    try {
      _services ??= await device.discoverServices();
      return _services;
    } on FlutterBluePlusException catch (e) {
      print('BLE discovery error: ${e.code} - ${e.description}');
      return null;
    } catch (e) {
      print('Service discovery error: $e');
      return null;
    }
  }

  Future<BluetoothCharacteristic?> findCharacteristic(
      BluetoothDevice device, String serviceUuid, String charUuid) async {
    final services = await discoverServices(device);
    if (services == null) return null;

    for (final service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == charUuid.toLowerCase()) {
            return char;
          }
        }
      }
    }
    return null;
  }

  Future<List<BluetoothCharacteristic>?> getCharacteristics(
      BluetoothDevice device, String serviceUuid) async {
    final services = await discoverServices(device);
    if (services == null) return null;

    for (final service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
        return service.characteristics;
      }
    }
    return null;
  }

  void clearCache() {
    _services = null;
  }
}
