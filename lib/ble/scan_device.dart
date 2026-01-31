import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleStartScanService {
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  Future<bool> startScan({
    int timeoutSeconds = 5,
    List<Guid>? withServices,
  }) async {
    try {
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: timeoutSeconds),
        withServices: withServices ?? [],
      );
      return true;
    } on FlutterBluePlusException catch (e) {
      print('BLE scan error: ${e.code} - ${e.description}');
      return false;
    } catch (e) {
      print('Scan start error: $e');
      return false;
    }
  }
}
