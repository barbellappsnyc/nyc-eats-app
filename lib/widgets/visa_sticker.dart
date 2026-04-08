import 'package:flutter/material.dart';

class VisaSticker extends StatelessWidget {
  final String cuisine;
  final String dateIssued;
  final Color mainColor;

  const VisaSticker({
    super.key,
    required this.cuisine,
    required this.dateIssued,
    required this.mainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 80,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: mainColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: mainColor.withOpacity(0.3), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Watermark
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              Icons.public,
              size: 80,
              color: mainColor.withOpacity(0.05),
            ),
          ),

          // 2. Security Pattern (Dots)
          Positioned(
            top: 5,
            left: 5,
            right: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                30,
                (index) => Container(
                  width: 2,
                  height: 2,
                  color: mainColor.withOpacity(0.5),
                ),
              ),
            ),
          ),

          // 3. Content
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ), // Reduced vertical padding
            child: Row(
              children: [
                // Seal
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: mainColor, width: 2),
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Icon(Icons.verified, color: mainColor, size: 28),
                  ),
                ),
                const SizedBox(width: 15),

                // 🚀 FIX: Use Flexible inside a compact column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min, // 🚀 Keep it compact
                    children: [
                      Text(
                        "OFFICIAL VISA",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                          color: mainColor.withOpacity(0.7),
                        ),
                      ),
                      // 🚀 FIX: Allow this text to shrink if needed
                      Flexible(
                        child: Text(
                          cuisine.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Courier',
                            color: Colors.black87,
                            height: 1.1, // Slightly tighter line height
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Date
                RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    "ISSUED $dateIssued",
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: mainColor.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
