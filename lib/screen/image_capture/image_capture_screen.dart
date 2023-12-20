import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class ImageCaptureScreen extends StatefulWidget {
  final Map<String, Image?> images;
  const ImageCaptureScreen({
    Key? key,
    required this.images,
  }) : super(key: key);

  @override
  _ImageCaptureScreenState createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        scrollDirection: Axis.horizontal,
        children: widget.images.values
            .map((e) => Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: e,
                ))
            .toList(),
      ),
    );
  }

  List<Image> convertCameraImageToImage(List<CameraImage> cameraImages) {
    return cameraImages.map((e) {
      ByteData byteData = ByteData.sublistView(e.planes[0].bytes);

      // Convert ByteData to Uint8List
      Uint8List imageData = byteData.buffer.asUint8List();

      // Create an Image from the Uint8List
      Image image = Image.memory(imageData);

      return image;
    }).toList();
  }
}
