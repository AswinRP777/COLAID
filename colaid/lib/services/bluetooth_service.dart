import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_tts/flutter_tts.dart';

class ColaidBluetoothService {
  static final ColaidBluetoothService _instance =
      ColaidBluetoothService._internal();
  factory ColaidBluetoothService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();

  ColaidBluetoothService._internal() {
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speakColor(String text) async {
    await _flutterTts.speak("It's $text");
  }

  fbp.BluetoothDevice? connectedDevice;
  StreamSubscription<fbp.BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _rxSubscription;

  // UUIDs (Standard BLE UART Service - generic for ESP32)
  static const String serviceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String rxCharacteristicUuid =
      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // App sends to THIS
  static const String txCharacteristicUuid =
      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // App receives from THIS

  fbp.BluetoothCharacteristic? _rxCharacteristic; // Write to this
  // ignore: unused_field
  fbp.BluetoothCharacteristic? _txCharacteristic; // Read from this

  // Stream for received data (Color name)
  final _colorController = StreamController<String>.broadcast();
  Stream<String> get colorStream => _colorController.stream;

  // Stream for connection state
  final _connectionStateController =
      StreamController<fbp.BluetoothConnectionState>.broadcast();
  Stream<fbp.BluetoothConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  // Check Permissions
  Future<bool> checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // Permission.bluetoothAdvertise, // Not needed for central
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  // Start Scanning
  Future<void> startScanning() async {
    if (!await checkPermissions()) {
      debugPrint("Permissions not granted");
      return;
    }

    try {
      // Start scanning - Filter by Service UUID to ONLY find Colaid Eyewear
      // This removes "simulated" or random nearby devices from the list.
      await fbp.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        // withServices: [fbp.Guid(serviceUuid)], // Removed filter to find device
      );
    } catch (e) {
      debugPrint("Error starting scan: $e");
    }
  }

  // Stop info
  Future<void> stopScanning() async {
    await fbp.FlutterBluePlus.stopScan();
  }

  Stream<List<fbp.ScanResult>> get scanResults =>
      fbp.FlutterBluePlus.scanResults;

  // Connect to Device
  Future<void> connectToDevice(fbp.BluetoothDevice device) async {
    await stopScanning();

    try {
      // Connect without autoConnect to ensure rapid connection attempt
      await device.connect(autoConnect: false, license: fbp.License.free);
      connectedDevice = device;

      // Wait a moment for connection to stabilize before requesting bond
      await Future.delayed(const Duration(seconds: 2));

      // Initiate Bonding (Pairing) for accurate System Settings visibility
      if (await device.bondState.first != fbp.BluetoothBondState.bonded) {
        try {
          await device.createBond();
        } catch (e) {
          debugPrint("Bonding failed or already bonded: $e");
        }
      }

      _connectionSubscription = device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == fbp.BluetoothConnectionState.disconnected) {
          disconnect();
        }
      });

      await _discoverServices(device);
    } catch (e) {
      debugPrint("Error connecting: $e");
      disconnect();
    }
  }

  // Discover Services & Characteristics
  Future<void> _discoverServices(fbp.BluetoothDevice device) async {
    try {
      List<fbp.BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        if (service.uuid.toString().toUpperCase() == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() ==
                rxCharacteristicUuid) {
              _rxCharacteristic = characteristic;
            }
            if (characteristic.uuid.toString().toUpperCase() ==
                txCharacteristicUuid) {
              _txCharacteristic = characteristic;

              // Enable Notifications
              await characteristic.setNotifyValue(true);
              _rxSubscription = characteristic.lastValueStream.listen((
                value,
              ) async {
                String receivedString = String.fromCharCodes(value);
                if (receivedString.isNotEmpty) {
                  _colorController.add(receivedString);
                  // Speak the color
                  await _speakColor(receivedString);
                }
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error discovering services: $e");
    }
  }

  // Send CVD Type to ESP32
  Future<void> sendCVDProfile(String cvdType) async {
    if (_rxCharacteristic != null) {
      try {
        await _rxCharacteristic!.write(cvdType.codeUnits);
        debugPrint("Sent CVD Profile: $cvdType");
      } catch (e) {
        debugPrint("Error sending data: $e");
      }
    } else {
      debugPrint("TX Characteristic not found (Cannot write to device)");
    }
  }

  Future<void> sendAudioState(bool isEnabled) async {
    String command = isEnabled ? "AUDIO_ON" : "AUDIO_OFF";
    if (_rxCharacteristic != null) {
      try {
        await _rxCharacteristic!.write(command.codeUnits);
        debugPrint("Sent Audio Command: $command");
      } catch (e) {
        debugPrint("Error sending audio command: $e");
      }
    } else {
      debugPrint("TX Characteristic not found (Cannot write to device)");
    }
  }

  // Disconnect
  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
    await _rxSubscription?.cancel();
    await connectedDevice?.disconnect();
    connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
  }
}
