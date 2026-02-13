import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../config/constants.dart'; 

class SearchModal extends StatefulWidget {
  final bool isDarkMode;
  final List<String> availableCategories;
  final List<Restaurant> allRestaurants;
  final Function(String? category, String? name) onSelect;

  const SearchModal({
    super.key,
    required this.isDarkMode,
    required this.availableCategories,
    required this.allRestaurants,
    required this.onSelect,
  });

  @override
  State<SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<SearchModal> {
  String _query = "";
  final TextEditingController _controller = TextEditingController();

  // --- SAFER EMOJI LOOKUP ---
  String _getEmoji(String category) {
    if (category.isEmpty) return ""; 
    
    try {
      // 1. Try exact match
      if (categoryFlags.containsKey(category)) {
        return categoryFlags[category] ?? ""; 
      }

      // 2. Try case-insensitive match
      final lowerKey = category.toLowerCase();
      for (var key in categoryFlags.keys) {
        if (key.toLowerCase() == lowerKey) {
          return categoryFlags[key] ?? "";
        }
      }
    } catch (e) {
      debugPrint("Error finding emoji for $category: $e");
      return "❓"; 
    }
    return ""; 
  }

  // --- SAFE CAPITALIZATION ---
  String _safeCapitalize(String input) {
    if (input.isEmpty) return input;
    try {
      return input[0].toUpperCase() + input.substring(1);
    } catch (e) {
      return input; 
    }
  }

  List<String> get _uniqueRestaurantNames {
    try {
      return widget.allRestaurants
          .map((r) => r.name)
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    } catch (e) {
      return [];
    }
  }

  // --- SAFE TILE BUILDER (With Fallback Icon Logic) ---
  Widget _buildSafeTile(String text, bool isCategory) {
    try {
      String displayEmoji = "";
      String displayName = text;

      if (isCategory) {
        displayEmoji = _getEmoji(text);
        displayName = _safeCapitalize(text);
      }

      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          alignment: Alignment.center,
          child: isCategory 
            ? (displayEmoji.isNotEmpty 
                // CASE A: We have a valid emoji (e.g. 🇲🇽)
                ? Text(displayEmoji, style: const TextStyle(fontSize: 24))
                // CASE B: No emoji found? Show Yellow Dining Icon
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restaurant, color: Colors.orange, size: 18),
                  ))
            // CASE C: It is a Restaurant (Blue Store Icon)
            : Icon(Icons.store_rounded, color: Colors.blue.withOpacity(0.7), size: 24),
        ),
        title: Text(
          displayName, 
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black, 
            fontWeight: FontWeight.bold,
            fontSize: 16
          )
        ),
        onTap: () => widget.onSelect(isCategory ? text : null, isCategory ? null : text),
      );

    } catch (e) {
      // ERROR FALLBACK
      return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: Colors.red.withOpacity(0.2),
        child: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Error on item '$text': $e",
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    // Filter Logic
    final visibleCategories = widget.availableCategories.where((cat) {
      return cat.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    final visibleRestaurants = _uniqueRestaurantNames.where((name) {
      return name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // --- GRABBER ---
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 20),
              width: 50, height: 5,
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5), borderRadius: BorderRadius.circular(10))
            ),
          ),

          // --- SEARCH FIELD ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18),
              decoration: InputDecoration(
                hintText: "Search cuisines or restaurants...",
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white70 : Colors.black54),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (val) {
                setState(() {
                  _query = val;
                });
              },
            ),
          ),
          
          const SizedBox(height: 10),

          // --- RESULTS LIST ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // SECTION 1: CUISINES
                if (visibleCategories.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 5),
                    child: Text("CUISINES", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  ...visibleCategories.map((cat) => _buildSafeTile(cat, true)),
                ],

                // SECTION 2: RESTAURANTS
                if (visibleRestaurants.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 5),
                    child: Text("RESTAURANTS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  ...visibleRestaurants.take(50).map((name) => _buildSafeTile(name, false)),
                ],

                // EMPTY STATE
                if (visibleCategories.isEmpty && visibleRestaurants.isEmpty)
                   Padding(
                     padding: const EdgeInsets.only(top: 50),
                     child: Center(child: Text("No results found.", style: TextStyle(color: Colors.grey))),
                   )
              ],
            ),
          ),
        ],
      ),
    );
  }
}