import 'package:flutter/material.dart';
import 'dart:io'; // Needed for File checks if you use them here
import '../widgets/immigration_stamp.dart';
import '../widgets/visa_document.dart';

class PassportCard extends StatelessWidget {
  final int pageIndex;
  final String passportSku;
  final String userName;
  final List<Map<String, String>> pageStamps;
  final List<GlobalKey>? slotKeys;
  final GlobalKey? cardKey;
  final bool useKeys;
  final Color cutoutColor;

  final bool isVacant;
  final String visaTitle;
  final String? visaDate;
  final Color? visaColor;
  final VoidCallback? onNameTap;
  final VoidCallback? onAddSlotTap;

  final String? photoUrl;
  final String? gender;
  final int? age;

  // ✈️ NEW: Flying Stamp Properties
  final bool isFlying;
  final int? flyingSlotIndex;
  final String? flyingStampName;
  final String? flyingStampDate;

  // 📝 CONSTANT: The Exact Slot Positions
  static Offset getSlotCenter(int slotIndex, Size cardSize) {
    const double stripHeight = 12.0;
    const double foldHeight = 20.0;
    const double fixedVertical = stripHeight + foldHeight;

    final double availableHeight = cardSize.height - fixedVertical;
    final double bottomSectionHeight = availableHeight * (48 / 100);
    final double bottomSectionTop = cardSize.height - bottomSectionHeight;

    final double x = (slotIndex % 2 == 0)
        ? cardSize.width * 0.25
        : cardSize.width * 0.75;
    final double rowY = (slotIndex < 2)
        ? bottomSectionHeight * 0.25
        : bottomSectionHeight * 0.75;

    return Offset(x, bottomSectionTop + rowY);
  }

  const PassportCard({
    super.key,
    required this.pageIndex,
    required this.passportSku,
    required this.userName,
    required this.pageStamps,
    this.slotKeys,
    this.cardKey,
    this.useKeys = false,
    required this.cutoutColor,
    this.isVacant = false,
    this.visaTitle = "GLOBAL VISA",
    this.visaDate,
    this.visaColor,
    this.onNameTap,
    this.onAddSlotTap,
    this.photoUrl,
    this.gender,
    this.age,

    this.isFlying = false,
    this.flyingSlotIndex,
    this.flyingStampName,
    this.flyingStampDate,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = (screenWidth * 0.85).clamp(300.0, 400.0);
    final double cardHeight = cardWidth * (540 / 340);

    final bool isBooklet =
        passportSku == 'diplomat_book' || passportSku == 'standard_book';
    final bool isCover = pageIndex == 0 && isBooklet;

    if (isCover) {
      return _buildCoverView(context, cardWidth, cardHeight);
    }

    final List<Color> stripColors = [
      Colors.blueAccent,
      Colors.redAccent,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    Color finalStripColor =
        visaColor ?? stripColors[pageIndex % stripColors.length];
    final double contentOpacity = isVacant ? 0.65 : 1.0;
    // 🛠 FIX: FORCE BLANK VIEW FOR NEW SINGLE PAGES
    // Even if the logic says it's "assigned", we don't want to show the Global Visa artwork.
    // We only show the Visa artwork if it has a specific cuisine (not "GLOBAL VISA").
    bool isSovereignPage = !isVacant;
    if (passportSku == 'single_page' && visaTitle == "GLOBAL VISA") {
      isSovereignPage = false;
    }

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          // 1. 🏗️ ROOT STACK: Allows elements to float OUTSIDE the card bounds
          child: Stack(
            clipBehavior: Clip.none, // 🔓 Allow overflow for the 5x zoom
            children: [
              // 2. 📦 THE PHYSICAL CARD (Clipped Content)
              Container(
                key: useKeys ? cardKey : null,
                clipBehavior:
                    Clip.antiAlias, // Keep corners rounded for the card itself
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      spreadRadius: -10,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Strip
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: finalStripColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                    ),

                    // Main Content
                    Expanded(
                      flex: 52,
                      child: isSovereignPage
                          ? _buildSovereignVisaView(finalStripColor)
                          : _buildGlobalOrVacantView(
                              contentOpacity,
                              finalStripColor,
                            ),
                    ),

                    // Fold Line
                    SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 10,
                            height: 20,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: cutoutColor,
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Flex(
                                  direction: Axis.horizontal,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  mainAxisSize: MainAxisSize.max,
                                  children: List.generate(
                                    (constraints.constrainWidth() / 10).floor(),
                                    (index) => const SizedBox(
                                      width: 5,
                                      height: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.black12,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: 10,
                            height: 20,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: cutoutColor,
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stamp Slots (Static)
                    Expanded(
                      flex: 48,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              for (int i = 0; i < 4; i++)
                                _buildExactPosSlot(
                                  i,
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                  isVacant,
                                ),

                              for (int i = 0; i < pageStamps.length; i++)
                                if (i < 4)
                                  _buildExactPosStamp(
                                    i,
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                    pageStamps[i],
                                  ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 3. ✈️ THE FLYING STAMP (Floating Above Everything)
              // We perform the layout math relative to the card size here
              if (isFlying && flyingSlotIndex != null)
                _buildFlyingStamp(flyingSlotIndex!, cardWidth, cardHeight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExactPosSlot(int index, double w, double h, bool vacant) {
    final double x = (index % 2 == 0) ? w * 0.25 : w * 0.75;
    final double y = (index < 2) ? h * 0.25 : h * 0.75;

    final double boxW = w * 0.4;
    final double boxH = h * 0.4;

    return Positioned(
      left: x - (boxW / 2),
      top: y - (boxH / 2),
      width: boxW,
      height: boxH,
      child: GestureDetector(
        onTap: onAddSlotTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          key: (slotKeys != null && index < slotKeys!.length)
              ? slotKeys![index]
              : null,
          decoration: BoxDecoration(
            border: Border.all(
              color: vacant
                  ? Colors.black.withOpacity(0.04)
                  : Colors.black.withOpacity(0.06),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              Icons.add,
              color: vacant
                  ? Colors.transparent
                  : Colors.black.withOpacity(0.05),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExactPosStamp(
    int index,
    double w,
    double h,
    Map<String, String> data,
  ) {
    final double x = (index % 2 == 0) ? w * 0.25 : w * 0.75;
    final double y = (index < 2) ? h * 0.25 : h * 0.75;

    const double stampWidth = 140.0;
    const double stampHeight = 90.0;

    return Positioned(
      left: x - (stampWidth / 2),
      top: y - (stampHeight / 2),
      width: stampWidth,
      height: stampHeight,
      child: Transform.rotate(
        angle: (index % 2 == 0) ? -0.1 : 0.1,
        child: FittedBox(
          fit: BoxFit.contain,
          child: ImmigrationStamp(
            restaurant: data['name'] ?? 'Unknown',
            date: data['date'] ?? 'Unknown',
          ),
        ),
      ),
    );
  }

  Widget _buildCoverView(BuildContext context, double width, double height) {
    // 🎨 DYNAMIC THEME ENGINE
    final Color baseColor;
    final Color highlightColor;

    if (passportSku == 'diplomat_book') {
      baseColor = const Color(0xFF041022);
      highlightColor = const Color(0xFF162538);
    } else {
      // Imperial Burgundy
      baseColor = const Color(0xFF3B0918); // Deep Oxblood
      highlightColor = const Color(0xFF5C1026); // Rich Burgundy
    }

    return Material(
      color: baseColor,
      elevation: 15,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        key: useKeys ? cardKey : null,
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(12),
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.0,
            colors: [highlightColor, baseColor],
            stops: const [0.0, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 20,
              offset: const Offset(4, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 30,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 40.0,
                horizontal: 20.0,
              ),
              child: SizedBox.expand(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _FoilEffect(
                      child: Text(
                        "PASSPORT",
                        style: TextStyle(
                          fontFamily: 'Times New Roman',
                          fontWeight: FontWeight.w700,
                          fontSize: 36,
                          letterSpacing: 4,
                        ),
                      ),
                    ),

                    _FoilEffect(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(width: 3, color: Colors.white),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.public,
                            size: 90,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    Column(
                      children: [
                        _FoilEffect(
                          child: Column(
                            children: [
                              Text(
                                "COLLECTION",
                                style: TextStyle(
                                  fontFamily: 'Times New Roman',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  letterSpacing: 3.0,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                passportSku == 'diplomat_book'
                                    ? "DIPLOMATIC"
                                    : "STANDARD",
                                style: TextStyle(
                                  fontFamily: 'Times New Roman',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        _FoilEffect(
                          child: Container(
                            width: 34,
                            height: 22,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSovereignVisaView(Color mainColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Theme(
        data: ThemeData.light(),
        child: VisaDocument(
          // 🛠 FIX: logic was forcing Page 0 to be "Global".
          // We must allow Single Page passports to show their specific cuisine on Page 0.
          cuisine: (pageIndex == 0 && passportSku != 'single_page')
              ? "Global"
              : visaTitle.replaceAll('OFFICIAL ', '').replaceAll(' VISA', ''),

          userName: userName,
          dateIssued: visaDate ?? "EST. 2026",
          mainColor: (pageIndex == 0 && passportSku != 'single_page')
              ? const Color(0xFF1A237E)
              : mainColor,
          photoUrl: photoUrl ?? "",
          gender: gender,
          age: age,
        ),
      ),
    );
  }

  Widget _buildGlobalOrVacantView(double opacity, Color stripColor) {
    final bool isBooklet =
        passportSku == 'diplomat_book' || passportSku == 'standard_book';
    final int displayNum = isBooklet ? pageIndex : pageIndex + 1;

    // 🛠 FIX: Determine the correct label
    // If we forced it to be blank (Single Page), show "SINGLE ENTRY"
    String displayTitle = isVacant ? "BLANK PAGE" : visaTitle;
    if (passportSku == 'single_page' && visaTitle == "GLOBAL VISA") {
      displayTitle = "SINGLE ENTRY";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Opacity(
        opacity: opacity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.public, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      displayTitle, // 👈 Uses our new logic
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                Text(
                  "00$displayNum",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Text(
              "TRAVELER",
              style: TextStyle(
                fontSize: 10,
                color: Colors.black38,
                fontWeight: FontWeight.bold,
              ),
            ),

            GestureDetector(
              onTap: onNameTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Courier',
                          letterSpacing: -1,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  if (useKeys)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(
                        Icons.edit,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            if (!isVacant ||
                passportSku == 'single_page') // Show label for single page too
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  passportSku == 'single_page'
                      ? "ONE-TIME PASS"
                      : (passportSku == 'free_tier'
                            ? "TOURIST STATUS"
                            : "CITIZEN OF THE WORLD"),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlyingStamp(int index, double cardW, double cardH) {
    const double stripHeight = 12.0;
    const double foldHeight = 20.0;
    final double availableH = cardH - stripHeight - foldHeight;
    final double topSectionH = availableH * 0.52;
    final double bottomSectionH = availableH * 0.48;
    final double offsetY = stripHeight + topSectionH + foldHeight;

    final double relX = (index % 2 == 0) ? cardW * 0.25 : cardW * 0.75;
    final double relY = (index < 2)
        ? bottomSectionH * 0.25
        : bottomSectionH * 0.75;

    const double stampWidth = 140.0;
    const double stampHeight = 90.0;

    final double finalX = relX - (stampWidth / 2);
    final double finalY = offsetY + relY - (stampHeight / 2);

    final double targetRotation = (index % 2 == 0) ? -0.1 : 0.1;
    final double startRotation = targetRotation * 3.0;

    return Positioned(
      left: finalX,
      top: finalY,
      width: stampWidth,
      height: stampHeight,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.linear,
        builder: (context, value, child) {
          double scale;
          double rotation;
          double opacity;

          const double impactTime = 0.6;

          if (value < impactTime) {
            final t = Curves.easeInQuint.transform(value / impactTime);
            scale = 5.0 - (4.2 * t);
            rotation = startRotation + ((targetRotation - startRotation) * t);
            opacity = (t * 5).clamp(0.0, 1.0);
          } else {
            final t = Curves.elasticOut.transform(
              (value - impactTime) / (1 - impactTime),
            );
            scale = 0.8 + (0.2 * t);
            rotation = targetRotation;
            opacity = 1.0;
          }

          return Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotation,
              child: Opacity(
                opacity: opacity,
                child: ImmigrationStamp(
                  restaurant: flyingStampName ?? "",
                  date: flyingStampDate ?? "",
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FoilEffect extends StatelessWidget {
  final Widget child;
  const _FoilEffect({required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE6C685),
            Color(0xFFD4AF37),
            Color(0xFFC5A028),
            Color(0xFFE6C685),
          ],
          stops: [0.1, 0.4, 0.7, 0.9],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
