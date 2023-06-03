import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:typed_data';

class Device extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('BLE RGB Demo')),
      body: MyHomePage(title: 'BLE RGB Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FlutterBluePlus flutterBluePlus = FlutterBluePlus.instance;
  final String SERVICE_UUID = "ae6e4ee0-da99-11ed-afa1-0242ac120002";
  final String CHARACTERISTIC_BTN_UUID = "b8092e20-da99-11ed-afa1-0242ac120002";
  final String CHARACTERISTIC_LED_UUID = "e7128b62-da99-11ed-afa1-0242ac120002";

  int _counter = 99;
  double _slidervalue_r = 0.0;
  double _slidervalue_g = 0.0;
  double _slidervalue_b = 0.0;
  int _val_r = 0;
  int _val_g = 0;
  int _val_b = 0;
  bool _bleScanning = false;
  bool _bleConnected = false;
  int _testwcnt = 0;

  BluetoothDevice? _targetDevice;

  Future _discoverDevice() async {
    print("scan target device");
    String uuid;
    setState(() {
      _bleScanning = true;
    });
    try {
      final results = await FlutterBluePlus.instance.startScan(
          timeout: const Duration(seconds: 4),
          withServices: [Guid(SERVICE_UUID)]);
    } catch (e) {
      print('An Error occurd on scanning. $e');
    }
    List<ScanResult> scanResultsList = [];
    StreamSubscription subscription =
        FlutterBluePlus.instance.scanResults.listen((List<ScanResult> results) {
      scanResultsList.addAll(results);
      scanResultsList = scanResultsList.toSet().toList();
      for (ScanResult result in scanResultsList) {
        print(
            "Device ${result.device.name} ID ${result.device.id} RSSI ${result.rssi}");
        uuid = result.advertisementData.serviceUuids.toString();
        print(
            "localName ${result.advertisementData.localName}  serviceUUID {$uuid}");
        _targetDevice = result.device;
      }
    });
    await Future.delayed(Duration(seconds: 4));
    await subscription.cancel();
    await FlutterBluePlus.instance.stopScan();

    if (_targetDevice != null) {
      _connectToDevice();
    } else {
      print("Error. targetdevice is null");
    }
    setState(() {
      _bleScanning = false;
    });
    return Future;
  }

  Future<void> _connectToDevice() async {
    if ((_targetDevice != null) && (_bleConnected == false)) {
      try {
        await _targetDevice!.connect();
        print('Connected to ${_targetDevice!.name} , ${_targetDevice!.id}');
        await Future.delayed(Duration(seconds: 2));
        setState(() {
          _bleConnected = true;
        });
        _listenToCharacteristicNotifications();
      } catch (e) {
        print('Error occurred while connecting to the device. $e');
      }
    } else {
      print("Error. connectToDevice skip.");
    }
  }

  Future<void> _writeCharacteristic(Uint8List data) async {
    if (_targetDevice != null) {
      BluetoothCharacteristic? targetCharacteristic =
          await _getCharacteristic(CHARACTERISTIC_LED_UUID);
      if (targetCharacteristic != null) {
        await targetCharacteristic.write(data);
      } else {
        print("Error: Characteristic not found");
      }
    } else {
      print("Error: targetDevice is null");
    }
  }

  Future<Uint8List?> _readCharacteristic() async {
    if (_targetDevice != null) {
      BluetoothCharacteristic? targetCharacteristic =
          await _getCharacteristic(CHARACTERISTIC_BTN_UUID);
      if (targetCharacteristic != null) {
        List<int> data = await targetCharacteristic.read();
        return Uint8List.fromList(data);
      } else {
        print("Error: Characteristic not found");
      }
    } else {
      print("Error: targetDevice is null..");
    }
    return null;
  }

  Future<void> _listServices() async {
    if (_targetDevice != null) {
      List<BluetoothService> services = await _targetDevice!.discoverServices();
      print("service UUID:");
      services.forEach((service) {
        print(service.uuid.toString());
      });
    } else {
      print("Error targetDevice is null.");
    }
  }

  Future<BluetoothCharacteristic?> _getCharacteristic(
      String characteristic_Uuid) async {
    List<BluetoothService> services = await _targetDevice!.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString() == SERVICE_UUID) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid.toString() == characteristic_Uuid) {
            return characteristic;
          }
        }
      }
    }
    return null;
  }

  Future<void> _listenToCharacteristicNotifications() async {
    print("_listenToCharacteristicNotifications()");
    BluetoothCharacteristic? targetCharacteristic =
        await _getCharacteristic(CHARACTERISTIC_BTN_UUID);
    if (targetCharacteristic != null) {
      // Set notification for the target characteristic
      if (targetCharacteristic.properties.notify) {
        await targetCharacteristic.setNotifyValue(true);
        print("* setNotify done *");
      } else {
        print("Error:The characteristic does not support notify or indicate.");
      }

      // Listen to the value changes
      targetCharacteristic.value.listen((event) {
        print("Characteristic value updated: $event");

        //String receivedData = utf8.decode(event);
        List<int> receivedData = event;
        _counter = receivedData[0];
        print("Received data: $receivedData");
        setState(() {});
      });
    } else {
      print("Error: Target characteristic not found.");
    }
  }

  void _writeLed() {
    List<int> tmp;
    tmp = [_val_r, _val_g, _val_b];
    Uint8List senddata = Uint8List.fromList(tmp);
    _writeCharacteristic(senddata);
  }

  void _testWriteLED() {
    final List<int> val1 = [0xff, 0x00, 0x00];
    final List<int> val2 = [0xff, 0xff, 0xff];
    Uint8List col1 = Uint8List.fromList(val1);
    Uint8List col2 = Uint8List.fromList(val2);

    _testwcnt++;
    if (_testwcnt % 2 == 0) {
      _writeCharacteristic(col1);
    } else {
      _writeCharacteristic(col2);
    }
  }

  Future<void> _disconnectDevice() async {
    FlutterBluePlus.instance.turnOff();
  }

  @override
  void dispose() {
    _disconnectDevice();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bleScanning) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Scanning..', style: TextStyle(fontSize: 30.0)),
        SizedBox(height: 10.0),
        CircularProgressIndicator()
      ]));
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'BLE RGB Sample',
            ),
            Text(
              'Button Count : $_counter',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              new Text(
                'R: $_counter',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              new Slider(
                label: '${_val_r}',
                min: 0,
                max: 255.0,
                value: _slidervalue_r,
                onChanged: (double value) {
                  setState(() {
                    _slidervalue_r = value;
                    _val_r = (_slidervalue_r).toInt();
                    _writeLed();
                  });
                },
              ),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              new Text(
                'G: $_counter',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              new Slider(
                label: '${_val_g}',
                min: 0,
                max: 255,
                value: _slidervalue_g,
                onChanged: (double value) {
                  setState(() {
                    _slidervalue_g = value;
                    _val_g = (_slidervalue_g).toInt();
                    _writeLed();
                  });
                },
              ),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              new Text(
                'B: $_val_b',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              new Slider(
                label: '${_val_b}',
                min: 0,
                max: 255,
                value: _slidervalue_b,
                onChanged: (double value) {
                  setState(() {
                    _slidervalue_b = value;
                    _val_b = (value).toInt();
                    _writeLed();
                  });
                },
              ),
            ]),
            FloatingActionButton(
              onPressed: _discoverDevice,
              tooltip: 'discover',
              child: const Icon(Icons.start_rounded),
            ),
            FloatingActionButton(
              onPressed: _testWriteLED,
              tooltip: 'Connect',
              child: const Icon(Icons.bluetooth_connected),
            ),
          ],
        ),
      );
    }
  }
}
