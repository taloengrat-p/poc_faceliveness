import 'dart:async';
import 'dart:developer' as develop;
import 'package:image/image.dart' as imglib;
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:poc_faceliveness_ml/widget/ats_face_area_frame_widget.dart';

enum CaptureState { PREPARE, CAPTURING, WAIT }

enum FaceClassification {
  LEFT,
  RIGHT,
  TOP,
  BOTTOM,
  FRONT,
  SMILING,
  NONE,
  FACE_NOT_DETECTED,
  TOO_FAR;
}

class AtsFaceCameraWidget extends StatefulWidget {
  final Rect rectInPrefer;
  final Rect rectOutPrefer;
  final FaceClassification faceClassificationTarget;
  final Function(FaceClassification faceClassification, Image value)? onSuccess;
  final Function(int? value)? onCountdownChange;
  final Function(FaceClassification)? onFaceEventUpdate;
  final int countDownNumber;
  final bool isDebug;
  final Color backgroundColor;
  final Color strokeColorReadyState;
  final Color strokeColorNotReadyState;

  const AtsFaceCameraWidget({
    super.key,
    required this.rectInPrefer,
    required this.rectOutPrefer,
    required this.faceClassificationTarget,
    this.onSuccess,
    required this.countDownNumber,
    this.isDebug = false,
    this.backgroundColor = Colors.white,
    this.strokeColorReadyState = const Color(0xFF38939B),
    this.strokeColorNotReadyState = const Color(0xFFEC4B55),
    this.onCountdownChange,
    this.onFaceEventUpdate,
  });

  @override
  _AtsFaceCameraWidgetState createState() => _AtsFaceCameraWidgetState();
}

class _AtsFaceCameraWidgetState extends State<AtsFaceCameraWidget> {
  final String TAG = 'AtsFaceCameraWidget';
  late CameraController _controller;
  Future<void>? _initializeControllerFuture;
  late List<CameraDescription> cameras;
  bool isCaptureMode = true;
  double smileProb = 0;
  double rotX = 0;
  double rotY = 0;
  double rotZ = 0;
  FaceClassification faceClassification = FaceClassification.NONE;
  CaptureState captureState = CaptureState.WAIT;
  Timer? _timer;
  Set<FaceClassification> livenessDetectedSets = {};
  int _captureCounter = 3;

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  String rotState = '';
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true, enableTracking: true),
  );

  bool get isValidBeforeCaptureImage =>
      captureState == CaptureState.PREPARE &&
      livenessDetectedSets.contains(widget.faceClassificationTarget) &&
      livenessDetectedSets.length == 1;

  get currentOnlySingleFaceState => livenessDetectedSets.length == 1 ? livenessDetectedSets.first : null;

  bool get isVisibleCounterText => _captureCounter != 0 && _captureCounter != _captureCounterPrefer;

  int get _captureCounterPrefer => widget.countDownNumber + 1;

  @override
  void dispose() {
    _initializeControllerFuture = null;
    doStopTimer();
    _controller.stopImageStream();
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _captureCounter = widget.countDownNumber;
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
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Initialize the camera controller.
      _initializeControllerFuture = _controller.initialize().then((_) {
        if (!mounted) {
          return;
        }
        _controller.startImageStream((CameraImage cameraImage) {
          Future.delayed(const Duration(milliseconds: 500), () {
            doStreamProcessCamera(cameraImage);
          });
        });
      });
      // if (_controller.description.lensDirection == CameraLensDirection.back) {}
      setState(() {});
    }
  }

  Future<void> processCameraImage(
    CameraImage cameraImage,
  ) async {
    develop.log('processCameraImage::');
    final inputImage = _inputImageFromCameraImage(cameraImage);

    if (inputImage == null) {
      return;
    }

    final List<Face> faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      widget.onFaceEventUpdate?.call(FaceClassification.FACE_NOT_DETECTED);
      livenessDetectedSets.clear();
      return;
    }
    // develop.log(faces.toString(), name: TAG);
    for (Face face in faces) {
      final Rect boundingBox = face.boundingBox;

      final isInBound = isInBoundary(boundingBox);
      final isOutBound = isOutBoundary(boundingBox);

      if (isInBound && isOutBound) {
        widget.onFaceEventUpdate?.call(FaceClassification.TOO_FAR);
      }

      doUpdateCaptureState(boundingBox);
      doUpdateAllRot(face);
      doUpdateClassification(face);
      doUpdateFacePropInfo(boundingBox, face);
      doUpdateLivenessDetectedSets();

      // if (currentCaptureState == CaptureState.PREPARE) {

      //   doCaptureCameraImage(imageFrame, );
      // }
      // develop.log('processCameraImage:face: $rotX $rotY $rotZ');
      // If landmark detection was enabled with FaceDetectorOptions (mouth, ears,
      // eyes, cheeks, and nose available):
      // final FaceLandmark? leftEar = face.landmarks[FaceLandmarkType.lef];
      // if (leftEar != null) {
      //   final Point<int> leftEarPos = leftEar.position;
      // }

      // // If face tracking was enabled with FaceDetectorOptions:
      // if (face.trackingId != null) {
      //   final int? id = face.trackingId;
      // }

      if (currentOnlySingleFaceState != null && isCaptureMode) {
        doStartCounterSaveImage(currentOnlySingleFaceState, cameraImage, inputImage);
      }
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas
    final camera = cameras.firstWhere((element) => element.lensDirection == CameraLensDirection.front);
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[_controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  bool isFrontLivenessDetected() {
    return !isLeftLivenessDetected() &&
        !isRightLivenessDetected() &&
        !isTopLivenessDetected() &&
        !isBottomLivenessDetected();
  }

  bool isLeftLivenessDetected() {
    return rotY < -20;
  }

  bool isRightLivenessDetected() {
    return rotY > 20;
  }

  bool isTopLivenessDetected() {
    return rotX > 10;
  }

  bool isBottomLivenessDetected() {
    return rotX < -10;
  }

  bool isSmileLivenessDetected() {
    return smileProb >= 0.7;
  }

  bool isMaskDetected() {
    return false;
  }

  Color getStrokeColor() {
    if (captureState == CaptureState.PREPARE) {
      return widget.strokeColorReadyState;
    } else if (captureState == CaptureState.CAPTURING) {
      return widget.strokeColorReadyState;
    } else {
      return widget.strokeColorNotReadyState;
    }
  }

  Future<void> onSaveImage(
      FaceClassification faceClassification, CameraImage cameraImage, InputImage inputImage) async {
    if (!isValidBeforeCaptureImage) {
      return;
    }

    Image image = await _convertXFileToImage();

    widget.onSuccess?.call(widget.faceClassificationTarget, image);
  }

  Future<Image> _convertXFileToImage() async {
    XFile xFile = await _controller.takePicture();
    Uint8List uint8list = await xFile.readAsBytes();
    Image image = Image.memory(uint8list);
    return image;
  }

  bool isInBoundary(Rect boundingBox) {
    return (widget.rectInPrefer.contains(boundingBox.topLeft) &&
            widget.rectInPrefer.contains(boundingBox.bottomRight)) ||
        widget.rectInPrefer.contains(boundingBox.topRight) && widget.rectInPrefer.contains(boundingBox.bottomLeft);
  }

  bool isOutBoundary(Rect boundingBox) {
    return (!widget.rectOutPrefer.contains(boundingBox.topLeft) &&
            !widget.rectOutPrefer.contains(boundingBox.bottomRight)) ||
        !widget.rectOutPrefer.contains(boundingBox.topRight) && !widget.rectOutPrefer.contains(boundingBox.bottomLeft);
  }

  CaptureState doUpdateCaptureState(Rect boundingBox) {
    if (isInBoundary(boundingBox) && isOutBoundary(boundingBox)) {
      captureState = CaptureState.PREPARE;
    } else {
      captureState = CaptureState.WAIT;
    }

    return captureState;
  }

  void doUpdateAllRot(Face face) {
    rotX = face.headEulerAngleX ?? 0; // Head is tilted up and down rotX degrees
    rotY = face.headEulerAngleY ?? 0; // Head is rotated to the right rotY degrees
    rotZ = face.headEulerAngleZ ?? 0; // Head is tilted sideways rotZ degrees
  }

  void doUpdateClassification(Face face) {
    // If classification was enabled with FaceDetectorOptions:
    if (face.smilingProbability != null) {
      smileProb = face.smilingProbability ?? 0;
    }
  }

  void doUpdateFacePropInfo(Rect boundingBox, Face face) {
    rotState = '''
boundingBox: $boundingBox
X: $rotX 
Y: $rotY 
Z: $rotZ
smileProb: $smileProb''';
  }

  void doUpdateLivenessDetectedSets() {
    if (isLeftLivenessDetected()) {
      livenessDetectedSets.add(FaceClassification.LEFT);
    } else {
      if (livenessDetectedSets.contains(FaceClassification.LEFT)) {
        livenessDetectedSets.remove(FaceClassification.LEFT);
      }
    }

    if (isRightLivenessDetected()) {
      livenessDetectedSets.add(FaceClassification.RIGHT);
    } else {
      if (livenessDetectedSets.contains(FaceClassification.RIGHT)) {
        livenessDetectedSets.remove(FaceClassification.RIGHT);
      }
    }

    if (isTopLivenessDetected()) {
      livenessDetectedSets.add(FaceClassification.TOP);
    } else {
      if (livenessDetectedSets.contains(FaceClassification.TOP)) {
        livenessDetectedSets.remove(FaceClassification.TOP);
      }
    }

    if (isBottomLivenessDetected()) {
      livenessDetectedSets.add(FaceClassification.BOTTOM);
    } else {
      if (livenessDetectedSets.contains(FaceClassification.BOTTOM)) {
        livenessDetectedSets.remove(FaceClassification.BOTTOM);
      }
    }

    if (isFrontLivenessDetected()) {
      livenessDetectedSets.add(FaceClassification.FRONT);
    } else {
      if (livenessDetectedSets.contains(FaceClassification.FRONT)) {
        livenessDetectedSets.remove(FaceClassification.FRONT);
      }
    }
    if (isSmileLivenessDetected()) {
      livenessDetectedSets.add(FaceClassification.SMILING);
    } else {
      if (livenessDetectedSets.contains(FaceClassification.SMILING)) {
        livenessDetectedSets.remove(FaceClassification.SMILING);
      }
    }

    if (isMaskDetected()) {}
  }

  void doStreamProcessCamera(CameraImage cameraImage) {
    setState(() {
      processCameraImage(cameraImage);
    });
  }

  void doStartCounterSaveImage(
      FaceClassification currentOnlySingleFaceState, CameraImage cameraImage, InputImage inputImage) async {
    if (_timer != null) {
      if (!isValidBeforeCaptureImage) {
        doStopTimer();
      }

      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_captureCounter > 0) {
        _captureCounter--;
        widget.onCountdownChange?.call(_captureCounter);
      } else {
        await onSaveImage(currentOnlySingleFaceState, cameraImage, inputImage);
        doStopTimer();
      }

      setState(() {});
    });
  }

  doStopTimer() {
    _captureCounter = widget.countDownNumber + 1;
    _timer?.cancel();
    _timer = null;
    widget.onCountdownChange?.call(null);
  }

  Future<File> convertImagetoPng(CameraImage cameraImage) async {
    // Create a 256x256 8-bit (default) rgb (default) image.
    final image = imglib.Image(width: cameraImage.width, height: cameraImage.height);
    // Iterate over its pixels
    for (var pixel in image) {
      // Set the pixels red value to its x position value, creating a gradient.
      pixel
        ..r = pixel.x
        // Set the pixels green value to its y position value.
        ..g = pixel.y;
    }
    // Encode the resulting image to the PNG image format.
    final png = imglib.encodePng(image);
    // Write the PNG formatted data to a file.
    return await File('image.png').writeAsBytes(png);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: CameraPreview(
                      _controller,
                      child: Center(
                        child: AtsFaceAreaFrameWidget(
                          backgroundColor: widget.backgroundColor,
                          strokeColor: getStrokeColor(),
                        ),
                      ),
                    ),
                  ),
                ),
                Visibility(
                  visible: widget.isDebug,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.white,
                      child: Text(rotState),
                    ),
                  ),
                ),
                Visibility(
                  visible: livenessDetectedSets.isNotEmpty && widget.isDebug,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(10),
                      color: Colors.white,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            livenessDetectedSets.map((e) => '${e.name} ').toString(),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                            ),
                          ),
                          Visibility(
                            visible: isVisibleCounterText,
                            child: Container(
                              margin: const EdgeInsets.only(top: 8),
                              child: Text(
                                (_captureCounter).toString(),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 32,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
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
}
