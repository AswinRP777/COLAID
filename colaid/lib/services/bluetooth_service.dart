import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io' show Platform;
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
    await _flutterTts.setSpeechRate(0.45); // Slightly slower for clarity through TWS
    await _flutterTts.setVolume(1.0);      // Max volume for earphone output

    if (Platform.isIOS) {
      // Route audio to Bluetooth earphones; fall back to speaker if none paired
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        ],
      );
      await _flutterTts.setSharedInstance(true);
    } else if (Platform.isAndroid) {
      // On Android, TTS uses STREAM_MUSIC by default which auto-routes to
      // connected Bluetooth audio devices (e.g. Lenskart Phonic).
      // Use Google TTS engine if available for better quality.
      var engines = await _flutterTts.getEngines;
      if (engines != null && engines.toString().contains('google')) {
        await _flutterTts.setEngine("com.google.android.tts");
      }
    }

    // Wait for each utterance to finish before starting the next
    await _flutterTts.awaitSpeakCompletion(true);
  }

  /// Speaks detected color info through the phone's audio output.
  /// When the phone is paired with TWS earphones (e.g. Lenscart Phonic),
  /// the speech automatically plays through the earphones.
  ///
  /// Parses ESP32 messages:
  ///   "CONFUSED:Red"  → "Warning. Red. This color may be hard to distinguish."
  ///   "VISIBLE:Green" → "Green" (brief confirmation)
  Future<void> _speakColor(String rawMessage) async {
    if (rawMessage.isEmpty) return;

    // Stop any ongoing speech to prevent overlap
    await _flutterTts.stop();

    if (rawMessage.startsWith("CONFUSED:")) {
      // Indistinguishable color detected — announce warning through TWS
      String colorName = rawMessage.substring(9); // Remove "CONFUSED:" prefix
      await _flutterTts.speak(
        "Warning. $colorName. This color may be hard to distinguish.",
      );
    } else if (rawMessage.startsWith("VISIBLE:")) {
      // Distinguishable color — brief confirmation
      String colorName = rawMessage.substring(8); // Remove "VISIBLE:" prefix
      await _flutterTts.speak(colorName);
    } else {
      // Unknown format — speak as-is
      await _flutterTts.speak("It's $rawMessage");
    }
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

  // --- TWS (Lenscart Phonic) State ---
  bool _twsConnected = false;
  bool get twsConnected => _twsConnected;
  int _twsVolume = 100; // Default volume (0-127)
  int get twsVolume => _twsVolume;

  // Stream for TWS connection state changes
  final _twsStateController = StreamController<bool>.broadcast();
  Stream<bool> get twsStateStream => _twsStateController.stream;

  // Stream for TWS events (status messages from ESP32)
  final _twsEventController = StreamController<String>.broadcast();
  Stream<String> get twsEventStream => _twsEventController.stream;

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
                  if (receivedString.startsWith("TWS:")) {
                    // TWS status messages — handle silently, don't speak
                    _handleTwsMessage(receivedString);
                  } else {
                    _colorController.add(receivedString);

                    // Parse and speak color name through TWS earphones
                    // When phone is paired to Lenskart Phonic, TTS routes
                    // through the earphones automatically (Mode 1)
                    await _speakColor(receivedString);
                  }
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

  // --- TWS Message Handler ---
  // Parses TWS status messages from ESP32 and updates local state
  void _handleTwsMessage(String message) {
    _twsEventController.add(message);

    if (message == "TWS:CONNECTED") {
      _twsConnected = true;
      _twsStateController.add(true);
    } else if (message == "TWS:DISCONNECTED" || message == "TWS:DISCONNECTING") {
      _twsConnected = false;
      _twsStateController.add(false);
    } else if (message.startsWith("TWS:VOL:")) {
      _twsVolume = int.tryParse(message.substring(8)) ?? _twsVolume;
    } else if (message == "TWS:SCANNING") {
      _twsConnected = false;
      _twsStateController.add(false);
    }
    debugPrint("[TWS] $message");
  }

  // --- Generic BLE Command Sender ---
  Future<void> _sendCommand(String command) async {
    if (_rxCharacteristic != null) {
      try {
        await _rxCharacteristic!.write(command.codeUnits);
        debugPrint("Sent: $command");
      } catch (e) {
        debugPrint("Error sending command: $e");
      }
    } else {
      debugPrint("Cannot send '$command' — not connected");
    }
  }

  // Send CVD Type to ESP32
  Future<void> sendCVDProfile(String cvdType) async {
    await _sendCommand(cvdType);
  }

  Future<void> sendAudioState(bool isEnabled) async {
    await _sendCommand(isEnabled ? "AUDIO_ON" : "AUDIO_OFF");
  }

  // --- TWS (Lenskart Phonic) Commands ---
  /// Request current TWS connection status from ESP32
  Future<void> requestTwsStatus() async => _sendCommand("TWS_STATUS");

  /// Set TWS speaker volume (0–127)
  Future<void> setTwsVolume(int volume) async {
    volume = volume.clamp(0, 127);
    _twsVolume = volume;
    await _sendCommand("TWS_VOL:$volume");
  }

  /// Ask ESP32 to disconnect from TWS speakers
  Future<void> disconnectTws() async => _sendCommand("TWS_DISCONNECT");

  /// Ask ESP32 to reconnect to TWS speakers
  Future<void> reconnectTws() async => _sendCommand("TWS_RECONNECT");

  /// Play a test tone through TWS speakers
  Future<void> testTwsTone() async => _sendCommand("TWS_TEST");

  // Disconnect
  Future<void> disconnect() async {
    await _flutterTts.stop();
    await _connectionSubscription?.cancel();
    await _rxSubscription?.cancel();
    await connectedDevice?.disconnect();
    connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    _twsConnected = false;
    _twsStateController.add(false);
  }
}
