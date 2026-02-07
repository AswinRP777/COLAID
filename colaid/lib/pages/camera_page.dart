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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🌗 Background gradient (same as Login / Home)
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF020617),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFEFF6FF),
            ],
          );

    final buttonBg = isDark ? Colors.white : const Color(0xFF1E293B);
    final buttonFg = isDark ? Colors.black : Colors.white;
    final iconColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Camera"),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: bgGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt,
                size: 120,
                color: iconColor,
              ),
              const SizedBox(height: 30),

              // Take Photo
              SizedBox(
                width: 240,
                child: FilledButton.icon(
                  icon: const Icon(Icons.camera),
                  label: const Text("Take Photo"),
                  onPressed: () => openCamera(false),
                  style: FilledButton.styleFrom(
                    backgroundColor: buttonBg,
                    foregroundColor: buttonFg,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Record Video
              SizedBox(
                width: 240,
                child: FilledButton.icon(
                  icon: const Icon(Icons.videocam),
                  label: const Text("Record Video"),
                  onPressed: () => openCamera(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: buttonBg,
                    foregroundColor: buttonFg,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Upload
              SizedBox(
                width: 240,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.upload),
                  label: const Text("Upload From Gallery"),
                  onPressed: pickImage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? Colors.white : const Color(0xFF1E293B),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1E293B),
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
