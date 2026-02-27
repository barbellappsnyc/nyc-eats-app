import 'package:flutter/material.dart';
import 'package:nyc_eats/config/cuisine_constants.dart';
import 'dart:math';

// 👈 CHANGED: Now a simple StatelessWidget!
class LanguageCollageBackground extends StatelessWidget {
  final String cuisine;
  final String currentFont; // 👈 NEW: Accepts the font from the parent screen
  const LanguageCollageBackground({super.key, required this.cuisine, required this.currentFont});

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
    final Random rnd = Random(42); 

    final List<Color> paperColors = [
      const Color(0xFFFBF8F1), const Color(0xFFF4ECD8), const Color(0xFFEFE5D0), 
      const Color(0xFFF9F6EE), const Color(0xFFF5EBE0), 
    ];

    final List<String> metaTags = [
      '(n.)', '(v.)', 'adj.', 'adv.', 'expr.', 
      '[idiom]', 'fig.', 'lit.', '1.', '2.', 'phr.'
    ];

    Widget buildDictionaryBlock(int flex) {
      final String phrase = phrases[rnd.nextInt(phrases.length)];
      final Color bgColor = paperColors[rnd.nextInt(paperColors.length)];
      final String metaTag = metaTags[rnd.nextInt(metaTags.length)];
      
      return Expanded(
        flex: flex,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: Colors.black.withOpacity(0.6), width: 0.5), 
          ),
          child: Stack(
            children: [
              Positioned(
                top: 6, left: 8,
                child: Text(
                  metaTag,
                  style: TextStyle(fontFamily: 'Times New Roman', fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black.withOpacity(0.5)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 12, left: 12, right: 12),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown, 
                    child: Text(
                      phrase,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: currentFont, // 👈 Uses the passed-in font
                        fontSize: 28, 
                        fontWeight: FontWeight.w600, 
                        color: Colors.black87,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 👈 CHANGED: Removed the Stack and Button. Just returns the pure grid!
    return Container(
      color: const Color(0xFFFDFBF7), 
      padding: const EdgeInsets.all(4.0), 
      child: SafeArea(
        top: false, bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 4, child: Column(children: [buildDictionaryBlock(3), buildDictionaryBlock(5), buildDictionaryBlock(2), buildDictionaryBlock(4), buildDictionaryBlock(3)])),
            Expanded(flex: 5, child: Column(children: [buildDictionaryBlock(4), buildDictionaryBlock(3), buildDictionaryBlock(6), buildDictionaryBlock(2), buildDictionaryBlock(4)])),
            Expanded(flex: 4, child: Column(children: [buildDictionaryBlock(2), buildDictionaryBlock(4), buildDictionaryBlock(3), buildDictionaryBlock(5), buildDictionaryBlock(2)])),
          ],
        ),
      ),
    );
  }
}