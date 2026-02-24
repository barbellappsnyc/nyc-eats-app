import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';

class MtaBackground extends StatefulWidget {
  final List<Map<String, dynamic>> stations;
  final bool isDarkMode; 
  final Offset passportPosition; 
  final double passportScale;

  const MtaBackground({
    Key? key, 
    required this.stations,
    this.isDarkMode = true, 
    this.passportPosition = Offset.zero, 
    this.passportScale = 0.85,           
  }) : super(key: key);

  @override
  State<MtaBackground> createState() => _MtaBackgroundState();
}

class _MtaBackgroundState extends State<MtaBackground> {
  
  // 📍 THE ORBITAL TRACK: 10 fixed anchor points around the bezel
  final List<Alignment> orbitalAnchors = const [
    Alignment(-1.0, -1.0),  // 0: Top-Left
    Alignment( 0.0, -1.0),  // 1: Top-Center
    Alignment( 1.0, -1.0),  // 2: Top-Right
    Alignment( 1.0, -0.33), // 3: Right-Upper (1/3rd down the right wall)
    Alignment( 1.0,  0.33), // 4: Right-Lower (2/3rds down the right wall)
    Alignment( 1.0,  1.0),  // 5: Bottom-Right
    Alignment( 0.0,  1.0),  // 6: Bottom-Center
    Alignment(-1.0,  1.0),  // 7: Bottom-Left
    Alignment(-1.0,  0.33), // 8: Left-Lower (2/3rds down the left wall)
    Alignment(-1.0, -0.33), // 9: Left-Upper (1/3rd down the left wall)
  ];

  // 🧠 MEMORY: Tracks the current anchor index for each blob
  late List<int> currentAnchors;

  @override
  void initState() {
    super.initState();
    _initializeDefaultAnchors();
  }

  // 📐 DEFAULT LAYOUTS: Places them in their starting spots based on the count
  void _initializeDefaultAnchors() {
    int count = widget.stations.length;
    if (count == 1) {
      currentAnchors = [1]; // Top-Center
    } else if (count == 2) {
      currentAnchors = [1, 6]; // Top-Center, Bottom-Center
    } else if (count == 3) {
      currentAnchors = [0, 1, 2]; // Top-Left, Top-Center, Top-Right
    } else {
      currentAnchors = [0, 2, 5, 7]; // Top-Left, Top-Right, Bottom-Right, Bottom-Left
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stations.isEmpty) {
      return Center(
        child: CupertinoActivityIndicator(
          radius: 16.0, 
          color: widget.isDarkMode ? Colors.white : Colors.black,
        ),
      );
    }

    final Size screenSize = MediaQuery.of(context).size;
    final int count = widget.stations.length;

    // 📏 SHAPE LOGIC: Calculate sizes based on count
    double defaultWidth;
    double defaultHeight;
    if (count == 1 || count == 2) {
      defaultWidth = screenSize.width * 0.85;  // Wide rectangle
      defaultHeight = screenSize.height * 0.22;
    } else if (count == 3) {
      defaultWidth = screenSize.width * 0.28;  // 3 narrow squircles across the top
      defaultHeight = screenSize.height * 0.18;
    } else {
      defaultWidth = screenSize.width * 0.40;  // 4 squarish corner squircles
      defaultHeight = screenSize.height * 0.20;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 🖼️ LAYER 1: THE STATIC BACKGROUND IMAGE
        Image.asset(
          'assets/images/subway_blueprint.png', 
          fit: BoxFit.cover,
          color: Colors.black.withOpacity(0.4), 
          colorBlendMode: BlendMode.darken,
        ),

        // 🗂️ LAYER 2: THE FLOATING BLOBS
        // 👇 THE FIX: The 100px padding is back to counteract the oversized squish canvas
        Padding(
          padding: const EdgeInsets.all(100.0),
          child: SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
            child: Stack(
              children: List.generate(count, (index) {
                // Grab the anchor alignment from memory
                Alignment currentAlignment = orbitalAnchors[currentAnchors[index]];

                return AnimatedAlign(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut, 
                  alignment: currentAlignment,
                  child: _buildStationCard(
                    widget.stations[index], 
                    defaultWidth, 
                    defaultHeight,
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // 👇 ADDED cardWidth and cardHeight parameters
  Widget _buildStationCard(Map<String, dynamic> station, double cardWidth, double cardHeight) {
    final String stationName = station['station_name'] ?? 'Unknown Station';
    final String linesString = station['lines'] ?? '';
    final String borough = station['borough'] ?? '';
    
    final List<String> lines = linesString.isNotEmpty 
        ? linesString.trim().split(RegExp(r'\s+')).where((l) => l.isNotEmpty).toList()
        : [];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      width: cardWidth,   // 👈 REPLACED double.infinity
      height: cardHeight, // 👈 REPLACED double.infinity
      margin: const EdgeInsets.all(8.0), 
      // ... the rest of the BoxDecoration and stack remains exactly the same ...
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 🌙 BASE LAYER: Night Card
              _buildCardContent(stationName, lines, borough, isDark: true),

              // ☀️ TOP LAYER: Day Card
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                opacity: widget.isDarkMode ? 0.0 : 1.0,
                child: _buildCardContent(stationName, lines, borough, isDark: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(String stationName, List<String> lines, String borough, {required bool isDark}) {
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