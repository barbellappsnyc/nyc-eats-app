import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nyc_eats/config/cuisine_constants.dart';
// Note: Ensure your CuisineConstants are imported here

class PillCache {
  static final Map<String, ({int width, int height, Uint8List data})>
  _memoryCache = {};

  // =========================================================================
  // ⚡ THE JIT GENERATOR (Only draws what is actually on screen)
  // =========================================================================
  static Future<({int width, int height, Uint8List data})> getOrGeneratePill(
    String id,
    String cuisine,
    String ringType,
    int stars,
    bool isDarkMode,
  ) async {
    // 🌟 FIX 1: Make the cache key aware of the theme so it doesn't load old colors!
    final String cacheKey = "${id}_$isDarkMode";

    // 1. If we already drew it recently, return it instantly
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    // 2. Otherwise, set up the colors based on the requested ID
    String emoji = CuisineConstants.emojiPalettes[cuisine]?.first ?? "🍽️";

    Color ringColor;
    if (ringType == "gold")
      ringColor = const Color(0xFFFFD700);
    else if (ringType == "red")
      ringColor = const Color(0xFFE53935);
    else
      ringColor = isDarkMode
          ? const Color(0xFF555555)
          : const Color(0xFF000000);

    // 🌟 FIX 2: INVERTED FILL COLORS
    // Dark Mode = White (0xFFFFFFFF), Light Mode = Matte Black (0xFF1E1E1E)
    Color fill = isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF1E1E1E);

    // 3. Draw it natively
    final data = await _drawPill(emoji, stars, ringColor, fill);

    // 4. Save it so we never have to draw it again
    _memoryCache[cacheKey] = data;
    return data;
  }

  // =========================================================================
  // 🎨 THE NATIVE CANVAS PAINTER
  // =========================================================================
  static Future<({int width, int height, Uint8List data})> _drawPill(
    String emoji,
    int stars,
    Color ringColor,
    Color fillColor,
  ) async {
    final double height = 68.0;
    final double width = stars > 0 ? 140.0 : 68.0;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final RRect outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(height / 2),
    );
    canvas.drawRRect(
      outerRect,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.fill,
    );

    final double strokeWidth = 6.0;
    final RRect innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth,
        strokeWidth,
        width - (strokeWidth * 2),
        height - (strokeWidth * 2),
      ),
      Radius.circular((height - (strokeWidth * 2)) / 2),
    );
    canvas.drawRRect(
      innerRect,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    final bool useDarkText = fillColor.computeLuminance() < 0.5;

    final TextSpan span = TextSpan(
      children: [
        TextSpan(
          text: emoji,
          style: const TextStyle(fontSize: 32, fontFamily: 'Apple Color Emoji'),
        ),
        if (stars > 0) const TextSpan(text: "   "),
        if (stars > 0)
          TextSpan(
            text: "$stars",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: useDarkText ? Colors.white : Colors.black,
            ),
          ),
        if (stars > 0)
          const TextSpan(
            text: "★",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
      ],
    );

    final TextPainter tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: width);

    final Offset textOffset = Offset(
      (width - tp.width) / 2,
      (height - tp.height) / 2,
    );
    tp.paint(canvas, textOffset);

    // pill_cache.dart

    // ... inside _drawPill function ...
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );

    // ✅ MUST BE PNG for Mapbox's native side to understand it
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return (
      width: width.toInt(),
      height: height.toInt(),
      data: byteData!.buffer.asUint8List(),
    );
  }
}
