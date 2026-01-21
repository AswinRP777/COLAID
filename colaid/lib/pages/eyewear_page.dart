import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/bluetooth_service.dart';
import '../services/user_service.dart';

class EyewearPage extends StatefulWidget {
  const EyewearPage({super.key});

  @override
  State<EyewearPage> createState() => _EyewearPageState();
}

class _EyewearPageState extends State<EyewearPage> {
  final ColaidBluetoothService _bleService = ColaidBluetoothService();
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // Listen to scan results if needed, or trigger scan
    _startScan();
  }

  void _startScan() async {
    setState(() => _isScanning = true);
    await _bleService.startScanning();
    await Future.delayed(const Duration(seconds: 15));
    if (mounted) setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        title: Text(
          'Connect Eyewear',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            onPressed: () {
              if (_isScanning) {
                _bleService.stopScanning();
                setState(() => _isScanning = false);
              } else {
                _startScan();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Connected Device Header
          if (_bleService.connectedDevice != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFE8EAF6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CONNECTED DEVICE",
                    style: GoogleFonts.outfit(
                      color: Colors.grey, // Fixed invalid index
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 10),
                      Text(
                        _bleService.connectedDevice!.platformName.isNotEmpty
                            ? _bleService.connectedDevice!.platformName
                            : "Unknown Device",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3F51B5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await _bleService.disconnect();
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text("Disconnect"),
                  ),
                ],
              ),
            ),

          // 2. Scan Results List
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: _bleService.scanResults,
              builder: (context, snapshot) {
                // Filter out devices with no name
                final validResults = snapshot.data!
                    // .where((r) => r.device.platformName.isNotEmpty) // Removed filter for debugging
                    .toList();

                if (validResults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bluetooth_searching,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _isScanning
                              ? "Scanning for eyewear..."
                              : "No named devices found.",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        if (!_isScanning)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: ElevatedButton(
                              onPressed: _startScan,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("Scan Again"),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: validResults.length,
                  itemBuilder: (context, index) {
                    final result = validResults[index];
                    final deviceName = result.device.platformName;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.bluetooth,
                          color: Color(0xFF6C63FF),
                        ),
                        title: Text(
                          deviceName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          result.device.remoteId.toString(),
                          style: GoogleFonts.outfit(color: Colors.grey),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            await _bleService.connectToDevice(result.device);
                            if (!context.mounted) return;

                            // Update UI instead of popping
                            setState(() {});

                            // Add In-App Notification
                            UserService().addNotification(
                              "Device connected: ${result.device.platformName.isNotEmpty ? result.device.platformName : 'Eyewear'}",
                              countsForBadge: true,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Connected to $deviceName"),
                              ),
                            );
                            // Navigator.pop(context); // Don't pop automatically
                          },
                          child: const Text("Connect"),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
