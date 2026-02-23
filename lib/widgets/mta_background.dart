import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui'; // 👈 Required for the premium frosted glass blur

class MtaBackground extends StatelessWidget {
  final List<Map<String, dynamic>> stations;

  const MtaBackground({
    Key? key, 
    required this.stations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 16.0),
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
      fit: StackFit.expand, // Forces children to fill the space
      children: [
        // 🖼️ LAYER 1: The Background Image
        Image.asset(
          'assets/images/subway_blueprint.png', // Make sure this path matches your file
          fit: BoxFit.cover, // 👈 The magic scaling fix
          // Optional: Add a dark overlay so the white cards pop more
          color: Colors.black.withOpacity(0.4), 
          colorBlendMode: BlendMode.darken,
        ),

        // 🗂️ LAYER 2: Your existing grid of white cards
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

    return Container(
      width: double.infinity,
      height: double.infinity, 
      margin: const EdgeInsets.all(8.0), 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.0), 
        // 🌟 STRONGER DROP SHADOW: Pushes the card off the dark wall
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3), // Darker shadow for high contrast
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      // 🧊 THE BRIGHTER GLASSMORPHISM ENGINE
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25), 
          child: Container(
            decoration: BoxDecoration(
              // 🌟 PURE WHITE GRADIENT: Stops the dark background from muddying the card
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white, // 100% Solid Bright White
                  Colors.white.withOpacity(0.95), // 95% White (Barely translucent)
                ],
              ),
              border: Border.all(
                color: Colors.white, // Solid crisp white border
                width: 2.0, // Slightly thicker for a premium edge
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
                    // 🚇 THE OVERSIZED WATERMARK
                    Positioned(
                      right: -25,
                      bottom: -25,
                      child: Icon(
                        Icons.directions_subway_filled,
                        size: isSmall ? 100 : 140,
                        color: Colors.black.withOpacity(0.03), // Barely visible texture
                      ),
                    ),
                    
                    // 📝 THE MAIN CONTENT
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 🏷️ OFFICIAL SIGNAGE HEADER
                              Text(
                                "NYC TRANSIT",
                                style: TextStyle(
                                  fontSize: isSmall ? 8 : 10,
                                  fontWeight: FontWeight.w900, // Thicker font
                                  letterSpacing: 2.0,
                                  color: Colors.black45, // Slightly darker to pop on bright white
                                ),
                              ),
                              const SizedBox(height: 12),

                              // 🚇 THE COLORED CIRCLES
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
                                        // 🌟 POPPING CIRCLE SHADOW
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
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
                              
                              // 📍 THE STATION NAME
                              Text(
                                stationName,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w800, // Bolder station name
                                  letterSpacing: -0.5,
                                  color: Colors.black87,
                                  height: 1.1, 
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              // 🏙️ THE BOROUGH
                              if (borough.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.location_on, size: boroughSize, color: Colors.black54),
                                    const SizedBox(width: 4),
                                    Text(
                                      borough.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: boroughSize,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                        color: Colors.black54,
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
          ),
        ),
      ),
    );
  }

  // --- COLOR HELPERS (Same as before) ---
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
      default: return Colors.black87;
    }
  }

  Color _getTextColor(String line) {
    if (['N', 'Q', 'R', 'W'].contains(line.toUpperCase())) {
      return Colors.black;
    }
    return Colors.white;
  }
}