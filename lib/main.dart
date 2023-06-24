import 'package:flutter/material.dart';
import 'device.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() {
  if (Platform.isAndroid) {
   WidgetsFlutterBinding.ensureInitialized();
   [
     Permission.location,
     Permission.bluetooth,
     Permission.bluetoothConnect,
     Permission.bluetoothScan
   ].request().then((status) {
     runApp(const MyApp());
   });
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE_RGB',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Device(),
    );
  }
}
