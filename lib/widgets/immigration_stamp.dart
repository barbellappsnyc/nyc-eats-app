import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImmigrationStamp extends StatelessWidget {
  final String restaurant;
  final String date;

  const ImmigrationStamp({
    super.key,
    required this.restaurant,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    // 1. ANALYZE NAME LENGTH
    // Short: < 12 chars (e.g. "Carbone", "Nobu") -> CIRCLE
    // Medium: < 22 chars (e.g. "Rubirosa Ristorante") -> OCTAGON
    // Long: > 22 chars (e.g. "Chipotle Mexican Grill") -> RECTANGLE
    final int len = restaurant.length;
    final StampShape shape = len < 12
        ? StampShape.circle
        : (len < 22 ? StampShape.octagon : StampShape.rectangle);

    // 2. GENERATE RANDOM CHAOS (Seeded by name so it's consistent per restaurant)
    final int seed = restaurant.hashCode;
    final Random rnd = Random(seed);

    // Ink Colors: Faded Red, Deep Navy, Forest Green, Burnt Orange
    final List<Color> inkColors = [
      const Color(0xFFC0392B), // Faded Red
      const Color(0xFF2C3E50), // Navy
      const Color(0xFF27AE60), // Green
      const Color(0xFFD35400), // Orange
    ];
    final Color inkColor = inkColors[rnd.nextInt(inkColors.length)];

    // Imperfections
    final double opacity = 0.7 + (rnd.nextDouble() * 0.25); // 0.70 to 0.95
    final double rotation =
        (rnd.nextDouble() - 0.5) * 0.1; // Slight tilt (-0.05 to +0.05 rad)
    final bool isDoubleStruck = rnd
        .nextBool(); // 50% chance of double-stamp effect

    return Transform.rotate(
      angle: rotation,
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          width: 140, // Fixed width for grid consistency
          height: 90,
          child: CustomPaint(
            painter: _StampPainter(shape: shape, color: inkColor, seed: seed),
            child: Center(
              child: _buildStampText(shape, inkColor, isDoubleStruck),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStampText(StampShape shape, Color color, bool doubleStrike) {
    // We use a Stack to create a "Double Strike" (blur effect)
    return Stack(
      alignment: Alignment.center,
      children: [
        if (doubleStrike)
          Transform.translate(
            offset: const Offset(1, 1),
            child: _layoutText(shape, color.withOpacity(0.3)),
          ),
        _layoutText(shape, color),
      ],
    );
  }

  Widget _layoutText(StampShape shape, Color color) {
    final TextStyle mainStyle = TextStyle(
      fontFamily: 'Courier',
      fontWeight: FontWeight.w900,
      color: color,
      fontSize: shape == StampShape.rectangle ? 10 : 12,
      letterSpacing: -0.5,
    );

    final TextStyle dateStyle = TextStyle(
      fontFamily: 'Courier',
      fontWeight: FontWeight.bold,
      color: color,
      fontSize: 8,
      letterSpacing: 2.0,
    );

    if (shape == StampShape.rectangle) {
      // 📦 STACKED LAYOUT
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("ENTRY PERMITTED", style: dateStyle.copyWith(fontSize: 6)),
          const SizedBox(height: 4),
          Text(
            restaurant.toUpperCase(),
            textAlign: TextAlign.center,
            style: mainStyle,
            maxLines: 2,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 4),
          Container(height: 1, width: 80, color: color),
          const SizedBox(height: 2),
          Text(date.toUpperCase(), style: dateStyle),
        ],
      );
    } else {
      // ⭕ CENTERED LAYOUT
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon or Rating placeholder
          Icon(Icons.verified, size: 14, color: color.withOpacity(0.6)),
          const SizedBox(height: 2),
          Text(
            restaurant.toUpperCase(),
            textAlign: TextAlign.center,
            style: mainStyle,
            maxLines: 2,
          ),
          Text(date.toUpperCase(), style: dateStyle.copyWith(fontSize: 7)),
        ],
      );
    }
  }
}

enum StampShape { circle, octagon, rectangle }

class _StampPainter extends CustomPainter {
  final StampShape shape;
  final Color color;
  final int seed;

  _StampPainter({required this.shape, required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final Random rnd = Random(seed);

    // 🎨 INK STYLE (Rough, slightly jagged lines)
    final Paint borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          2.0 +
          rnd
              .nextDouble() // Variable thickness
      ..strokeJoin = StrokeJoin.round;

    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;

    Path path = Path();

    // 1. DRAW SHAPE
    switch (shape) {
      case StampShape.circle:
        // Draw imperfect circle
        final double radius = min(w, h) / 2 - 5;
        path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));

        // Inner Ring (Grand Tour Style)
        canvas.drawCircle(
          Offset(cx, cy),
          radius - 4,
          borderPaint..strokeWidth = 0.8,
        );
        borderPaint.strokeWidth = 2.5; // Reset
        break;

      case StampShape.octagon:
        // Draw Octagon
        final double radius = min(w, h) / 2 - 5;
        for (int i = 0; i < 8; i++) {
          final double theta = (i * pi / 4) - (pi / 8); // Rotate to flat top
          final double x = cx + radius * cos(theta);
          final double y = cy + radius * sin(theta);
          if (i == 0)
            path.moveTo(x, y);
          else
            path.lineTo(x, y);
        }
        path.close();
        break;

      case StampShape.rectangle:
        // Draw "Ticket" Shape (Rounded Rect with Corners)
        final Rect rect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: w - 10,
          height: h - 20,
        );
        path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)));

        // Add decorative corners
        final double cornerSize = 10;
        final Paint cornerFill = Paint()..color = color;
        // Top Left
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, cornerSize, 1),
          cornerFill,
        );
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, 1, cornerSize),
          cornerFill,
        );
        // Bottom Right
        canvas.drawRect(
          Rect.fromLTWH(rect.right - cornerSize, rect.bottom, cornerSize, 1),
          cornerFill,
        );
        canvas.drawRect(
          Rect.fromLTWH(rect.right, rect.bottom - cornerSize, 1, cornerSize),
          cornerFill,
        );
        break;
    }

    // 2. APPLY "GRUNGE" MASK (Simulate Ink Gaps)
    // We use a shader to make the stroke look uneven
    borderPaint.shader = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(w, h),
      [color, color.withOpacity(0.8), color],
      [0.0, 0.5, 1.0],
    );

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _StampPainter old) => old.seed != seed;
}
