import 'package:flutter/material.dart';
import 'dart:math';

String getBorough(double lat, double lng) {
  if (lat > 40.70 && lat < 40.88 && lng > -74.02 && lng < -73.91) return "MANHATTAN";
  if (lat > 40.57 && lat < 40.74 && lng > -74.04 && lng < -73.85) return "BROOKLYN";
  if (lat > 40.69 && lat < 40.80 && lng > -73.96 && lng < -73.70) return "QUEENS";
  if (lat > 40.80 && lat < 40.92 && lng > -73.93 && lng < -73.78) return "BRONX";
  if (lat > 40.50 && lat < 40.65 && lng > -74.26 && lng < -74.05) return "STATEN IS.";
  return "NEW YORK"; 
}

class CoordinateCollageBackground extends StatelessWidget {
  final List<Map<String, String>> stamps;
  const CoordinateCollageBackground({super.key, required this.stamps});

  @override
  Widget build(BuildContext context) {
    // 🎨 Soft Pastel Palette (Inspired by the reference)
    final List<Color> palette = [
      const Color(0xFFFDFBF7), // Cream/Base Off-White
      const Color(0xFFFFF0F5), // Lavender Blush
      const Color(0xFFE6F2EA), // Minty Pastel
      const Color(0xFFFFF5E1), // Soft Peach/Papaya
      const Color(0xFFE3F0FF), // Alice Blue
      const Color(0xFFF5E6E6), // Dusty Rose Light
      const Color(0xFFFAFAD2), // Light Goldenrod
      const Color(0xFFF0F8FF), // Ice Blue
    ];

    final Random rnd = Random(42); 

    final List<Map<String, String>> sourceStamps = stamps.isNotEmpty 
        ? stamps 
        : [{'lat': '40.7128', 'lng': '-74.0060', 'name': 'NYC EATS'}];

    // 🧱 THE BLOCK BUILDER
    Widget buildBlock(int flex, {bool rotate = false}) {
      final stamp = sourceStamps[rnd.nextInt(sourceStamps.length)];
      double lat = double.tryParse(stamp['lat'] ?? '0') ?? 40.7128;
      double lng = double.tryParse(stamp['lng'] ?? '0') ?? -74.0060;
      
      String name = stamp['name'] ?? 'UNKNOWN';
      String borough = getBorough(lat, lng); 
      String coordText = "${lat.toStringAsFixed(4)}°N\n${lng.abs().toStringAsFixed(4)}°W";
      
      Color bgColor = palette[rnd.nextInt(palette.length)];
      
      // Because it's pastel, text is always dark/black for contrast
      Color textColor = Colors.black87;

      int type = rnd.nextInt(4);
      String displayText;

      if (type == 0) {
        displayText = coordText; 
      } else if (type == 1) {
        displayText = borough; 
      } else if (type == 2) {
        displayText = "📍"; 
      } else {
        displayText = name.toUpperCase(); 
      }

      // 📚 Much wider variety of aesthetic fonts
      List<String?> fonts = [
        'Courier', 
        'Times New Roman', 
        'Georgia', 
        'Helvetica', 
        'Trebuchet MS',
        'Impact', 
        null // Default system font
      ]; 
      String? font = fonts[rnd.nextInt(fonts.length)];

      Widget textWidget = Text(
        displayText,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: font,
          fontWeight: FontWeight.w800,
          color: textColor,
          height: 1.0, // Tighter line spacing
          letterSpacing: -0.5, 
        ),
      );

      if (rotate) {
        textWidget = RotatedBox(quarterTurns: 3, child: textWidget);
      }

      return Expanded(
        flex: flex,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(4), // 👈 Drastically reduced padding
          decoration: BoxDecoration(
            color: bgColor,
            // 👈 Thin, elegant 1px borders just like "Day 130"
            border: Border.all(color: Colors.black87, width: 1.0), 
          ),
          alignment: Alignment.center,
          // 👈 BoxFit.contain forces text to maximize its size inside the box
          child: FittedBox(
            fit: BoxFit.contain,
            child: textWidget,
          ),
        ),
      );
    }

    // 🚀 THE ASSEMBLY: 4 Columns modeled perfectly after "Day 130"
    return Container(
      color: const Color(0xFF111111), 
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // COLUMN 1
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  buildBlock(2, rotate: false),
                  buildBlock(4, rotate: true),
                  buildBlock(2, rotate: false),
                  buildBlock(5, rotate: true),
                ],
              ),
            ),
            
            // COLUMN 2 (Thinner vertical slices)
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  buildBlock(5, rotate: true),
                  buildBlock(2, rotate: false),
                  buildBlock(3, rotate: true),
                  buildBlock(3, rotate: false),
                ],
              ),
            ),

            // COLUMN 3
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  buildBlock(3, rotate: false),
                  buildBlock(5, rotate: true),
                  buildBlock(2, rotate: false),
                  buildBlock(3, rotate: false),
                ],
              ),
            ),

            // COLUMN 4
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  buildBlock(2, rotate: false),
                  buildBlock(4, rotate: true),
                  buildBlock(3, rotate: false),
                  buildBlock(2, rotate: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}