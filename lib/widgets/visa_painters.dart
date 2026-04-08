import 'package:flutter/material.dart';
import 'dart:math' as math;

// 1. THE 10 REGIONAL ARCHETYPES
enum VisaBatch {
  global, // 🌍 THE EARTH (Compass/Diplomatic) - NEW!
  sinosphere, // East Asia (Imperial Seal)
  oldWorld, // Europe (Classic Banknote)
  sunAndStone, // Latin America (Aztec/Solar)
  arabesque, // Middle East (Geometric/Mosaic)
  oceanic, // Pacific (Waves/Shells)
  subcontinent, // South Asia (Mandala/Fractal)
  newWorld, // North America (Federal/Grid)
  textile, // Africa (Weave/Zigzag)
  nordic, // Scandinavia (Minimalist/Aurora)
  construct, // Eastern Bloc (Industrial/Block)
}

class VisaTheme {
  final String countryName;
  final String countryCode;
  final Color primaryColor;
  final Color secondaryColor;
  final VisaBatch batch;

  VisaTheme(
    this.countryName,
    this.countryCode,
    this.primaryColor,
    this.secondaryColor,
    this.batch,
  );

  // 🧠 THE UNIVERSAL MAPPER (Moved here to clean up the Widget)
  static VisaTheme getTheme(String cuisine, Color fallbackColor) {
    final String lower = cuisine.toLowerCase();

    // 0. 🌍 GLOBAL / EARTH (The Master Page)
    if (lower == 'global' || lower == 'earth' || lower == 'world') {
      return VisaTheme(
        "Planet Earth",
        "WLD",
        const Color(0xFF1A237E),
        const Color(0xFFFFD700),
        VisaBatch.global,
      );
      // Deep Navy + Gold
    }

    // 1. SINOSPHERE (East Asia)
    if (_matches(lower, [
      'japan',
      'sushi',
      'china',
      'dim sum',
      'korea',
      'kimchi',
      'ramen',
      'viet',
      'pho',
      'taiwan',
    ])) {
      Color primary = const Color(0xFFBC002D);
      if (lower.contains('china')) primary = const Color(0xFFFFCC00);
      if (lower.contains('korea')) primary = const Color(0xFF003478);
      return VisaTheme(
        "East Asia Territory",
        "EAS",
        primary,
        Colors.redAccent,
        VisaBatch.sinosphere,
      );
    }

    // 2. OLD WORLD (Europe)
    if (_matches(lower, [
      'ital',
      'pizza',
      'pasta',
      'franc',
      'bistro',
      'german',
      'spanish',
      'tapas',
      'greek',
      'uk',
      'british',
    ])) {
      Color primary = const Color(0xFF008C45);
      if (lower.contains('franc')) primary = const Color(0xFF0055A4);
      if (lower.contains('german')) primary = Colors.black87;
      return VisaTheme(
        "Schengen Zone",
        "EUR",
        primary,
        const Color(0xFFCD212A),
        VisaBatch.oldWorld,
      );
    }

    // 3. SUN & STONE (Latin America)
    if (_matches(lower, [
      'mexic',
      'taco',
      'peru',
      'brazil',
      'argentin',
      'cuban',
      'latin',
    ])) {
      return VisaTheme(
        "Americas South",
        "LAT",
        const Color(0xFF006847),
        const Color(0xFFCE1126),
        VisaBatch.sunAndStone,
      );
    }

    // 4. ARABESQUE (Middle East)
    if (_matches(lower, [
      'lebano',
      'falafel',
      'turk',
      'kebab',
      'arab',
      'middle east',
      'persian',
    ])) {
      return VisaTheme(
        "Levant Region",
        "ME",
        const Color(0xFF007A3D),
        const Color(0xFFC8102E),
        VisaBatch.arabesque,
      );
    }

    // 5. OCEANIC (Pacific)
    if (_matches(lower, [
      'australia',
      'aussie',
      'new zealand',
      'hawaii',
      'poke',
    ])) {
      return VisaTheme(
        "Oceania",
        "OCE",
        const Color(0xFF00008B),
        const Color(0xFFFFD700),
        VisaBatch.oceanic,
      );
    }

    // 6. SUBCONTINENT (South Asia)
    if (_matches(lower, ['india', 'curry', 'pakistan', 'bengal', 'nepal'])) {
      return VisaTheme(
        "South Asia",
        "IND",
        const Color(0xFFFF9933),
        const Color(0xFF138808),
        VisaBatch.subcontinent,
      );
    }

    // 7. NEW WORLD (North America)
    if (_matches(lower, ['usa', 'american', 'burger', 'bbq', 'canada'])) {
      return VisaTheme(
        "North America",
        "USA",
        const Color(0xFF3C3B6E),
        const Color(0xFFB22234),
        VisaBatch.newWorld,
      );
    }

    // 8. TEXTILE (Africa)
    if (_matches(lower, ['ethiop', 'nigeria', 'african', 'morocco'])) {
      return VisaTheme(
        "African Union",
        "AFR",
        const Color(0xFF009639),
        const Color(0xFFFFCE00),
        VisaBatch.textile,
      );
    }

    // 9. NORDIC (Scandinavia)
    if (_matches(lower, ['swed', 'norway', 'danish', 'scandi'])) {
      return VisaTheme(
        "Nordic Council",
        "NOR",
        const Color(0xFF006AA7),
        const Color(0xFFFECC00),
        VisaBatch.nordic,
      );
    }

    // 10. CONSTRUCT (Eastern Bloc)
    if (_matches(lower, ['russia', 'polish', 'ukrain'])) {
      return VisaTheme(
        "Eastern Bloc",
        "EUS",
        const Color(0xFFD52B1E),
        Colors.black,
        VisaBatch.construct,
      );
    }

    // FALLBACK
    final int hash = cuisine.length;
    final batch = VisaBatch.values[hash % VisaBatch.values.length];

    return VisaTheme(
      "Territory of $cuisine",
      cuisine.substring(0, 3).toUpperCase(),
      fallbackColor,
      Colors.grey,
      batch,
    );
  }

  static bool _matches(String input, List<String> keywords) {
    for (final k in keywords) {
      if (input.contains(k)) return true;
    }
    return false;
  }
}

// 🌀 THE UNIVERSAL GUILLOCHE PAINTER (High Contrast Edition)
class UniversalGuillochePainter extends CustomPainter {
  final Color color;
  final Color secondaryColor;
  final VisaBatch batch;

  UniversalGuillochePainter({
    required this.color,
    required this.secondaryColor,
    required this.batch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 🖊️ Increased stroke width slightly for better visibility
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..isAntiAlias = true;
    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (batch) {
      case VisaBatch.global: // 🌍 THE COMPASS ROSE (Diplomatic Style)
        // 1. The Lat/Long Grid Background
        paint.color = color.withOpacity(0.08);
        canvas.drawCircle(Offset(cx, cy), 180, paint); // Globe outline
        // Draw Meridians (Curved lines)
        for (int i = 0; i < 6; i++) {
          double radiusX = 180.0 * (i / 6);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: radiusX * 2,
              height: 360,
            ),
            paint,
          );
        }
        // Draw Parallels (Horizontal lines)
        for (int i = 0; i < 6; i++) {
          double radiusY = 180.0 * (i / 6);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: 360,
              height: radiusY * 2,
            ),
            paint,
          );
        }

        // 2. The Compass Rose (Center)
        paint.color = secondaryColor.withOpacity(0.3); // Gold
        _drawStar(
          canvas,
          cx,
          cy,
          120,
          4,
          0.4,
          paint..strokeWidth = 1,
        ); // Main Points (N,E,S,W)
        _drawStar(
          canvas,
          cx,
          cy,
          80,
          4,
          0.4,
          paint,
          rotation: math.pi / 4,
        ); // Sub Points (NE, SE...)

        // 3. The Outer Ring
        paint.color = color.withOpacity(0.4);
        _drawSpirograph(
          canvas,
          cx,
          cy,
          190,
          185,
          20,
          100,
          paint..strokeWidth = 0.5,
        );
        break;

      case VisaBatch.sinosphere: // 🌸 3D IMPERIAL
        canvas.save();
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateX(0.6)
          ..rotateZ(0.1);
        canvas.translate(cx, cy);
        canvas.transform(matrix.storage);
        canvas.translate(-cx, -cy);

        paint.color = color.withOpacity(0.25);
        _drawSpirograph(canvas, cx, cy, 300, 150, 100, 32, paint);
        canvas.restore();

        paint.color = Colors.black.withOpacity(0.1); // Shadow
        _drawSpirograph(canvas, cx + 5, cy + 8, 85, 5, 75, 16, paint);

        paint.color = color.withOpacity(0.7); // Main Seal
        _drawSpirograph(canvas, cx, cy, 85, 5, 75, 16, paint);

        paint.color = secondaryColor.withOpacity(0.8); // Core
        _drawSpirograph(canvas, cx, cy, 35, 0, 15, 12, paint);
        break;

      case VisaBatch.nordic: // ❄️ 3D AURORA (High Vis)
        canvas.save();
        final auroraMatrix = Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateX(-0.6)
          ..rotateY(0.1);
        canvas.translate(cx, cy);
        canvas.transform(auroraMatrix.storage);
        canvas.translate(-cx, -cy);

        paint.color = color.withOpacity(0.35);
        _drawSpirograph(canvas, cx, cy, 300, 40, 100, 24, paint);
        canvas.restore();

        paint.color = color.withOpacity(0.4);
        _drawSpirograph(canvas, cx, cy, 140, 135, 120, 60, paint);

        paint.color = secondaryColor.withOpacity(0.6);
        _drawSpirograph(canvas, cx, cy, 100, 25, 140, 16, paint);

        paint.color = color.withOpacity(0.8);
        _drawSpirograph(canvas, cx, cy, 40, 0, 10, 6, paint);
        break;

      case VisaBatch.oldWorld: // 🏛️ BANKNOTE
        paint.color = color.withOpacity(0.35);
        _drawSpirograph(canvas, cx, cy, 200, 120, 20, 40, paint);
        paint.color = secondaryColor.withOpacity(0.5);
        _drawSpirograph(canvas, cx, cy, 150, 90, 60, 12, paint);
        break;

      case VisaBatch.sunAndStone: // ☀️ AZTEC
        paint.color = color.withOpacity(0.6);
        _drawSpirograph(canvas, cx, cy, 120, 110, 200, 24, paint);
        break;

      case VisaBatch.oceanic: // 🌊 WAVES
        paint.color = color.withOpacity(0.5);
        _drawSpirograph(canvas, cx, cy, 250, 60, 90, 8, paint);
        paint.color = secondaryColor.withOpacity(0.4);
        _drawSpirograph(canvas, cx, cy, 180, 100, 60, 12, paint);
        break;

      case VisaBatch.newWorld: // 🦅 FEDERAL
        paint.color = color.withOpacity(0.5);
        _drawSpirograph(canvas, cx, cy, 180, 175, 150, 60, paint);
        break;

      case VisaBatch
          .subcontinent: // 🕉️ THE MAHARAJA'S FRAME (Vertical Rubies + Axis Emeralds)

        // LAYER 1: The "Zari" Background Field
        paint.color = color.withOpacity(0.10);
        _drawSpirograph(canvas, cx, cy, 400, 395, 100, 100, paint);

        // LAYER 2: The "Corner Fanlights"
        paint.color = secondaryColor.withOpacity(0.5);
        double cornerR = 120;
        _drawSpirograph(canvas, 0, 0, cornerR, 30, 80, 12, paint);
        _drawSpirograph(canvas, size.width, 0, cornerR, 30, 80, 12, paint);
        _drawSpirograph(canvas, 0, size.height, cornerR, 30, 80, 12, paint);
        _drawSpirograph(
          canvas,
          size.width,
          size.height,
          cornerR,
          30,
          80,
          12,
          paint,
        );

        // LAYER 3: The "Connective Border"
        paint.color = color.withOpacity(0.4);
        for (double i = 0; i < size.width; i += 5) {
          canvas.drawCircle(Offset(i, 20 + 10 * math.sin(i / 20)), 2, paint);
          canvas.drawCircle(
            Offset(i, size.height - 20 + 10 * math.sin(i / 20)),
            2,
            paint,
          );
        }

        // LAYER 4: The "Inner Rectangular Frame"
        final rectPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = secondaryColor.withOpacity(0.3);

        canvas.drawRect(
          Rect.fromLTWH(20, 20, size.width - 40, size.height - 40),
          rectPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(24, 24, size.width - 48, size.height - 48),
          rectPaint,
        );

        // LAYER 4.5: The "Royal Blue Corner Diamonds"
        final diamondPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = Colors.blueAccent.withOpacity(0.9);

        final List<Offset> corners = [
          Offset(55, 55),
          Offset(size.width - 55, 55),
          Offset(55, size.height - 55),
          Offset(size.width - 55, size.height - 55),
        ];

        for (final pos in corners) {
          _drawSpirograph(canvas, pos.dx, pos.dy, 14, 4, 12, 4, diamondPaint);
          canvas.drawCircle(pos, 1.5, diamondPaint..style = PaintingStyle.fill);
          diamondPaint.style = PaintingStyle.stroke;
        }

        // LAYER 4.6: The "Rectangular Flank Rubies" (VERTICAL)
        final rubyPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = Colors.redAccent.withOpacity(0.95);

        final List<Offset> rubyPos = [
          Offset(55, cy), // Left Flank
          Offset(size.width - 55, cy), // Right Flank
        ];

        for (final pos in rubyPos) {
          canvas.save();
          canvas.translate(pos.dx, pos.dy);

          // Draw "Step Cut"
          for (int i = 0; i < 5; i++) {
            double w = 20.0 - (i * 4); // Width shrinks
            double h = 28.0 - (i * 5); // Height shrinks
            canvas.drawRect(
              Rect.fromCenter(center: Offset.zero, width: w, height: h),
              rubyPaint,
            );
          }
          // Solid Ruby Center
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: 4, height: 8),
            rubyPaint..style = PaintingStyle.fill,
          );
          rubyPaint.style = PaintingStyle.stroke;
          canvas.restore();
        }

        // 🆕 LAYER 4.7: The "Axis Emeralds" (Top & Bottom Center)
        final emeraldPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = Colors.greenAccent[700]!.withOpacity(
            0.9,
          ); // Deep Emerald Green

        final List<Offset> emeraldPos = [
          Offset(cx, 55), // Top Center
          Offset(cx, size.height - 55), // Bottom Center
        ];

        for (final pos in emeraldPos) {
          canvas.save();
          canvas.translate(pos.dx, pos.dy);

          // Draw "Octagonal Cut"
          for (int i = 0; i < 4; i++) {
            double s = 22.0 - (i * 5);
            // Square 1
            canvas.drawRect(
              Rect.fromCenter(center: Offset.zero, width: s, height: s),
              emeraldPaint,
            );
            // Square 2 (Rotated 45 degrees)
            canvas.save();
            canvas.rotate(math.pi / 4);
            canvas.drawRect(
              Rect.fromCenter(
                center: Offset.zero,
                width: s * 0.8,
                height: s * 0.8,
              ),
              emeraldPaint,
            );
            canvas.restore();
          }
          // Solid Emerald Center
          canvas.drawCircle(
            Offset.zero,
            3,
            emeraldPaint..style = PaintingStyle.fill,
          );
          emeraldPaint.style = PaintingStyle.stroke;
          canvas.restore();
        }

        // LAYER 5: The "Mini Jewel" (Center)
        paint.color = color.withOpacity(0.8);
        _drawSpirograph(canvas, cx, cy, 45, 5, 35, 24, paint);

        paint.color = secondaryColor.withOpacity(1.0);
        canvas.drawCircle(Offset(cx, cy), 4, paint..style = PaintingStyle.fill);
        break;

      case VisaBatch.arabesque: // 🕌 GEOMETRIC
        paint.color = color.withOpacity(0.5);
        _drawSpirograph(canvas, cx, cy, 140, 70, 70, 6, paint);
        paint.color = secondaryColor.withOpacity(0.5);
        _drawSpirograph(canvas, cx, cy, 140, 70, 35, 12, paint);
        break;

      case VisaBatch.textile: // 🧶 WEAVE
        paint.color = color.withOpacity(0.4);
        _drawSpirograph(canvas, cx, cy, 200, 190, 40, 100, paint);
        break;

      case VisaBatch.construct: // 🧱 BLOCK
        paint.color = color.withOpacity(0.5);
        _drawSpirograph(canvas, cx, cy, 150, 100, 150, 4, paint);
        break;
    }
  }

  // Helper to draw the Compass Star
  void _drawStar(
    Canvas canvas,
    double cx,
    double cy,
    double radius,
    int points,
    double innerRatio,
    Paint paint, {
    double rotation = 0,
  }) {
    final path = Path();
    final double step = math.pi / points;

    for (int i = 0; i < 2 * points; i++) {
      final double r = (i % 2 == 0) ? radius : radius * innerRatio;
      final double currAngle =
          i * step + rotation - (math.pi / 2); // -pi/2 to start at top
      final double x = cx + r * math.cos(currAngle);
      final double y = cy + r * math.sin(currAngle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawSpirograph(
    Canvas canvas,
    double cx,
    double cy,
    double R,
    double r,
    double offset,
    double revolutions,
    Paint paint,
  ) {
    final path = Path();
    final double step = (math.pi * 2) / 360;
    bool firstPoint = true;
    for (double t = 0; t <= math.pi * 2 * revolutions; t += step) {
      final double x =
          cx + (R - r) * math.cos(t) + offset * math.cos(((R - r) / r) * t);
      final double y =
          cy + (R - r) * math.sin(t) - offset * math.sin(((R - r) / r) * t);
      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant UniversalGuillochePainter old) =>
      old.batch != batch || old.color != color;
}

// 🎨 THE BATCH SYMBOL PAINTER (Abstract Watermarks)
class BatchSymbolPainter extends CustomPainter {
  final VisaBatch batch;
  final Color color;
  BatchSymbolPainter({required this.batch, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = color;
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    switch (batch) {
      case VisaBatch.global: // 🌍 GLOBE
        canvas.drawCircle(Offset(cx, cy), w * 0.35, paint);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: w * 0.7,
            height: w * 0.2,
          ),
          paint,
        );
        canvas.drawLine(
          Offset(cx, cy - w * 0.35),
          Offset(cx, cy + w * 0.35),
          paint,
        );
        break;

      case VisaBatch.sinosphere: // Circle/Sun
        canvas.drawCircle(Offset(cx, cy), w * 0.3, paint);
        break;
      case VisaBatch.oldWorld: // Shield Shape
        final path = Path();
        path.moveTo(cx - 40, cy - 40);
        path.lineTo(cx + 40, cy - 40);
        path.quadraticBezierTo(cx + 40, cy + 20, cx, cy + 50);
        path.quadraticBezierTo(cx - 40, cy + 20, cx - 40, cy - 40);
        canvas.drawPath(path, paint);
        break;
      case VisaBatch.sunAndStone: // Diamond/Sun
        final path = Path();
        path.moveTo(cx, cy - 50);
        path.lineTo(cx + 50, cy);
        path.lineTo(cx, cy + 50);
        path.lineTo(cx - 50, cy);
        path.close();
        canvas.drawPath(path, paint);
        break;
      case VisaBatch.oceanic: // Spiral
        final rect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: w * 0.6,
          height: h * 0.6,
        );
        canvas.drawArc(rect, 0, 10, false, paint);
        break;
      case VisaBatch.newWorld: // Star
        _drawStar(canvas, cx, cy, w * 0.3, paint);
        break;
      case VisaBatch.arabesque: // Hexagon
        _drawPolygon(canvas, cx, cy, w * 0.3, 6, paint);
        break;
      case VisaBatch.construct: // Square
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: w * 0.5,
            height: w * 0.5,
          ),
          paint,
        );
        break;
      default: // Generic Globe
        canvas.drawCircle(Offset(cx, cy), w * 0.3, paint);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: w * 0.6,
            height: h * 0.2,
          ),
          paint,
        );
    }
  }

  void _drawStar(
    Canvas canvas,
    double cx,
    double cy,
    double radius,
    Paint paint,
  ) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      double angle = (i * 4 * math.pi) / 5;
      double x = cx + radius * math.sin(angle);
      double y = cy - radius * math.cos(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawPolygon(
    Canvas canvas,
    double cx,
    double cy,
    double radius,
    int sides,
    Paint paint,
  ) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      double angle = (i * 2 * math.pi) / sides;
      double x = cx + radius * math.cos(angle);
      double y = cy + radius * math.sin(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BatchSymbolPainter old) => old.batch != batch;
}
