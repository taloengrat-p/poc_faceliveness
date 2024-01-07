import 'package:flutter/material.dart';

class FaceDetectionPainter extends CustomPainter {
  FaceDetectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawOval(Rect.fromLTRB(10, 10, 10, 10), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
