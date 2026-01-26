import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleScanService {
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<void> startScan({int timeoutSeconds = 5}) async {
    await FlutterBluePlus.startScan(timeout: Duration(seconds: timeoutSeconds));
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }
}
