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
      if (searchTarget.contains(entry.key) ||
          entry.key.contains(searchTarget)) {
        return entry.value;
      }
    }
    return CuisineConstants.nativePhrases['default']!;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> phrases = _getPhrases();
    // Seeds the layout so it stays perfectly still while you drag the passport
    final Random rnd = Random(cuisine.hashCode);

    return Container(
      color: const Color(0xFF1C1C1E), // Dark, gritty tabletop background
      child: LayoutBuilder(
        builder: (context, constraints) {
          final List<Widget> strips = [];

          // Throw 18 strips of paper onto the table
          for (int i = 0; i < 18; i++) {
            final String phrase = phrases[rnd.nextInt(phrases.length)];

            // Randomize the physical placement and rotation
            final double angle = (rnd.nextDouble() * 0.6) - 0.3;
            final double topPos =
                rnd.nextDouble() * (constraints.maxHeight + 100) - 50;
            final double leftPos =
                rnd.nextDouble() * (constraints.maxWidth + 100) - 50;
            final double fontSize =
                rnd.nextDouble() * 14 + 22; // Sizes from 22 to 36

            strips.add(
              Positioned(
                top: topPos,
                left: leftPos,
                child: Transform.rotate(
                  angle: angle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFFDFBF7,
                      ), // Warm receipt paper color
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 10,
                          offset: const Offset(
                            5,
                            5,
                          ), // Harsh, high-contrast drop shadow
                        ),
                      ],
                      // Ripped paper effect via slightly uneven borders
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(rnd.nextDouble() * 3),
                        bottomRight: Radius.circular(rnd.nextDouble() * 5),
                      ),
                    ),
                    child: Text(
                      phrase,
                      style: TextStyle(
                        fontFamily:
                            currentFont, // 👈 Hooked directly to your Aa button
                        fontSize: fontSize,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(clipBehavior: Clip.none, children: strips);
        },
      ),
    );
  }
}
