import 'dart:developer';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
// import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:poc_faceliveness_ml/screen/image_capture/image_capture_screen.dart';
import 'package:poc_faceliveness_ml/widget/face_scanner_overlay_shape.dart';
import 'package:poc_faceliveness_ml/widget/qr_scanner_overlay_shape.dart';

import '../../widget/overlay_face_detector.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  Future<void>? _initializeControllerFuture;
  late List<CameraDescription> cameras;
  Map<String, Image?> images = {
    'front': null,
    'left': null,
    'right': null,
  };
  final FaceDetector _faceDetector = FirebaseVision.instance.faceDetector(FaceDetectorOptions(enableLandmarks: true));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeCamera();
    });
  }

  Future<void> initializeCamera() async {
    // Get the list of available cameras.
    cameras = await availableCameras();

    if (cameras.isEmpty) {
      // Handle no available cameras.
    } else {
      // Use the first camera from the list.
      _controller = CameraController(
        cameras.firstWhere((element) => element.lensDirection == CameraLensDirection.front),
        ResolutionPreset.medium,
      );

      // Initialize the camera controller.
      _initializeControllerFuture = _controller.initialize().then((_) {
        if (!mounted) {
          return;
        }
        _controller.startImageStream((CameraImage cameraImage) {
          log('process camera ');
          // processCameraImage(cameraImage);
        });
        setState(() {});
      });
      this.cameras = cameras;
      // if (_controller.description.lensDirection == CameraLensDirection.back) {}
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    var scanArea =
        (MediaQuery.of(context).size.width < 400 || MediaQuery.of(context).size.height < 400) ? size.width - 40 : 400.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Face Liveness')),
      body: FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return Stack(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: CameraPreview(
                    _controller,
                  ),
                ),
                Center(
                  child: Container(
                    // decoration: ShapeDecoration(
                    //   shape: QrScannerOverlayShape(
                    //       borderColor: Colors.white, borderLength: 30, borderWidth: 10, cutOutSize: scanArea),
                    // ),
                    decoration: ShapeDecoration(
                      shape: FaceDetectionShapeBorder(
                        cutoutSize: Size(300.0, 300.0),
                        borderWidth: 2.0,
                        borderRadius: 10.0,
                      ),
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator.adaptive());
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.stopImageStream();
    _controller.dispose();
    // _faceDetector.close();
    super.dispose();
  }

  // void processCameraImage(CameraImage cameraImage) async {
  //   try {
  //     final FirebaseVisionImage visionImage = FirebaseVisionImage.fromBytes(
  //       cameraImage.planes[0].bytes,
  //       FirebaseVisionImageMetadata(
  //         size: Size(
  //           cameraImage.width.toDouble(),
  //           cameraImage.height.toDouble(),
  //         ),
  //         rotation: ImageRotation.rotation0,
  //       ),
  //     );

  //     List<Face> faces = await _faceDetector.processImage(visionImage);

  //     log('faces result : $faces');
  //     // Process detected faces and update your UI accordingly
  //     // Example: draw a rectangle around each detected face
  //     // (You can use a custom widget or use CustomPaint to draw on top of the CameraPreview)

  //     // Your face detection UI logic here...
  //   } catch (e) {
  //     print(e.toString());
  //   }
  // }
}
