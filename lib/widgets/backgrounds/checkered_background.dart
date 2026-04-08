import 'package:flutter/material.dart';

class CheckeredBackground extends StatelessWidget {
  const CheckeredBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: CustomPaint(painter: _CheckerPainter()));
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = const Color(0xFFE0E0E0); // Light Grey
    final paint2 = Paint()..color = const Color(0xFFFFFFFF); // White

    const double squareSize = 20.0;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        // Alternate colors based on row and column
        bool isEvenRow = (y / squareSize).floor() % 2 == 0;
        bool isEvenCol = (x / squareSize).floor() % 2 == 0;

        final paint = (isEvenRow == isEvenCol) ? paint1 : paint2;

        canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
