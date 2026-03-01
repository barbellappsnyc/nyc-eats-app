import 'package:flutter/material.dart';
import 'dart:math';
import 'package:nyc_eats/config/cuisine_constants.dart';

class PostageStampBackground extends StatefulWidget {
  final String cuisine;

  const PostageStampBackground({super.key, required this.cuisine});

  @override
  State<PostageStampBackground> createState() => _PostageStampBackgroundState();
}

class _PostageStampBackgroundState extends State<PostageStampBackground> {
  late List<Widget> _cachedStamps;

  @override
  void initState() {
    super.initState();
    _cachedStamps = _generateStamps(); // 👈 MATH HAPPENS ONLY ONCE!
  }

  @override
  void didUpdateWidget(covariant PostageStampBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cuisine != widget.cuisine) {
      setState(() {
        _cachedStamps = _generateStamps();
      });
    }
  }

  List<String> _getEmojis() {
    final String searchTarget = widget.cuisine.toLowerCase();
    for (var entry in CuisineConstants.emojiPalettes.entries) {
      if (searchTarget.contains(entry.key) || entry.key.contains(searchTarget)) {
        return entry.value;
      }
    }
    return CuisineConstants.emojiPalettes['default']!; 
  }

  List<Widget> _generateStamps() {
    final List<String> emojis = _getEmojis();
    final Random rnd = Random(42); 
    final List<Widget> generatedStamps = [];

    final List<Color> stampColors = [
      const Color(0xFFF9F6EE), const Color(0xFFF4ECD8), const Color(0xFFEFE5D0), 
      const Color(0xFFFDFBF7), const Color(0xFFF5EBE0),
    ];

    final List<Color> postmarkColors = [
      Colors.black87, const Color(0xFF8B1A1A), const Color(0xFF1A2A42), 
    ];

    // Generate an excessive amount (150) to guarantee it fills even the largest Pro Max screens
    for (int i = 0; i < 150; i++) {
      final String emoji = emojis[rnd.nextInt(emojis.length)];
      final Color bgColor = stampColors[rnd.nextInt(stampColors.length)];
      
      // A microscopic rotation so they don't look like sterile computer boxes
      final double slightRotation = (rnd.nextDouble() * 0.1) - 0.05; 
      
      final bool hasPostmark = rnd.nextBool();
      final Color postmarkColor = postmarkColors[rnd.nextInt(postmarkColors.length)];
      final double postmarkRotation = (rnd.nextDouble() * 1.5) - 0.75;

      generatedStamps.add(
        Transform.rotate(
          angle: slightRotation,
          // 🪄 THE FIX: We use SizedBox to define the area, and PhysicalShape to handle the complex teeth+shadow
          child: SizedBox(
            width: 75, 
            height: 90,
            child: PhysicalShape(
              clipper: const StampClipper(), // Cuts the teeth
              color: bgColor, // The paper color
              elevation: 2.0, // Creates a natural, teeth-hugging drop shadow
              shadowColor: Colors.black.withOpacity(0.6),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black.withOpacity(0.2), width: 0.5),
                      ),
                    ),
                  ),
                  Center(child: Text(emoji, style: const TextStyle(fontSize: 34))),
                  Positioned(
                    top: 6, left: 6,
                    child: Text(
                      widget.cuisine.toUpperCase(),
                      style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.black.withOpacity(0.6)),
                    ),
                  ),
                  Positioned(
                    bottom: 6, right: 6,
                    child: Text(
                      "${rnd.nextInt(80) + 10}¢",
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.7)),
                    ),
                  ),
                  if (hasPostmark)
                    Positioned.fill(
                      child: Transform.rotate(
                        angle: postmarkRotation,
                        child: Opacity(
                          opacity: 0.6,
                          child: CustomPaint(
                            painter: PostmarkPainter(color: postmarkColor),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return generatedStamps;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFD6CFC4), 
      width: double.infinity,
      height: double.infinity,
      // 🪄 THE FIX: ClipRect + a locked ScrollView lets the extra stamps safely bleed off the bottom
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(), // Disables scrolling so it remains a static background
          child: Padding(
            padding: const EdgeInsets.only(top: 40, bottom: 40, left: 12, right: 12),
            child: Wrap(
              spacing: 12.0, 
              runSpacing: 16.0, 
              alignment: WrapAlignment.center,
              children: _cachedStamps, 
            ),
          ),
        ),
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

// Drop this at the bottom of postage_stamp_background.dart
class PostmarkPainter extends CustomPainter {
  final Color color;

  PostmarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draws the classic wavy post office cancellation lines
    final Path path = Path();
    for (int i = 0; i < 4; i++) {
      double y = size.height * 0.3 + (i * 12);
      path.moveTo(0, y);
      for (double x = 0; x <= size.width; x += 20) {
        path.quadraticBezierTo(x + 10, y - 5, x + 20, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ✂️ THE PERFORATED EDGE MAKER
class StampClipper extends CustomClipper<Path> {
  const StampClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    const double holeRadius = 2.5; // Size of the teeth cutouts
    
    // How many holes per side
    const int holesX = 6; 
    const int holesY = 8; 

    final stepX = size.width / holesX;
    final stepY = size.height / holesY;

    path.moveTo(0, 0);

    // Top edge (Left to Right)
    for (int i = 0; i < holesX; i++) {
      path.lineTo(stepX * i + stepX / 2 - holeRadius, 0);
      path.arcToPoint(
        Offset(stepX * i + stepX / 2 + holeRadius, 0),
        radius: const Radius.circular(holeRadius),
        clockwise: false,
      );
    }
    path.lineTo(size.width, 0);

    // Right edge (Top to Bottom)
    for (int i = 0; i < holesY; i++) {
      path.lineTo(size.width, stepY * i + stepY / 2 - holeRadius);
      path.arcToPoint(
        Offset(size.width, stepY * i + stepY / 2 + holeRadius),
        radius: const Radius.circular(holeRadius),
        clockwise: false,
      );
    }
    path.lineTo(size.width, size.height);

    // Bottom edge (Right to Left)
    for (int i = holesX - 1; i >= 0; i--) {
      path.lineTo(stepX * i + stepX / 2 + holeRadius, size.height);
      path.arcToPoint(
        Offset(stepX * i + stepX / 2 - holeRadius, size.height),
        radius: const Radius.circular(holeRadius),
        clockwise: false,
      );
    }
    path.lineTo(0, size.height);

    // Left edge (Bottom to Top)
    for (int i = holesY - 1; i >= 0; i--) {
      path.lineTo(0, stepY * i + stepY / 2 + holeRadius);
      path.arcToPoint(
        Offset(0, stepY * i + stepY / 2 - holeRadius),
        radius: const Radius.circular(holeRadius),
        clockwise: false,
      );
    }
    path.lineTo(0, 0);

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}