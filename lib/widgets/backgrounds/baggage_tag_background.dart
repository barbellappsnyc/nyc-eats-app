import 'dart:math';
import 'package:flutter/material.dart';
// Note: Adjust this import path to wherever your CuisineConstants is located!
import 'package:nyc_eats/config/cuisine_constants.dart';

class BaggageTagBackground extends StatefulWidget {
  final String cuisine;
  final List<dynamic> stamps;

  const BaggageTagBackground({
    super.key,
    required this.cuisine,
    required this.stamps,
  });

  @override
  State<BaggageTagBackground> createState() => _BaggageTagBackgroundState();
}

class _BaggageTagBackgroundState extends State<BaggageTagBackground> {
  late List<DateTime> _validDates;

  @override
  void initState() {
    super.initState();
    _extractDates();
  }

  @override
  void didUpdateWidget(covariant BaggageTagBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cuisine != widget.cuisine ||
        oldWidget.stamps.length != widget.stamps.length) {
      setState(() {
        _extractDates();
      });
    }
  }

  void _extractDates() {
    _validDates = [];
    for (var stamp in widget.stamps) {
      try {
        if (stamp is Map) {
          if (stamp['stamped_at'] != null) {
            _validDates.add(DateTime.parse(stamp['stamped_at'].toString()));
          }
        } else {
          _validDates.add(DateTime.parse(stamp.stamped_at.toString()));
        }
      } catch (e) {
        debugPrint("🚨 DATE EXTRACTION FAILED FOR STAMP: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String cleanCuisine = widget.cuisine.toLowerCase();
    final List<String> destinations =
        CuisineConstants.airportCodes[cleanCuisine] ??
        CuisineConstants.airportCodes['default']!;

    return Container(
      color: const Color(0xFFD6D2C4),
      padding: EdgeInsets.zero,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.45,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
        ),
        itemCount: 20,
        itemBuilder: (context, index) {
          DateTime tagDate = _validDates.isNotEmpty
              ? _validDates[index % _validDates.length]
              : DateTime.now();

          const List<String> months = [
            'JAN',
            'FEB',
            'MAR',
            'APR',
            'MAY',
            'JUN',
            'JUL',
            'AUG',
            'SEP',
            'OCT',
            'NOV',
            'DEC',
          ];
          String formattedDate =
              "${tagDate.day.toString().padLeft(2, '0')} ${months[tagDate.month - 1]} ${tagDate.hour.toString().padLeft(2, '0')}:${tagDate.minute.toString().padLeft(2, '0')}";

          final String destination = destinations[index % destinations.length];

          // 🛑 THE JFK OVERRIDE LOGIC
          String origin = 'JFK'; // Default origin is always JFK

          // If the destination is a major NYC hub (like American/Deli food), we switch the origin so it's not JFK -> JFK
          if (destination == 'JFK' ||
              destination == 'EWR' ||
              destination == 'LGA') {
            origin = ['LAX', 'SFO', 'ORD'][index % 3];
          }

          final String flightNumber = "NX-${100 + (index * 12)}";

          // Pulling the bilingual city name
          final String cityName =
              CuisineConstants.airportCityNames[destination] ?? '';

          String barcode = "";
          for (int b = 0; b < 25; b++) {
            barcode += (b % 2 == 0) ? "|" : ((b % 3 == 0) ? " " : "||");
          }

          return FittedBox(
            fit: BoxFit.contain,
            child: SingleBaggageTag(
              origin: origin,
              destination: destination,
              flightNumber: flightNumber,
              dateStr: formattedDate,
              barcode: barcode,
              cityName: cityName, // 👈 Passing it to the tag
              isFaded: false,
            ),
          );
        },
      ),
    );
  }
}

class SingleBaggageTag extends StatelessWidget {
  final String origin;
  final String destination;
  final String flightNumber;
  final String dateStr;
  final String barcode;
  final String cityName; // 👈 New property
  final bool isFaded;

  const SingleBaggageTag({
    super.key,
    required this.origin,
    required this.destination,
    required this.flightNumber,
    required this.dateStr,
    required this.barcode,
    required this.cityName,
    this.isFaded = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> cityParts = cityName.split(' / ');
    final String nativeName = cityParts.length > 1 ? cityParts[0] : '';
    final String englishName = cityParts.length > 1
        ? cityParts[1]
        : cityParts[0];

    // =========================================================
    // 🧪 FONT TESTING ZONE (Uncomment one, hit Hot Reload)
    // =========================================================

    // 1. The Ultra-Premium Apple Japanese Standard
    const String testFont = 'Hiragino Kaku Gothic ProN';

    // 2. The Airy, Elegant Japanese Classic
    // const String testFont = 'YuGothic';

    // 3. Apple's Modern System Default (San Francisco)
    // const String testFont = '.SF Pro Display';

    // 4. The Pre-2015 Apple Standard
    // const String testFont = 'Helvetica Neue';

    // 5. The Classic Editorial Serif (If you want to compare it to the modern sans-serifs)
    // const String testFont = 'Didot';

    // ---------------------------------------------------------
    // The Master Style Variable
    // ---------------------------------------------------------
    final TextStyle premiumCityStyle = TextStyle(
      fontFamily: testFont,
      fontSize: 11,
      fontWeight:
          FontWeight.w600, // Drop to w500 if the Katakana looks too thick
      color: Colors.black45,
      letterSpacing: 2.5,
    );

    // NOTE: If you are using the google_fonts package, comment out the `premiumCityStyle` above and uncomment this instead:
    // final TextStyle premiumCityStyle = GoogleFonts.notoSansJp(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black45, letterSpacing: 2.5);

    return Container(
      width: 140,
      height: 320,
      // ... (rest of your container code)
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EA),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isFaded ? 0.05 : 0.15),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Opacity(
        opacity: isFaded ? 0.4 : 0.95,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Color Strip
            Container(
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFC83A3A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),

            // Flight & Date Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "FLT: $flightNumber",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(
              flex: 3,
            ), // 👈 Increased flex pushes the block lower down the tag
            // 🏙️ Native City Name (First Line)
            if (nativeName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    nativeName.toUpperCase(),
                    style: premiumCityStyle, // 👈 JUST DROP THIS HERE
                    textAlign: TextAlign.left,
                  ),
                ),
              ),

            // 🏙️ English City Name (Second Line)
            if (englishName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    englishName.toUpperCase(),
                    style: premiumCityStyle, // 👈 AND HERE
                    textAlign: TextAlign.left,
                  ),
                ),
              ),

            // Massive Destination Code (Anchored Left, Auto-Scaling)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  destination,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -2,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),

            // Routing (Anchored Left, Auto-Scaling)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  "$origin -> $destination",
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),

            const Spacer(
              flex: 2,
            ), // 👈 Smaller flex keeps it nested closer to the barcode
            // Vertical Barcode
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FittedBox(
                fit: BoxFit.fill,
                child: Text(
                  barcode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
