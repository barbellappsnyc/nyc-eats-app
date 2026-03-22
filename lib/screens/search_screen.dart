import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // 🌟 ADDED FOR NATIVE iOS LOADER
import '../models/restaurant.dart';
import '../config/constants.dart'; 
import 'dart:async'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 

class SearchScreen extends StatefulWidget {
  final List<String> availableCategories;
  final bool isDarkMode;
  final Function(String category) onCategorySelected;
  final Function(Restaurant restaurant) onRestaurantSelected;

  const SearchScreen({
    super.key,
    required this.availableCategories,
    required this.isDarkMode,
    required this.onCategorySelected,
    required this.onRestaurantSelected,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  List<Restaurant> _filteredRestaurants = [];
  List<String> _filteredCategories = []; 
  String _query = "";
  
  Timer? _debounce;
  bool _isSearchingDB = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_searchFocus);
    });
    _filteredCategories = widget.availableCategories;
  }

  @override
  void dispose() {
    _debounce?.cancel(); 
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _formatCategoryName(String category) {
    return category
        .split('_')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' 
            : '')
        .join(' ');
  }

  void _onSearchChanged(String query) {
    setState(() {
      _query = query;
      
      if (query.isEmpty) {
        _filteredRestaurants = [];
        _filteredCategories = widget.availableCategories; 
        _isSearchingDB = false;
        _debounce?.cancel();
      } else {
        _filteredCategories = widget.availableCategories.where((c) {
          return _formatCategoryName(c).toLowerCase().contains(query.toLowerCase());
        }).toList();

        if (_debounce?.isActive ?? false) _debounce!.cancel();
        
        setState(() => _isSearchingDB = true); 
        
        _debounce = Timer(const Duration(milliseconds: 500), () {
          _searchSupabase(query);
        });
      }
    });
  }

  Future<void> _searchSupabase(String searchQuery) async {
    try {
      final data = await Supabase.instance.client
          .from('restaurants')
          .select()
          .ilike('name', '%$searchQuery%') 
          .limit(20);

      if (mounted) {
        setState(() {
          _filteredRestaurants = data.map((json) => Restaurant.fromMap(json)).toList();
          _isSearchingDB = false;
        });
      }
    } catch (e) {
      debugPrint("🚨 Search Query Error: $e");
      if (mounted) setState(() => _isSearchingDB = false);
    }
  }
  
  String? _getEmojiForCategory(String category) {
    if (category.toLowerCase() == 'hot_dog' || category.toLowerCase() == 'hot dog') {
      return '🌭';
    }

    if (categoryFlags.containsKey(category)) {
      return categoryFlags[category];
    }
    
    final key = categoryFlags.keys.firstWhere(
      (k) => k.toLowerCase() == category.toLowerCase(), 
      orElse: () => ""
    );
    if (key.isNotEmpty) return categoryFlags[key];

    for (var entry in categoryFlags.entries) {
      if (category.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color hintColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        style: TextStyle(color: textColor, fontSize: 16),
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: "Search restaurants, cuisines...",
                          hintStyle: TextStyle(color: hintColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close, color: hintColor),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged("");
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _buildCategoriesList(textColor, isDark)
                  : _buildSearchResults(textColor, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList(Color textColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            "Explore Cuisines",
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.availableCategories.length,
            separatorBuilder: (context, index) => Divider(
              height: 1, 
              color: isDark ? Colors.grey[800] : Colors.grey[200], 
              indent: 70, 
              endIndent: 20
            ),
            itemBuilder: (context, index) {
              final cat = widget.availableCategories[index];
              final emoji = _getEmojiForCategory(cat);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  width: 45, height: 45,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: emoji != null
                      ? Text(emoji, style: const TextStyle(fontSize: 24)) 
                      : Icon(Icons.restaurant, size: 20, color: textColor),
                ),
                title: Text(
                  _formatCategoryName(cat), 
                  style: TextStyle(
                    color: textColor, 
                    fontSize: 16, 
                    fontWeight: FontWeight.w500
                  )
                ),
                onTap: () {
                  widget.onCategorySelected(cat); 
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(Color textColor, bool isDark) {
    if (_isSearchingDB && _filteredRestaurants.isEmpty) {
      return const Center(
        // 🌟 THE FIX: Replaced standard Material loader with the native iOS spinner
        child: CupertinoActivityIndicator(radius: 16),
      );
    }

    if (!_isSearchingDB && _filteredRestaurants.isEmpty && _filteredCategories.isEmpty) {
      return Center(
        child: Text("No results found", style: TextStyle(color: textColor)),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_filteredCategories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              "MATCHING CUISINES",
              style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
          ..._filteredCategories.map((cat) {
            final emoji = _getEmojiForCategory(cat);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Container(
                width: 45, height: 45,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: emoji != null
                    ? Text(emoji, style: const TextStyle(fontSize: 24))
                    : Icon(Icons.restaurant, size: 20, color: textColor),
              ),
              title: Text(
                _formatCategoryName(cat), 
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)
              ),
              onTap: () {
                widget.onCategorySelected(cat); 
                Navigator.pop(context);
              },
            );
          }),
          
          if (_filteredRestaurants.isNotEmpty)
             Divider(height: 32, color: isDark ? Colors.grey[800] : Colors.grey[200], indent: 24, endIndent: 24),
        ],

        if (_filteredRestaurants.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              "RESTAURANTS",
              style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
          ..._filteredRestaurants.map((r) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4), 
              title: Text(r.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              subtitle: Text(
                "${_formatCategoryName(r.cuisine)} • ${r.price}", 
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
              ),
              onTap: () {
                widget.onRestaurantSelected(r);
                Navigator.pop(context);
              },
            );
          }),
        ]
      ],
    );
  }
}