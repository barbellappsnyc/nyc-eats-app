import 'package:flutter/material.dart';
import 'package:nyc_eats/config/cuisine_constants.dart';

class WarholBackground extends StatelessWidget {
  final String cuisine;

  const WarholBackground({super.key, required this.cuisine});

  @override
  Widget build(BuildContext context) {
    final String safeCuisine = cuisine.toLowerCase().trim();
    final List<String> emojis =
        CuisineConstants.emojiPalettes[safeCuisine] ??
        CuisineConstants.emojiPalettes['default']!;

    final String targetEmoji = emojis.isNotEmpty ? emojis[0] : '🍽️';

    // 2. The True Marilyn Diptych Palettes
    final List<Map<String, Color>> palettes = [
      {
        'bg': const Color(0xFFE32462),
        'tint': const Color(0xFFFFD700),
      }, // Top L: Crimson / Gold
      {
        'bg': const Color(0xFF93C6D6),
        'tint': const Color(0xFFFF69B4),
      }, // Top M: Dusty Blue / Hot Pink
      {
        'bg': const Color(0xFFD58145),
        'tint': const Color(0xFF98FF98),
      }, // Top R: Burnt Orange / Mint
      {
        'bg': const Color(0xFFDE6725),
        'tint': const Color(0xFF87CEFA),
      }, // Bot L: Bright Orange / Sky Blue
      {
        'bg': const Color(0xFF0D7A84),
        'tint': const Color(0xFFFF00FF),
      }, // Bot M: Deep Teal / Magenta
      {
        'bg': const Color(0xFFD81682),
        'tint': const Color(0xFFBFFF00),
      }, // Bot R: Hot Pink / Lime
    ];

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildPanel(
                  palettes[0]['bg']!,
                  palettes[0]['tint']!,
                  targetEmoji,
                ),
              ),
              Expanded(
                child: _buildPanel(
                  palettes[1]['bg']!,
                  palettes[1]['tint']!,
                  targetEmoji,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildPanel(
                  palettes[2]['bg']!,
                  palettes[2]['tint']!,
                  targetEmoji,
                ),
              ),
              Expanded(
                child: _buildPanel(
                  palettes[3]['bg']!,
                  palettes[3]['tint']!,
                  targetEmoji,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildPanel(
                  palettes[4]['bg']!,
                  palettes[4]['tint']!,
                  targetEmoji,
                ),
              ),
              Expanded(
                child: _buildPanel(
                  palettes[5]['bg']!,
                  palettes[5]['tint']!,
                  targetEmoji,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(Color bgColor, Color tintColor, String emoji) {
    return Container(
      color: bgColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double boxWidth = constraints.maxWidth;
          final double padding = boxWidth * 0.20; // Keeping your safe padding

          return Padding(
            padding: EdgeInsets.all(padding),
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Transform.translate(
                  offset: const Offset(
                    0,
                    -100,
                  ), // Keeping your optical center nudge
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // 🌑 LAYER 1: The Heavy Ink Shadow
                      // Increased and made slightly uneven (70, 90) for a sloppy print feel
                      Transform.translate(
                        offset: const Offset(70, 90),
                        child: ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.black87, Colors.black87],
                          ).createShader(bounds),
                          child: Text(
                            emoji,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 1000,
                              height: 1.0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),

                      // 💥 LAYER 2: The "Primer Bleed" (NEW)
                      // Shifts up and left to create that misregistered color-spill glitch
                      Transform.translate(
                        offset: const Offset(-40, -25),
                        child: ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (bounds) => LinearGradient(
                            // Opacity lets it blend slightly with the background
                            colors: [
                              tintColor.withOpacity(0.85),
                              tintColor.withOpacity(0.85),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            emoji,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 1000,
                              height: 1.0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),

                      // 🌈 LAYER 3: The Main Modulated Subject
                      ShaderMask(
                        blendMode: BlendMode.modulate,
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [tintColor, tintColor],
                        ).createShader(bounds),
                        child: Text(
                          emoji,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 1000,
                            height: 1.0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
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
