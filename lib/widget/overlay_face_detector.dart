import 'package:flutter/material.dart';

class FaceDetectionShapeBorder extends ShapeBorder {
  final Size cutoutSize;
  final double borderWidth;
  final double borderRadius;

  FaceDetectionShapeBorder({
    required this.cutoutSize,
    this.borderWidth = 2.0,
    this.borderRadius = 10.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rect.center,
            width: cutoutSize.width,
            height: cutoutSize.height,
          ),
          Radius.circular(180),
        )),
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final Paint paint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.fill;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: rect.center,
        width: cutoutSize.width,
        height: cutoutSize.height,
      ),
      Radius.circular(180),
    );

    canvas.drawRRect(rrect, paint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return FaceDetectionShapeBorder(
      cutoutSize: Size(cutoutSize.width * t, cutoutSize.height * t),
      borderWidth: borderWidth * t,
      borderRadius: borderRadius * t,
    );
  }
}
