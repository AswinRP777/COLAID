import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'image_preview_page.dart';
import 'camera_preview_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? controller;
  List<CameraDescription>? cameras;

  @override
  void initState() {
    super.initState();
    loadCamera();
  }

  Future<void> loadCamera() async {
    cameras = await availableCameras();
  }

  // Upload image from gallery
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewPage(
          imageFile: File(pickedFile.path),
        ),
      ),
    );
  }

  // Open camera
  Future<void> openCamera(bool isVideo) async {
    cameras ??= await availableCameras();

    controller = CameraController(
      cameras![0],
      ResolutionPreset.high,
      enableAudio: isVideo,
    );

    await controller!.initialize();
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraPreviewPage(
          controller: controller!,
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Camera")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 120, color: Colors.blueGrey),
            const SizedBox(height: 30),

            ElevatedButton.icon(
              icon: const Icon(Icons.camera),
              label: const Text("Take Photo"),
              onPressed: () => openCamera(false),
            ),

            ElevatedButton.icon(
              icon: const Icon(Icons.videocam),
              label: const Text("Record Video"),
              onPressed: () => openCamera(true),
            ),

            ElevatedButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text("Upload From Gallery"),
              onPressed: pickImage,
            ),
          ],
        ),
      ),
    );
  }
}
