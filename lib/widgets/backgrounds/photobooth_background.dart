import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import 'dart:io'; // 👈 Required to display local files

class PhotoboothBackground extends StatelessWidget {
  const PhotoboothBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF050505), // Pitch black base
      child: CustomPaint(
        painter: StaticBokehPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class StaticBokehPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // We use a fixed seed so the bokeh looks exactly the same every time 
    // the user opens this specific screen, adding to the "memory" vibe.
    final random = Random(42); 
    
    final colors = [
      const Color(0x66FF3B30), // Apple Red
      const Color(0x55FFCC00), // Warm Amber
      const Color(0x22FFFFFF), // Headlight White
      const Color(0x44007AFF), // Distant Neon Blue
    ];

    for (int i = 0; i < 20; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double radius = random.nextDouble() * 80 + 30;
      Color color = colors[random.nextInt(colors.length)];

      final paint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25.0); // Heavy blur

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false; // Completely static!
}

class PhotoStripCard extends StatelessWidget {
  final String borough;
  final String dateText;
  final VoidCallback onDateTapped;
  final List<String?> photoPaths;
  final List<int> photoRotations; // 👈 NEW: list of 0-3 values
  final Function(int) onPhotoTapped;
  final Function(int) onRotatePhoto; // 👈 NEW: Callback for the button

  const PhotoStripCard({
    super.key,
    required this.borough,
    required this.dateText,
    required this.onDateTapped,
    required this.photoPaths,
    required this.photoRotations, // 👈 Required
    required this.onPhotoTapped,
    required this.onRotatePhoto, // 👈 Required
  });
//... (build method stays the same, it just passes index to _buildPhotoSlot)

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A192F), 
        borderRadius: BorderRadius.circular(12), // Slightly softer corners for the fat rectangle
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 25, offset: const Offset(0, 15))
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 🍕 THE STRUCTURED WALLPAPER EMOJI PATTERN
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final emojis = ["🍕", "🌮", "🍣", "🍔", "🍩", "🍷", "🍝", "🥟"];
                List<Widget> pattern = [];
                
                double spacing = 55.0; // Slightly wider spacing for the fat rectangle
                int rows = (constraints.maxHeight / spacing).ceil() + 1;
                int cols = (constraints.maxWidth / spacing).ceil() + 1;
                
                int emojiIndex = 0;
                
                for (int r = -1; r <= rows; r++) {
                  for (int c = -1; c <= cols; c++) {
                    double xOffset = (r % 2 == 0) ? 0.0 : spacing / 2.0;
                    pattern.add(
                      Positioned(
                        left: (c * spacing) + xOffset - 10, 
                        top: (r * spacing) - 10,            
                        child: Text(
                          emojis[emojiIndex % emojis.length],
                          style: const TextStyle(fontSize: 34), 
                        ),
                      )
                    );
                    emojiIndex++;
                  }
                }
                
                return Stack(children: pattern);
              }
            ),
          ),
          
          // 📸 THE FOREGROUND (2x2 Grid + White Label)
          Padding(
            padding: const EdgeInsets.all(16.0), // More padding for the fat rectangle
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // TOP ROW (Slots 0 and 1)
                Expanded(
                  child: Row(
                    children: [
                      _buildPhotoSlot(0),
                      const SizedBox(width: 12),
                      _buildPhotoSlot(1),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // BOTTOM ROW (Slots 2 and 3)
                Expanded(
                  child: Row(
                    children: [
                      _buildPhotoSlot(2),
                      const SizedBox(width: 12),
                      _buildPhotoSlot(3),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // 🏷️ THE WHITE LABEL
                GestureDetector(
                  onTap: onDateTapped, 
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), 
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown, 
                      child: Text(
                        "📍 $borough • $dateText",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 18, // Nice and bold
                          fontWeight: FontWeight.w900, 
                          letterSpacing: 1.5, 
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSlot(int index) {
    final path = photoPaths[index];
    final turns = photoRotations[index]; // Get 0-3 turns

    return Expanded(
      child: GestureDetector(
        onTap: path == null ? () => onPhotoTapped(index) : null, // If photo exists, tap image doesn't open picker
        child: Container(
          clipBehavior: Clip.antiAlias, // REQUIRED for RotatedBox to crop correctly
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 🖼️ LAYER 1: THE VISUAL PHOTO (Handling rotation & cropping)
              if (path != null)
                RotatedBox(
                  quarterTurns: turns, // Applies native cropping bounds
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover, // Ensures slot is always full, even landscape
                  ),
                ),

              // LAYER 1 (Empty State)
              if (path == null)
                const Center(
                  child: Icon(Icons.add_a_photo, color: Colors.white30, size: 36),
                ),
            
              // 🔄 LAYER 2: THE INVISIBLE SWAP OVERLAY 
              // (Moved UP so it sits behind the rotate button)
              if (path != null) 
                 Positioned.fill(
                   child: Material(
                     color: Colors.transparent,
                     child: InkWell(
                       onTap: () => onPhotoTapped(index),
                     )
                   )
                 ),

              // 🔘 LAYER 3: THE ROTATE BUTTON 
              // (Moved DOWN so it is the top-most touch target)
              if (path != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => onRotatePhoto(index), // Triggers the state update
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5), 
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white70, width: 1),
                      ),
                      child: const Icon(
                        Icons.rotate_90_degrees_ccw_outlined, 
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}