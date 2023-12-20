import 'package:flutter/material.dart';

class FaceScannerOverlayShape extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OverlayShape(
      cutoutSize: Size(250.0, 250.0), // Size of the face detection area
      borderColor: Colors.white,
      borderStrokeWidth: 2.0,
      borderRadius: 10.0,
      borderLength: 20.0,
      cutoutRadius: 10.0,
      centerAreaColor: Colors.green, // Highlight color for the center area
    );
  }
}

class OverlayShape extends StatelessWidget {
  final Size cutoutSize;
  final Color borderColor;
  final double borderStrokeWidth;
  final double borderRadius;
  final double borderLength;
  final double cutoutRadius;
  final Color centerAreaColor;

  OverlayShape({
    required this.cutoutSize,
    required this.borderColor,
    required this.borderStrokeWidth,
    required this.borderRadius,
    required this.borderLength,
    required this.cutoutRadius,
    required this.centerAreaColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.7,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Positioned(
            left: (MediaQuery.of(context).size.width - cutoutSize.width) / 2,
            top: (MediaQuery.of(context).size.height - cutoutSize.height) / 2,
            child: Container(
              width: cutoutSize.width,
              height: cutoutSize.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(cutoutRadius),
                border: Border.all(
                  color: borderColor,
                  width: borderStrokeWidth,
                ),
                color: centerAreaColor, // Highlight color for the center area
              ),
            ),
          ),
          Positioned(
            left: (MediaQuery.of(context).size.width - cutoutSize.width) / 2,
            top: (MediaQuery.of(context).size.height - cutoutSize.height) / 2 - borderLength / 2,
            child: Container(
              width: cutoutSize.width,
              height: borderLength,
              color: borderColor,
            ),
          ),
          Positioned(
            left: (MediaQuery.of(context).size.width - cutoutSize.width) / 2 - borderLength / 2,
            top: (MediaQuery.of(context).size.height - cutoutSize.height) / 2,
            child: Container(
              width: borderLength,
              height: cutoutSize.height,
              color: borderColor,
            ),
          ),
        ],
      ),
    );
  }
}
