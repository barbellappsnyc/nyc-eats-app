import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // For the indeterminate circular progress indicator

// Note: Replace 'Station' with whatever your actual data model is called
class MtaBackground extends StatelessWidget {
  final List<Map<String, dynamic>> stations;
  
  const MtaBackground({
    Key? key, 
    required this.stations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Elegant loading state while fetching
    if (stations.isEmpty) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 16.0), 
      );
    }

    int count = stations.length;

    if (count == 1) {
      return _buildStationCard(stations[0]);
      
    } else if (count == 2) {
      return Column(
        children: [
          Expanded(child: _buildStationCard(stations[0])),
          Expanded(child: _buildStationCard(stations[1])),
        ],
      );
      
    } else if (count == 3) {
      return Column(
        children: [
          Expanded(child: _buildStationCard(stations[0])),
          Expanded(child: _buildStationCard(stations[1])),
          Expanded(child: _buildStationCard(stations[2])),
        ],
      );
      
    } else {
      // 4 Stamps (or more, capped at 4 for the UI): 2x2 grid
      return Column(
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
  }

  // Maps the train line to its official MTA color
  Color _getLineColor(String line) {
    switch (line.toUpperCase()) {
      case 'A': case 'C': case 'E': return const Color(0xFF0039A6); // Blue
      case 'B': case 'D': case 'F': case 'M': return const Color(0xFFFF6319); // Orange
      case 'G': return const Color(0xFF6CBE45); // Light Green
      case 'J': case 'Z': return const Color(0xFF996633); // Brown
      case 'L': return const Color(0xFFA7A9AC); // Light Grey
      case 'N': case 'Q': case 'R': case 'W': return const Color(0xFFFCCC0A); // Yellow
      case '1': case '2': case '3': return const Color(0xFFEE352E); // Red
      case '4': case '5': case '6': return const Color(0xFF00933C); // Green
      case '7': return const Color(0xFFB933AD); // Purple
      case 'S': return const Color(0xFF808183); // Dark Grey
      case 'SIR': return const Color(0xFF0039A6); // Staten Island Railway
      default: return Colors.black87; // Fallback
    }
  }

  // Yellow lines need dark text to be readable
  Color _getTextColor(String line) {
    if (['N', 'Q', 'R', 'W'].contains(line.toUpperCase())) {
      return Colors.black;
    }
    return Colors.white;
  }

  Widget _buildStationCard(Map<String, dynamic> station) {
    final String stationName = station['station_name'] ?? 'Unknown Station';
    final String linesString = station['lines'] ?? '';
    final String borough = station['borough'] ?? '';
    
    // Aggressively clean up spaces to prevent invisible circles
    final List<String> lines = linesString.isNotEmpty 
        ? linesString.trim().split(RegExp(r'\s+')).where((l) => l.isNotEmpty).toList()
        : [];

    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85), 
        borderRadius: BorderRadius.circular(24.0), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // 🧠 THE FIX: LayoutBuilder measures the exact bounds of the card
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double cardWidth = constraints.maxWidth;
          
          // Responsive Math: Shrink elements if we are in a tight 2x2 grid (<180px wide)
          final double circleSize = cardWidth < 180 ? 22.0 : 34.0;
          final double circleTextSize = cardWidth < 180 ? 12.0 : 18.0;
          final double titleSize = cardWidth < 180 ? 15.0 : 20.0;
          final double boroughSize = cardWidth < 180 ? 10.0 : 12.0;

          return Padding(
            padding: const EdgeInsets.all(12.0),
            // Center + SingleChildScrollView ensures we never get a vertical overflow error
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // Keep column tight
                  children: [
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
                            ),
                            child: Center(
                              child: Text(
                                line,
                                style: TextStyle(
                                  color: _getTextColor(line),
                                  fontSize: circleTextSize,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Helvetica', 
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    
                    if (lines.isNotEmpty) const SizedBox(height: 12),
                    
                    // 📍 THE STATION NAME
                    Text(
                      stationName,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3, // Wraps long names safely
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // 🏙️ THE BOROUGH
                    if (borough.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        borough.toUpperCase(),
                        style: TextStyle(
                          fontSize: boroughSize,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: Colors.black54,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}