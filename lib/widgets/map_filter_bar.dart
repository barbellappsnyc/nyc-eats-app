import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/telemetry_service.dart'; // 📡 TELEMETRY IMPORT

class MapFilterBar extends StatefulWidget {
  final bool isDarkMode;
  final bool showOpenOnly;
  final bool savedOnly;
  final bool showVegetarian;
  final bool showVegan;
  final Set<String> selectedMichelin;
  final Set<String> selectedPrices;

  // Callbacks
  final Function(bool) onOpenChanged;
  final Function(bool) onSavedChanged;
  final Function(bool) onVegChanged;
  final Function(bool) onVeganChanged;
  final Function(Set<String>) onMichelinChanged;
  final Function(Set<String>) onPriceChanged;

  const MapFilterBar({
    super.key,
    required this.isDarkMode,
    required this.showOpenOnly,
    required this.savedOnly,
    required this.showVegetarian,
    required this.showVegan,
    required this.selectedMichelin,
    required this.selectedPrices,
    required this.onOpenChanged,
    required this.onSavedChanged,
    required this.onVegChanged,
    required this.onVeganChanged,
    required this.onMichelinChanged,
    required this.onPriceChanged,
  });

  @override
  State<MapFilterBar> createState() => _MapFilterBarState();
}

class _MapFilterBarState extends State<MapFilterBar> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToStart() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // --- SHEET LOGIC ---
  void _showMultiSelectSheet({
    required String title,
    required List<String> options,
    required Set<String> currentSelection,
    required Function(Set<String>) onApply,
  }) {
    Set<String> tempSelection = Set.from(currentSelection);
    final isDark = widget.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((option) {
                    final isSelected = tempSelection.contains(option);
                    return CheckboxListTile(
                      title: _buildSheetLabel(option, isDark),
                      value: isSelected,
                      activeColor: isDark ? Colors.white : Colors.black,
                      checkColor: isDark ? Colors.black : Colors.white,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) => setSheetState(
                        () => val == true
                            ? tempSelection.add(option)
                            : tempSelection.remove(option),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setSheetState(tempSelection.clear),
                          child: Text(
                            "Clear",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white
                                : Colors.black,
                            foregroundColor: isDark
                                ? Colors.black
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            onApply(tempSelection);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Apply",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetLabel(String option, bool isDark) {
    if (option.contains('\$')) {
      return Text(
        option,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    if (option == "Bib Gourmand") {
      return Row(
        children: [
          const Icon(Icons.restaurant, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(
            "Bib Gourmand",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    if (option.contains("Star")) {
      int count = option.contains("1")
          ? 1
          : option.contains("2")
          ? 2
          : 3;
      return Row(
        children: List.generate(
          count,
          (_) => const Icon(Icons.star, color: Colors.red, size: 20),
        ),
      );
    }
    return Text(
      option,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
    );
  }

  Widget _buildMichelinLabelContent() {
    if (widget.selectedMichelin.isEmpty) return const Text("Michelin");
    if (widget.selectedMichelin.length > 1) {
      return Text("${widget.selectedMichelin.length} Selected");
    }
    String selection = widget.selectedMichelin.first;
    if (selection == "Bib Gourmand") {
      return Row(
        children: [
          const Icon(Icons.restaurant, color: Colors.red, size: 16),
          const SizedBox(width: 6),
          Text(
            "Bib Gourmand",
            style: TextStyle(
              color: widget.isDarkMode ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    int count = selection.contains("1")
        ? 1
        : selection.contains("2")
        ? 2
        : 3;
    return Row(
      children: [
        ...List.generate(
          count,
          (_) => const Icon(Icons.star, color: Colors.red, size: 16),
        ),
        const SizedBox(width: 6),
        Text(
          selection,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    // Sort logic handled here
    List<Map<String, dynamic>> filters = [
      {
        'selected': widget.selectedPrices.isNotEmpty,
        'widget': FilterChip(
          label: Text(
            widget.selectedPrices.isEmpty
                ? "Price"
                : widget.selectedPrices.join(", "),
          ),
          avatar: widget.selectedPrices.isNotEmpty
              ? null
              : Icon(
                  Icons.attach_money,
                  size: 16,
                  color: isDark ? Colors.white : Colors.black,
                ),
          selected: widget.selectedPrices.isNotEmpty,
          showCheckmark: false,
          onSelected: (_) => _showMultiSelectSheet(
            title: "Filter by Price",
            options: ["\$", "\$\$", "\$\$\$", "\$\$\$\$"],
            currentSelection: widget.selectedPrices,
            onApply: (s) {
              // 📡 TELEMETRY: Price Filter Applied
              TelemetryService.logInteraction(
                actionType: 'filter_updated',
                metadata: {'filter': 'price', 'selected_tiers': s.toList()},
              );
              widget.onPriceChanged(s);
              _scrollToStart();
            },
          ),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          selectedColor: isDark ? Colors.white : Colors.black,
          labelStyle: TextStyle(
            color: widget.selectedPrices.isNotEmpty
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white : Colors.black),
            fontWeight: FontWeight.bold,
          ),
          side: BorderSide(
            color: widget.selectedPrices.isNotEmpty
                ? (isDark ? Colors.white : Colors.black)
                : Colors.transparent,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      },
      {
        'selected': widget.showOpenOnly,
        'widget': FilterChip(
          label: const Text("Open Now"),
          selected: widget.showOpenOnly,
          onSelected: (val) {
            // 📡 TELEMETRY: Open Now Toggled
            TelemetryService.logInteraction(
              actionType: 'filter_toggled',
              metadata: {'filter': 'open_now', 'is_active': val},
            );
            widget.onOpenChanged(val);
            _scrollToStart();
          },
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          selectedColor: Colors.green.withOpacity(0.2),
          checkmarkColor: Colors.green,
          labelStyle: TextStyle(
            color: widget.showOpenOnly
                ? Colors.green
                : (isDark ? Colors.white : Colors.black),
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          side: BorderSide.none,
        ),
      },
      {
        'selected': widget.selectedMichelin.isNotEmpty,
        'widget': AnimatedMichelinButton(
          isDarkMode: isDark,
          selectedMichelin: widget.selectedMichelin,
          onTap: () => _showMultiSelectSheet(
            title: "Michelin Rating",
            options: ["Bib Gourmand", "1 Star", "2 Stars", "3 Stars"],
            currentSelection: widget.selectedMichelin,
            onApply: (s) {
              // 📡 TELEMETRY: Michelin Filter Applied
              TelemetryService.logInteraction(
                actionType: 'filter_updated',
                metadata: {'filter': 'michelin', 'selected_tiers': s.toList()},
              );
              widget.onMichelinChanged(s);
              _scrollToStart();
            },
          ),
        ),
      },
      {
        'selected': widget.savedOnly,
        'widget': FilterChip(
          label: const Text("Saved"),
          avatar: Icon(
            Icons.favorite,
            size: 16,
            color: widget.savedOnly
                ? Colors.red
                : (isDark ? Colors.white : Colors.black),
          ),
          selected: widget.savedOnly,
          showCheckmark: false,
          onSelected: (val) {
            // 📡 TELEMETRY: Saved Items Toggled
            TelemetryService.logInteraction(
              actionType: 'filter_toggled',
              metadata: {'filter': 'saved', 'is_active': val},
            );
            widget.onSavedChanged(val);
            _scrollToStart();
          },
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          selectedColor: isDark ? Colors.white : Colors.black,
          labelStyle: TextStyle(
            color: widget.savedOnly
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white : Colors.black),
            fontWeight: FontWeight.bold,
          ),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      },
      {
        'selected': widget.showVegetarian,
        'widget': FilterChip(
          label: const Text("Veg Options"),
          selected: widget.showVegetarian,
          onSelected: (val) {
            // 📡 TELEMETRY: Vegetarian Filter Toggled
            TelemetryService.logInteraction(
              actionType: 'filter_toggled',
              metadata: {
                'filter': 'dietary',
                'type': 'vegetarian',
                'is_active': val,
              },
            );
            widget.onVegChanged(val);
            _scrollToStart();
          },
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          selectedColor: Colors.green[800],
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: widget.showVegetarian
                ? Colors.white
                : (isDark ? Colors.white : Colors.black),
            fontWeight: FontWeight.bold,
          ),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      },
      {
        'selected': widget.showVegan,
        'widget': FilterChip(
          label: const Text("Vegan Options"),
          selected: widget.showVegan,
          onSelected: (val) {
            // 📡 TELEMETRY: Vegan Filter Toggled
            TelemetryService.logInteraction(
              actionType: 'filter_toggled',
              metadata: {
                'filter': 'dietary',
                'type': 'vegan',
                'is_active': val,
              },
            );
            widget.onVeganChanged(val);
            _scrollToStart();
          },
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          selectedColor: Colors.green[800],
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: widget.showVegan
                ? Colors.white
                : (isDark ? Colors.white : Colors.black),
            fontWeight: FontWeight.bold,
          ),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      },
    ];

    filters.sort(
      (a, b) => (a['selected'] == b['selected']) ? 0 : (a['selected'] ? -1 : 1),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: filters
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: f['widget'] as Widget,
              ),
            )
            .toList(),
      ),
    );
  }
}

// =========================================================================
// 🌟 CUSTOM ANIMATED MICHELIN CHIP (The "Cartoon Gleam")
// =========================================================================
class AnimatedMichelinButton extends StatefulWidget {
  final bool isDarkMode;
  final Set<String> selectedMichelin;
  final VoidCallback onTap;

  const AnimatedMichelinButton({
    super.key,
    required this.isDarkMode,
    required this.selectedMichelin,
    required this.onTap,
  });

  @override
  State<AnimatedMichelinButton> createState() => _AnimatedMichelinButtonState();
}

class _AnimatedMichelinButtonState extends State<AnimatedMichelinButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // 2-second loop for the lap
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // easeInOutCubic creates the "Zap and Slow down" cartoon physics
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Light mode: Matte Black, Dark mode: Crisp White
    final bgColor = widget.isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final textColor = widget.isDarkMode ? Colors.black : Colors.white;

    Widget content;
    if (widget.selectedMichelin.isEmpty) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 16, color: Colors.red),
          const SizedBox(width: 6),
          Text(
            "Michelin",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else if (widget.selectedMichelin.length > 1) {
      content = Text(
        "${widget.selectedMichelin.length} Selected",
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      );
    } else {
      String selection = widget.selectedMichelin.first;
      if (selection == "Bib Gourmand") {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant, color: Colors.red, size: 16),
            const SizedBox(width: 6),
            Text(
              "Bib Gourmand",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
          ],
        );
      } else {
        int count = selection.contains("1")
            ? 1
            : selection.contains("2")
            ? 2
            : 3;
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(
              count,
              (_) => const Icon(Icons.star, color: Colors.red, size: 16),
            ),
            const SizedBox(width: 6),
            Text(
              selection,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
          ],
        );
      }
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            // The 2px padding acts as the border width!
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              // The spinning SweepGradient creates the gleam
              gradient: SweepGradient(
                transform: GradientRotation(_animation.value * 2 * math.pi),
                colors: const [
                  Color(0xFFFFD700), // Gold
                  Color(0xFFFFD700), // Gold
                  Colors.white, // 🌟 The bright white zap
                  Color(0xFFFFD700), // Gold
                  Color(0xFFFFD700), // Gold
                ],
                // Tightly cluster the white stop to make a sharp gleam
                stops: const [0.0, 0.85, 0.9, 0.95, 1.0],
              ),
            ),
            child: child, // Inner container
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: content,
        ),
      ),
    );
  }
}
