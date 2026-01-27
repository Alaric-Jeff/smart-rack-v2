import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDiscoverService {
  Future<List<BluetoothService>> discoverServices(BluetoothDevice device) async {
    return await device.discoverServices();
  }

  Future<BluetoothCharacteristic?> findCharacteristic(
      BluetoothDevice device, String serviceUuid, String charUuid) async {
    final services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.toString() == serviceUuid) {
        for (var char in service.characteristics) {
          if (char.uuid.toString() == charUuid) {
            return char;
          }
        }
      }
    }
    return null;
  }
}
