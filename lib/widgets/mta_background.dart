import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';

class MtaBackground extends StatelessWidget {
  final List<Map<String, dynamic>> stations;
  final bool isDarkMode; // 👈 The Master Switch

  const MtaBackground({
    Key? key, 
    required this.stations,
    this.isDarkMode = true, 
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) {
      return Center(
        child: CupertinoActivityIndicator(
          radius: 16.0, 
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      );
    }

    Widget gridLayout;
    int count = stations.length;

    if (count == 1) {
      gridLayout = _buildStationCard(stations[0]);
    } else if (count == 2) {
      gridLayout = Column(
        children: [
          Expanded(child: _buildStationCard(stations[0])),
          Expanded(child: _buildStationCard(stations[1])),
        ],
      );
    } else if (count == 3) {
      gridLayout = Column(
        children: [
          Expanded(child: _buildStationCard(stations[0])),
          Expanded(child: _buildStationCard(stations[1])),
          Expanded(child: _buildStationCard(stations[2])),
        ],
      );
    } else {
      gridLayout = Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildStationCard(stations[0])),
                Expanded(child: _buildStationCard(stations[1])),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildStationCard(stations[2])),
                Expanded(child: _buildStationCard(stations[3])),
              ],
            ),
          ),
        ],
      );
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

        // 🗂️ LAYER 2: THE DYNAMIC CARDS
        Padding(
          padding: const EdgeInsets.all(100.0), 
          child: SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 24.0), 
            child: gridLayout,
          ),
        ),
      ],
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station) {
    final String stationName = station['station_name'] ?? 'Unknown Station';
    final String linesString = station['lines'] ?? '';
    final String borough = station['borough'] ?? '';
    
    final List<String> lines = linesString.isNotEmpty 
        ? linesString.trim().split(RegExp(r'\s+')).where((l) => l.isNotEmpty).toList()
        : [];

    // 🌟 THE MASTER ANIMATION: Only the outer shadow morphs
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      width: double.infinity,
      height: double.infinity, 
      margin: const EdgeInsets.all(8.0), 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.0), 
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.3), 
            blurRadius: isDarkMode ? 24 : 30,
            spreadRadius: isDarkMode ? 0 : 2,
            offset: Offset(0, isDarkMode ? 10 : 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.0),
        // ONE single blur applied to the entire stack prevents double-blur performance issues
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          // 🎬 THE TRUE APPLE-STYLE DISSOLVE
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 🌙 BASE LAYER: The Night Card (Always rendered, sits underneath)
              _buildCardContent(stationName, lines, borough, isDark: true),

              // ☀️ TOP LAYER: The Day Card (Fades in over the Night card without transparency bleed)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                opacity: isDarkMode ? 0.0 : 1.0,
                child: _buildCardContent(stationName, lines, borough, isDark: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🧱 THE STATIC CARD RENDERER (Clean, no animation mess inside)
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
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      color: _getTextColor(line),
                                      fontSize: circleText,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Helvetica', 
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
      default: return isDarkMode ? Colors.white70 : Colors.black54; 
    }
  }

  Color _getTextColor(String line) {
    if (['N', 'Q', 'R', 'W'].contains(line.toUpperCase())) {
      return Colors.black;
    }
    return Colors.white;
  }
}