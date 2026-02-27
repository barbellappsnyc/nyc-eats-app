import 'package:flutter/material.dart';
import 'dart:math';
import 'package:nyc_eats/config/cuisine_constants.dart';

class PostageStampBackground extends StatelessWidget {
  final String cuisine;
  const PostageStampBackground({super.key, required this.cuisine});

  // 🌍 Borrowing the emojis! Returns a list of emojis based on the cuisine
  List<String> _getEmojiPalette() {
    final String searchTarget = cuisine.toLowerCase();

    for (var entry in CuisineConstants.emojiPalettes.entries) {
      if (searchTarget.contains(entry.key) || entry.key.contains(searchTarget)) {
        return entry.value;
      }
    }

    // Default Travel Palette if cuisine isn't in the list
    return ['🌍', '✈️', '🗺️', '🎫', '🧳', '📸']; 
  }

  @override
  Widget build(BuildContext context) {
    final List<String> emojiPalette = _getEmojiPalette();
    final Random rnd = Random(42); 

    // 🎨 Ultra-bright, high-saturation colors
    final List<Color> stampColors = [
      const Color(0xFFFF3B30), // Pure Red
      const Color(0xFF007AFF), // Pure Blue
      const Color(0xFF34C759), // Pure Green
      const Color(0xFFFF9500), // Pure Orange
      const Color(0xFFAF52DE), // Pure Purple
      const Color(0xFFFFCC00), // Pure Yellow
      const Color(0xFF5AC8FA), // Pure Light Blue
    ];

    return Container(
      color: const Color(0xFFFDFBF7), 
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 11, // 👈 CHANGED: 11 columns makes them much smaller!
          childAspectRatio: 0.82, 
        ),
        itemCount: 600, // 👈 CHANGED: Generated way more to fill the screen
        itemBuilder: (context, index) {
          final Color randomStampColor = stampColors[rnd.nextInt(stampColors.length)];
          final String randomEmoji = emojiPalette[rnd.nextInt(emojiPalette.length)];

          return Padding(
            padding: const EdgeInsets.all(3.0), // 👈 CHANGED: Tighter spacing
            child: CustomPaint(
              painter: PostageStampPainter(), 
              child: Container(
                margin: const EdgeInsets.all(2), // 👈 CHANGED: Thinner white border
                decoration: BoxDecoration(color: randomStampColor),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Text(randomEmoji, style: const TextStyle(fontSize: 16)), // Smaller base font
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// 🖌️ THE MAGIC PAINTER: Mathematically cuts out the serrated edges!
class PostageStampPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // ... inside PostageStampPainter -> paint()
    final rectPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // 2. Prepare the holes we want to punch out
    final holesPath = Path();
    final double holeRadius = 1.2; // 👈 CHANGED: Smaller holes for smaller stamps
    final double spacing = 5.0;    // 👈 CHANGED: Tighter spacing for the teeth

    // Punch top & bottom holes
    int hHoles = (size.width / spacing).floor();
    double hOffset = (size.width - (hHoles * spacing)) / 2;
    for (int i = 0; i <= hHoles; i++) {
      double cx = hOffset + (i * spacing);
      holesPath.addOval(Rect.fromCircle(center: Offset(cx, 0), radius: holeRadius));
      holesPath.addOval(Rect.fromCircle(center: Offset(cx, size.height), radius: holeRadius));
    }

    // Punch left & right holes
    int vHoles = (size.height / spacing).floor();
    double vOffset = (size.height - (vHoles * spacing)) / 2;
    for (int i = 0; i <= vHoles; i++) {
      double cy = vOffset + (i * spacing);
      holesPath.addOval(Rect.fromCircle(center: Offset(0, cy), radius: holeRadius));
      holesPath.addOval(Rect.fromCircle(center: Offset(size.width, cy), radius: holeRadius));
    }

    // 3. Subtract the holes from the rectangle
    final stampPath = Path.combine(PathOperation.difference, rectPath, holesPath);
    
    // 4. Draw a subtle shadow behind the newly carved shape
    canvas.drawShadow(stampPath, Colors.black, 2.0, true);
    
    // 5. Paint the final white shape
    canvas.drawPath(stampPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}