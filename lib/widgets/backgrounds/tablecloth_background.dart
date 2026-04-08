import 'package:flutter/material.dart';
import 'dart:math' as math;

class PizzeriaTableclothBackground extends StatelessWidget {
  const PizzeriaTableclothBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDFBF7), // Slightly warm, off-white cloth base
      // ClipRect prevents the rotated cloth from bleeding outside the background area
      child: ClipRect(
        child: Transform.scale(
          scale: 1.2, // Scaled up to hide the edges of the rotated canvas
          child: Transform.rotate(
            angle:
                -math.pi /
                24, // A very slight -7.5 degree tilt for that organic, thrown-on-a-table feel
            child: CustomPaint(size: Size.infinite, painter: _GinghamPainter()),
          ),
        ),
      ),
    );
  }
}

class _GinghamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // The width of each square
    const double squareSize = 45.0;

    // THE ICONIC PIZZERIA BRIGHT RED (Vivid, clean, classic)
    // 0xFFFF1111 is a pure, bright, punchy red.
    // Opacity 0.4 keeps it from being overwhelming and creates perfect, clean intersections.
    final Paint redPaint = Paint()
      ..color = const Color(0xFFFF1111).withOpacity(0.4)
      ..style = PaintingStyle.fill;

    // 1. Paint Vertical Stripes
    for (double x = 0; x < size.width; x += squareSize * 2) {
      canvas.drawRect(
        Rect.fromLTWH(x, -100, squareSize, size.height + 200),
        redPaint,
      );
    }

    // 2. Paint Horizontal Stripes
    for (double y = -100; y < size.height + 200; y += squareSize * 2) {
      canvas.drawRect(
        Rect.fromLTWH(-100, y, size.width + 200, squareSize),
        redPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
