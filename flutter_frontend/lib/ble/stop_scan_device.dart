import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleStopScanService {
  Future<bool> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      return true;
    } on FlutterBluePlusException catch (e) {
      print('BLE stop scan error: ${e.code} - ${e.description}');
      return false;
    } catch (e) {
      print('Scan stop error: $e');
      return false;
    }
  }
}
