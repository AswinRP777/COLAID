import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'image_preview_page.dart';
import 'live_video_preview_page.dart';

class CameraPreviewPage extends StatefulWidget {
  final CameraController controller;
  final bool isVideo;

  const CameraPreviewPage({
    super.key,
    required this.controller,
    required this.isVideo,
  });

  @override
  State<CameraPreviewPage> createState() => _CameraPreviewPageState();
}

class _CameraPreviewPageState extends State<CameraPreviewPage> {
  bool _capturing = false;

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_capturing) return;

    setState(() => _capturing = true);

    try {
      final XFile file = await widget.controller.takePicture();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImagePreviewPage(
            imageFile: File(file.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to capture image: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // CAMERA PREVIEW
          CameraPreview(widget.controller),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // TOP BAR
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // CAPTURE / VIDEO BUTTON
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: FloatingActionButton.large(
                    heroTag: "capture",
                    backgroundColor:
                        widget.isVideo ? Colors.red : Colors.white,
                    onPressed: widget.isVideo
                        ? () {
                            // 🎥 OPEN LIVE VIDEO COLOR FLIP PAGE
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiveVideoPreviewPage(
                                  controller: widget.controller,
                                ),
                              ),
                            );
                          }
                        : _capturing
                            ? null
                            : _captureImage,
                    child: _capturing
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.black,
                            ),
                          )
                        : Icon(
                            widget.isVideo
                                ? Icons.videocam
                                : Icons.camera_alt,
                            color: widget.isVideo
                                ? Colors.white
                                : Colors.black,
                            size: 30,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
