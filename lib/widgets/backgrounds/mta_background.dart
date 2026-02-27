import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:flutter/scheduler.dart'; // 👈 Add this to the top of the file
import 'dart:math';

class MtaBackground extends StatefulWidget {
  final List<Map<String, dynamic>> stations;
  final bool isDarkMode; 
  final Offset passportPosition; 
  final double passportScale;
  final bool isDragging; // 👈 NEW

  const MtaBackground({
    Key? key, 
    required this.stations,
    this.isDarkMode = true, 
    this.passportPosition = Offset.zero, 
    this.passportScale = 0.85,    
    this.isDragging = false, // 👈 NEW       
  }) : super(key: key);

  @override
  State<MtaBackground> createState() => _MtaBackgroundState();
}

// 👇 REMOVED: with SingleTickerProviderStateMixin
class _MtaBackgroundState extends State<MtaBackground> {
  
  List<BlobNode> _blobs = [];
  bool _isInitialized = false;
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    // 🛑 REMOVED: The Ticker that was running the physics loop
  }

  @override
  void dispose() {
    // 🛑 REMOVED: Ticker disposal
    super.dispose();
  }

  // 🛑 REMOVED: The entire _tick(Duration elapsed) function with the math

  void _initializeBlobsIfNeed(double width, double height) {
    // 🛠️ STEP 2 FIX: Also check if the number of stations has changed!
    // If a new station arrives from the DB, this forces the blobs to recalculate.
    if (_isInitialized && _screenSize.width == width && _blobs.length == widget.stations.length) return;
    _screenSize = Size(width, height);
    _blobs.clear();
    
    int count = widget.stations.length;
    double bW, bH;
    
    // 📏 SHAPE & HOME LOGIC
    // 📏 SHAPE & HOME LOGIC
    if (count == 1 || count == 2) {
      bW = width * 0.90; 
      bH = height * 0.12; 
      
      // 🚀 THE EXTREMES: Push Top up to the absolute SafeArea, push Bottom to the floor
      double topY = height * 0.05; 
      double bottomY = height * 0.95 - bH; 
      
      _blobs.add(BlobNode(x: (width - bW) / 2, y: topY, width: bW, height: bH)); // Top
      if (count == 2) {
        _blobs.add(BlobNode(x: (width - bW) / 2, y: bottomY, width: bW, height: bH)); // Bottom
      }
    } else if (count == 3) {
      bW = width * 0.28; bH = height * 0.18;
      double spacing = (width - (bW * 3)) / 4;
      for (int i = 0; i < 3; i++) _blobs.add(BlobNode(x: spacing + (i * (bW + spacing)), y: height * 0.1, width: bW, height: bH));
    } else {
      bW = width * 0.40; bH = height * 0.20;
      _blobs.add(BlobNode(x: width * 0.05, y: height * 0.05, width: bW, height: bH)); // Top L
      _blobs.add(BlobNode(x: width - bW - (width * 0.05), y: height * 0.05, width: bW, height: bH)); // Top R
      _blobs.add(BlobNode(x: width * 0.05, y: height - bH - (height * 0.05), width: bW, height: bH)); // Bot L
      _blobs.add(BlobNode(x: width - bW - (width * 0.05), y: height - bH - (height * 0.05), width: bW, height: bH)); // Bot R
    }
    _isInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stations.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        _initializeBlobsIfNeed(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. THE BLUEPRINT BACKGROUND
            Image.asset(
              'assets/images/subway_blueprint.png', 
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.4), 
              colorBlendMode: BlendMode.darken,
            ),
            
            // 🏟️ THE PHYSICS PLAYPEN
            Stack(
              children: List.generate(_blobs.length, (index) {
                final blob = _blobs[index];
                
                // 🎯 THE SCALABILITY FIX: Mirror the clamp from the detail screen!
                final double baseCardW = (constraints.maxWidth * 0.85).clamp(300.0, 400.0);
                final double cardW = baseCardW * widget.passportScale;
                final double cardH = cardW * (540 / 340);
                
                // Hitbox is slightly smaller (0.75) so it feels fair
                final Rect cardHitbox = Rect.fromCenter(
                  center: widget.passportPosition, 
                  width: cardW * 0.75, 
                  height: cardH * 0.75,
                );
                
                // The Blob's Hitbox
                final Rect blobRect = Rect.fromLTWH(blob.x, blob.y, blob.width, blob.height);
                
                // Does the card overlap this specific blob?
                final bool isOverlapped = cardHitbox.overlaps(blobRect);

                return Positioned(
                  left: blob.x,
                  top: blob.y,
                  // 🎬 INDIVIDUAL DEPTH FADE
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    opacity: isOverlapped ? 0.3 : 1.0, // 👈 ONLY fades if overlapped!
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: isOverlapped ? 8.0 : 0.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      builder: (context, blurValue, child) {
                        return ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                          child: child,
                        );
                      },
                      child: _buildStationCard(widget.stations[index], blob.width, blob.height, widget.stations.length),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station, double cardWidth, double cardHeight, int totalStations) {
    final String stationName = station['station_name'] ?? 'Unknown Station';
    final String linesString = station['lines'] ?? '';
    final String borough = station['borough'] ?? '';
    
    final List<String> lines = linesString.isNotEmpty 
        ? linesString.trim().split(RegExp(r'\s+')).where((l) => l.isNotEmpty).toList()
        : [];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      width: cardWidth,  
      height: cardHeight,
      margin: const EdgeInsets.all(8.0), 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.0), 
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.3), 
            blurRadius: widget.isDarkMode ? 24 : 30,
            spreadRadius: widget.isDarkMode ? 0 : 2,
            offset: Offset(0, widget.isDarkMode ? 10 : 15),
          ),
        ],
      ),
      // 🛠 THE FIX: We restored the child and Stack wrappers here!
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 🌙 BASE LAYER: Night Card
              _buildLayoutRouter(stationName, lines, borough, totalStations, isDark: true),

              // ☀️ TOP LAYER: Day Card
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                opacity: widget.isDarkMode ? 0.0 : 1.0,
                child: _buildLayoutRouter(stationName, lines, borough, totalStations, isDark: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔀 THE ROUTER: Decides between LTR (1-2) or Centered (3-4)
  Widget _buildLayoutRouter(String name, List<String> lines, String borough, int totalStations, {required bool isDark}) {
    if (totalStations <= 2) {
      return _buildLTRContent(name, lines, borough, isDark: isDark);
    } else {
      // This is your existing centered code! Just rename your old `_buildCardContent` to `_buildCenteredContent`
      return _buildCenteredContent(name, lines, borough, isDark: isDark); 
    }
  }

  Widget _buildLTRContent(String stationName, List<String> lines, String borough, {required bool isDark}) {
    // Keep your existing glassGradient logic here...
    List<Color> glassGradient = isDark 
        ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.02)]
        : [Colors.white, Colors.white.withOpacity(0.95)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: glassGradient),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.15) : Colors.white, width: 2.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🔣 LEFT ANCHOR: The Line Grid
          SizedBox(
            width: 80, // Fixed width block for the icons
            child: _buildDynamicLineGrid(lines, isDark),
          ),
          
          const SizedBox(width: 16), // Padding between icons and text
          
          // 📝 RIGHT ANCHOR: The Typography
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "NYC TRANSIT",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isDark ? FontWeight.w800 : FontWeight.w900,
                    letterSpacing: 2.0,
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontFamily: 'Helvetica',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stationName,
                  maxLines: 2, // 👈 THE FIX: Allows long names to wrap cleanly
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: 20, // 👈 Slightly smaller to ensure elegance
                    fontWeight: isDark ? FontWeight.w700 : FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.1,
                    fontFamily: 'Helvetica',
                  ),
                ),
                if (borough.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: isDark ? Colors.white54 : Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        borough.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontFamily: 'Helvetica',
                        ),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🧮 THE SMART ICON MATH
  Widget _buildDynamicLineGrid(List<String> lines, bool isDark) {
    if (lines.isEmpty) return const SizedBox();

    if (lines.length == 1) {
      // 👈 SHRUNK: From 70 to 56 to fit the slimmer height
      return _buildLineCircle(lines[0], 56, 26, isDark); 
    } 
    
    if (lines.length == 2) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // 👈 SHRUNK: From 36 to 30
          _buildLineCircle(lines[0], 30, 14, isDark),
          const SizedBox(width: 4),
          _buildLineCircle(lines[1], 30, 14, isDark),
        ],
      );
    }

    // 3 OR MORE: 2x2 Grid 
    List<Widget> gridItems = [];
    for (int i = 0; i < 4; i++) {
      if (i < 3 && i < lines.length) {
        gridItems.add(_buildLineCircle(lines[i], 30, 14, isDark));
      } else if (i == 3 && lines.length > 4) {
        gridItems.add(_buildLineCircle("+${lines.length - 3}", 30, 12, isDark, isOverflow: true));
      } else if (i < lines.length) {
        gridItems.add(_buildLineCircle(lines[i], 30, 14, isDark));
      } else {
        gridItems.add(const SizedBox(width: 30, height: 30)); 
      }
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: gridItems,
    );
  }

  Widget _buildLineCircle(String text, double size, double fontSize, bool isDark, {bool isOverflow = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOverflow ? (isDark ? Colors.grey[800] : Colors.grey[300]) : _getLineColor(text),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: isOverflow ? (isDark ? Colors.white : Colors.black) : _getTextColor(text),
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'Helvetica',
          ),
        ),
      ),
    );
  }

  Widget _buildCenteredContent(String stationName, List<String> lines, String borough, {required bool isDark}) {
    final List<Color> stationColors = lines.map((l) => _getLineColor(l)).toSet().toList();
    List<Color> glassGradient;
    List<double> glassStops;

    if (isDark) {
      if (stationColors.isEmpty) {
        glassGradient = [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.02)];
        glassStops = [0.0, 1.0];
      } else if (stationColors.length == 1) {
        glassGradient = [stationColors.first.withOpacity(0.35), Colors.white.withOpacity(0.02)];
        glassStops = [0.0, 0.8];
      } else {
        glassGradient = [
          stationColors.first.withOpacity(0.35), 
          stationColors[1].withOpacity(0.20),
          Colors.white.withOpacity(0.02)
        ];
        glassStops = [0.0, 0.4, 1.0];
      }
    } else {
      glassGradient = [Colors.white, Colors.white.withOpacity(0.95)];
      glassStops = [0.0, 1.0];
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isDark ? Alignment.bottomRight : Alignment.topLeft,
          end: isDark ? Alignment.topLeft : Alignment.bottomRight,
          colors: glassGradient,
          stops: glassStops,
        ),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.15) : Colors.white, 
          width: isDark ? 1.5 : 2.0,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double cardWidth = constraints.maxWidth;
          final bool isSmall = cardWidth < 160; 
          
          final double circleSize = isSmall ? 24.0 : 32.0;
          final double circleText = isSmall ? 13.0 : 16.0;
          final double titleSize = isSmall ? 18.0 : 22.0;
          final double boroughSize = isSmall ? 10.0 : 12.0;

          return Stack(
            children: [
              Positioned(
                right: -25,
                bottom: -25,
                child: Icon(
                  Icons.directions_subway_filled,
                  size: isSmall ? 100 : 140,
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03), 
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "NYC TRANSIT",
                          style: TextStyle(
                            fontSize: isSmall ? 8 : 10,
                            fontWeight: isDark ? FontWeight.w800 : FontWeight.w900,
                            letterSpacing: 2.0,
                            color: isDark ? Colors.white54 : Colors.black45, 
                            fontFamily: 'Helvetica',
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (lines.isNotEmpty)
                          Wrap(
                            spacing: 4.0, 
                            runSpacing: 4.0,
                            alignment: WrapAlignment.center,
                            children: lines.map((line) {
                              return Container(
                                width: circleSize,
                                height: circleSize,
                                decoration: BoxDecoration(
                                  color: _getLineColor(line),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: isDark ? 4 : 6,
                                      offset: Offset(0, isDark ? 2 : 3),
                                    ),
                                    if (!isDark)
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.5),
                                        blurRadius: 0,
                                        spreadRadius: 0.5,
                                        offset: const Offset(0, 0),
                                      )
                                  ]
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0), 
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        line,
                                        maxLines: 1, 
                                        style: TextStyle(
                                          color: _getTextColor(line),
                                          fontSize: circleText,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Helvetica', 
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        
                        if (lines.isNotEmpty) const SizedBox(height: 14),
                        
                        Text(
                          stationName,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: isDark ? FontWeight.w700 : FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black87, 
                            height: 1.1, 
                            fontFamily: 'Helvetica',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        if (borough.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on, size: boroughSize, color: isDark ? Colors.white54 : Colors.black54),
                              const SizedBox(width: 4),
                              Text(
                                borough.toUpperCase(),
                                style: TextStyle(
                                  fontSize: boroughSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontFamily: 'Helvetica',
                                ),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getLineColor(String line) {
    switch (line.toUpperCase()) {
      case 'A': case 'C': case 'E': return const Color(0xFF0039A6);
      case 'B': case 'D': case 'F': case 'M': return const Color(0xFFFF6319);
      case 'G': return const Color(0xFF6CBE45);
      case 'J': case 'Z': return const Color(0xFF996633);
      case 'L': return const Color(0xFFA7A9AC);
      case 'N': case 'Q': case 'R': case 'W': return const Color(0xFFFCCC0A);
      case '1': case '2': case '3': return const Color(0xFFEE352E);
      case '4': case '5': case '6': return const Color(0xFF00933C);
      case '7': return const Color(0xFFB933AD);
      case 'S': return const Color(0xFF808183);
      case 'SIR': return const Color(0xFF0039A6);
      default: return widget.isDarkMode ? Colors.white70 : Colors.black54; 
    }
  }

  Color _getTextColor(String line) {
    if (['N', 'Q', 'R', 'W'].contains(line.toUpperCase())) {
      return Colors.black;
    }
    return Colors.white;
  }
}

// 🧠 PHYSICS ENGINE: The Brain for each blob
class BlobNode {
  double x;
  double y;
  double vx = 0.0; // Velocity X (Momentum)
  double vy = 0.0; // Velocity Y (Momentum)
  double width;
  double height;

  BlobNode({
    required this.x, 
    required this.y, 
    required this.width, 
    required this.height
  });
}