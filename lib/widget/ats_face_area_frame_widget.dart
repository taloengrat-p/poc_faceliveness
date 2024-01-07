import 'package:flutter/material.dart';
import 'package:poc_faceliveness_ml/widget/overlay_face_detector.dart';

class AtsFaceAreaFrameWidget extends StatelessWidget {
  final Color strokeColor;
  final Color backgroundColor;
  final double borderWidth;

  const AtsFaceAreaFrameWidget({
    Key? key,
    required this.backgroundColor,
    required this.strokeColor,
    this.borderWidth = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        shape: FaceDetectionShapeBorder(
          cutoutSize: const Size(300.0, 380.0),
          borderWidth: borderWidth,
          borderRadius: 10.0,
          strokeColor: strokeColor,
        ),
        color: backgroundColor,
      ),
    );
  }
}
