import 'package:flutter/material.dart';
import 'package:nyc_eats/config/cuisine_constants.dart';
import 'dart:math';

class LanguageCollageBackground extends StatelessWidget {
  final String cuisine;
  final String currentFont; 

  const LanguageCollageBackground({
    super.key, 
    required this.cuisine, 
    required this.currentFont,
  });

  List<String> _getPhrases() {
    final String searchTarget = cuisine.toLowerCase();
    for (var entry in CuisineConstants.nativePhrases.entries) {
      if (searchTarget.contains(entry.key) || entry.key.contains(searchTarget)) {
        return entry.value;
      }
    }
    return CuisineConstants.nativePhrases['default']!; 
  }

  @override
  Widget build(BuildContext context) {
    final List<String> phrases = _getPhrases();
    
    // We seed the randomizer with the cuisine's name. 
    // This ensures the chaos looks completely organic, but doesn't frantically 
    // reshuffle every single time the user drags the passport card.
    final Random rnd = Random(cuisine.hashCode); 

    // 🎨 The Passport Ink Palette
    final List<Color> inkColors = [
      const Color(0xFF1A2A42), // Faded Indigo / Customs Blue
      const Color(0xFF8B1A1A), // Deep Crimson / Entry Stamp Red
      const Color(0xFF1F4A2C), // Forest Green / Exit Stamp
      const Color(0xFF2B2B2B), // Charcoal / Heavy Black Ink
      const Color(0xFF6A2C70), // Faded Plum
    ];

    return Container(
      color: const Color(0xFFF4F1EA), // Textured cream passport paper
      child: LayoutBuilder(
        builder: (context, constraints) {
          final List<Widget> stamps = [];
          
          // 🖨️ Fire 45 random stamps across the canvas
          for (int i = 0; i < 45; i++) {
            final String phrase = phrases[rnd.nextInt(phrases.length)];
            final Color inkColor = inkColors[rnd.nextInt(inkColors.length)];
            
            // Randomize the aesthetic of the stamp
            final double fontSize = rnd.nextDouble() * 36 + 16; // Sizes from 16 to 52
            final double opacity = rnd.nextDouble() * 0.6 + 0.15; // Opacity from 15% (faded) to 75% (fresh)
            final double angle = (rnd.nextDouble() * 0.3) - 0.15; // Slight tilt between -8.5 and +8.5 degrees
            
            // Randomize the coordinates (allowing them to bleed off the edges of the screen)
            final double leftPos = rnd.nextDouble() * (constraints.maxWidth + 100) - 50;
            final double topPos = rnd.nextDouble() * (constraints.maxHeight + 100) - 50;

            stamps.add(
              Positioned(
                left: leftPos,
                top: topPos,
                child: Transform.rotate(
                  angle: angle,
                  child: Opacity(
                    opacity: opacity,
                    child: Text(
                      phrase,
                      style: TextStyle(
                        fontFamily: currentFont, // Keeps your aesthetic font
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900, // Heavy weight to mimic thick rubber stamps
                        color: inkColor,
                        letterSpacing: -1.0, // Tightly tracked for that physical stamp feel
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // Return the chaotic stack of text
          return Stack(
            clipBehavior: Clip.none,
            children: stamps,
          );
        },
      ),
    );
  }
}