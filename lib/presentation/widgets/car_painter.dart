import 'package:flutter/material.dart';

/// A car seen from above, pointing up (north). Rotate the widget to turn it.
class CarPainter extends CustomPainter {
  const CarPainter();

  static const _bodyColor = Color(0xFF263238);
  static const _glassColor = Color(0xFFB3E5FC);
  static const _lightColor = Color(0xFFFFEB3B);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Body: a rounded rectangle, narrower than it is long.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.25, h * 0.05, w * 0.5, h * 0.9),
      Radius.circular(w * 0.14),
    );
    canvas.drawShadow(Path()..addRRect(body), Colors.black, 3, false);
    canvas.drawRRect(body, Paint()..color = _bodyColor);
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05,
    );

    final glass = Paint()..color = _glassColor;
    // Windshield (front, at the top).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.32, h * 0.24, w * 0.36, h * 0.16),
        Radius.circular(w * 0.04),
      ),
      glass,
    );
    // Rear window.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.34, h * 0.70, w * 0.32, h * 0.10),
        Radius.circular(w * 0.04),
      ),
      glass,
    );

    // Headlights, so the front is easy to see.
    final light = Paint()..color = _lightColor;
    canvas.drawCircle(Offset(w * 0.36, h * 0.11), w * 0.04, light);
    canvas.drawCircle(Offset(w * 0.64, h * 0.11), w * 0.04, light);
  }

  @override
  bool shouldRepaint(CarPainter oldDelegate) => false;
}
