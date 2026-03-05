import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // Required for compute()
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- IMPORTS ---
import '../models/restaurant.dart';
import '../widgets/restaurant_detail_sheet.dart';
import '../widgets/country_wheel_modal.dart';
import '../widgets/map_filter_bar.dart';
import 'search_screen.dart';
import 'auth_screen.dart'; 
import 'profile_edit_screen.dart'; 
import 'passport_collection_screen.dart'; 
import '../services/passport_service.dart'; 
import 'package:connectivity_plus/connectivity_plus.dart'; 
import '../services/tile_provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();

  bool _isJumpingToLocation = false;

  // --- STATE VARIABLES ---
  bool isDarkMode = false;
  bool showOpenOnly = false;
  bool savedOnly = false;

  Set<String> _selectedMichelin = {}; 
  Set<String> _selectedPrices = {}; 
  
  String? selectedCategory;
  String? selectedRestaurantName;
  LatLng? myLocation;
  final LatLng _defaultLocation = const LatLng(40.735, -73.99);
  List<Restaurant> allRestaurants = [];
  Set<String> savedRestaurantNames = {};
  bool isLoading = true;
  bool hasError = false;

  int _fetchedCount = 0;
  int _totalToFetch = 0;
  
  // 🌟 NEW: The "Fake" smooth counter variables
  int _displayFetchedCount = 0;
  Timer? _simulationTimer;

  bool _isCheckingLocation = false;

  bool _showVegetarian = false;
  bool _showVegan = false;

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusStreamSubscription;

  final Set<String> _savedRestaurants = {};

  // 🔌 CONNECTIVITY STATE
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isGpsDisabled = false; 

  String? _userPhotoUrl;
  String? _userName;
  String? _userGender;
  int? _userAge;

  // 🔦 TUTORIAL KEYS
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _wheelKey = GlobalKey();
  final GlobalKey _passportKey = GlobalKey();

  // --- ANIMATED TEXT VARIABLES ---
  int _currentPhraseIndex = 0;
  Timer? _textTimer;
  final List<String> _searchPhrases = [
    "Hungry?", "Nom nom nom...", "Where to next?", "Craving something?", "Let's eat!", "Find a hidden gem..."
  ];

  @override
  void initState() {
    super.initState();
    _startTextAnimation();
    WidgetsBinding.instance.addObserver(this);
    _safeInit();

    _initConnectivityListener();
    _fastBootSequence();
  }

  Future<void> _safeInit() async {
    _fetchUserProfile(); 
    PassportService.prewarmCache();

    await _loadTheme();
    await _loadFavorites();
    await _fetchRestaurants();
    
    _initLocationService();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel(); // 👈 ADD THIS
    _textTimer?.cancel();
    // ... rest of your dispose method
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSubscription?.cancel();
    _serviceStatusStreamSubscription?.cancel();
    _connectivitySubscription?.cancel(); 
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isCheckingLocation) {
        _checkLocationOnResume();
        if (allRestaurants.isEmpty) _fetchRestaurants();
      }
    }
  }

  Future<void> _fastBootSequence() async {
    _loadTheme();
    await _loadCachedLocation(); 

    _fetchUserProfile();
    PassportService.prewarmCache();
    await _loadFavorites();
    await _fetchRestaurants();
    
    _initLocationService();

    Future.delayed(const Duration(seconds: 3), () {
      MapHeater.preCacheTiles(40.735, -73.99, true); 
      debugPrint("🌑 Dark Mode Map warming up in background...");
    });

    _checkAndShowTutorial(); 
  }

  Future<void> _loadCachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final double? lat = prefs.getDouble('last_known_lat');
    final double? lng = prefs.getDouble('last_known_lng');

    if (lat != null && lng != null) {
      if (mounted) {
        setState(() {
          myLocation = LatLng(lat, lng);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(myLocation!, 14.0);
        });
      }
    }
  }

  Future<void> _saveLocationToCache(LatLng position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_known_lat', position.latitude);
    await prefs.setDouble('last_known_lng', position.longitude);
  }

  void _initConnectivityListener() {
    Connectivity().checkConnectivity().then((results) {
       _updateConnectionStatus(results);
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    
    _serviceStatusStreamSubscription = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (mounted) {
        setState(() {
          _isGpsDisabled = (status == ServiceStatus.disabled);
          if (_isGpsDisabled) myLocation = null; 
        });
      }
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    bool hasConnection = results.any((r) => r != ConnectivityResult.none);
    
    if (mounted) {
      setState(() => _isOffline = !hasConnection);
      
      // 🚀 AUTO-RESUME: If connection is restored and the dataset is incomplete
      if (hasConnection && allRestaurants.length < 36252) {
        debugPrint("🌐 Connection restored! Resuming background sync...");
        _fetchRestaurants(); 
      }
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => isDarkMode = prefs.getBool('is_dark_mode') ?? false);
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => isDarkMode = !isDarkMode);
    await prefs.setBool('is_dark_mode', isDarkMode);
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => savedRestaurantNames = (prefs.getStringList('saved_restaurants') ?? []).toSet());
  }

  Future<void> _toggleFavorite(String restaurantName) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (savedRestaurantNames.contains(restaurantName)) {
        savedRestaurantNames.remove(restaurantName);
      } else {
        savedRestaurantNames.add(restaurantName);
      }
    });
    await prefs.setStringList('saved_restaurants', savedRestaurantNames.toList());
  }

  Future<void> _checkLocationOnResume() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted && myLocation == null) _showLocationDialog();
    else _checkPermissionAndListen();
  }

  Future<void> _initLocationService() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      _startListening();
    } else {
      _checkPermissionAndListen();
    }
  }

  Future<void> _checkPermissionAndListen() async {
    if (_isCheckingLocation) return;
    _isCheckingLocation = true;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      
      _startListening();
    } finally {
      _isCheckingLocation = false;
    }
  }

  void _startListening() {
    Geolocator.getLastKnownPosition().then((pos) {
      if (pos != null && myLocation == null) {
         setState(() => myLocation = LatLng(pos.latitude, pos.longitude));
      }
    });

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
    ).listen((Position position) {
      final newLoc = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() { myLocation = newLoc; });
        _saveLocationToCache(newLoc);
      }
    });
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Location Disabled"),
        content: const Text("Turn on location to see spots near you."),
        actions: [
          TextButton(child: const Text("Turn On"), onPressed: () { Navigator.pop(context); Geolocator.openLocationSettings(); }),
        ],
      ),
    );
  }

  List<String> get dynamicCuisines {
    final Set<String> uniqueCuisines = {};
    for (var r in allRestaurants) {
      r.cuisine.split(RegExp(r'[;,/]')).forEach((part) {
        var clean = part.trim().replaceAll('_', ' ');
        if (clean.isNotEmpty && clean.toLowerCase() != "other" && clean.toLowerCase() != "n/a") {
          uniqueCuisines.add(clean.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : "").join(' '));
        }
      });
    }
    return uniqueCuisines.toList()..sort();
  }

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/restaurants_cache.json');
  }

  static List<Restaurant> _parseRestaurantsInBackground(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Restaurant.fromMap(json)).toList();
  }

  Future<List<Restaurant>> _loadFromCache() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        return await compute(_parseRestaurantsInBackground, contents);
      }
    } catch (e) { debugPrint("Error reading cache: $e"); }
    return [];
  }

  Future<void> _fetchRestaurants() async {
    setState(() { 
      isLoading = true; 
      hasError = false; 
    });

    List<dynamic> fullList = []; 

    // 1. 🔍 TRY THE LOCAL CACHE FIRST (FULL OR PARTIAL)
    try {
      debugPrint("🔍 Checking local device cache...");
      final cachedRestaurants = await _loadFromCache();
      
      if (cachedRestaurants.length >= 36252) { 
        debugPrint("⚡ BOOM! Full cache found!");
        if (mounted) {
          setState(() {
            allRestaurants = cachedRestaurants;
            isLoading = false;
          });
        }
        return; 
      } else if (cachedRestaurants.isNotEmpty) {
        debugPrint("⚠️ Partial cache found (${cachedRestaurants.length}). Resuming fetch...");
        // Pre-populate UI with what we have for a seamless resume experience
        if (mounted) setState(() => allRestaurants = cachedRestaurants);
        // Load the raw JSON back into fullList to append the missing batches
        final file = await _localFile;
        fullList = jsonDecode(await file.readAsString());
      }
    } catch (e) {
      debugPrint("⚠️ Cache miss or error: $e");
    }

    // 2. ☁️ FETCH FROM SUPABASE (RESUMEABLE)
    try {
      debugPrint("☁️ Fetching from database...");
      
      const int totalRecords = 36252;
      const int batchSize = 1000;
      
      // Calculate starting page based on existing cached data
      int startPage = (fullList.length / batchSize).floor();
      int totalPages = (totalRecords / batchSize).ceil();

      // Initialize counters to the current progress point
      if (mounted) {
        setState(() {
          _fetchedCount = fullList.length;
          _displayFetchedCount = fullList.length;
          _totalToFetch = totalRecords;
        });
      }
      
      _startSimulationTimer();

      for (int i = startPage; i < totalPages; i++) {
        final start = i * batchSize;
        final end = start + batchSize - 1;
        
        final batch = await Supabase.instance.client
            .from('restaurants')
            .select() 
            .range(start, end)
            .order('id', ascending: true); 
            
        fullList.addAll(batch as List<dynamic>);
        
        if (mounted) {
          setState(() {
            _fetchedCount = fullList.length; 
          });
        }
      }

      // 🛑 STOP THE SIMULATION WHEN FETCHING IS COMPLETELY DONE
      _simulationTimer?.cancel();
      if (mounted) {
        setState(() {
          _displayFetchedCount = 36252; 
        });
      }

      await _saveToCache(fullList);

      final List<Restaurant> mappedRestaurants = await compute(parseRestaurantsInBackground, fullList);

      if (mounted) {
        setState(() {
          allRestaurants = mappedRestaurants;
          isLoading = false;
          hasError = false;
        });
      }
      
    } catch (e) {
      debugPrint('🚨 ERROR FETCHING RESTAURANTS: $e');
      
      // 3. 🛡️ SALVAGE LOGIC: If connection drops, use what we managed to grab
      _simulationTimer?.cancel(); 

      if (fullList.isNotEmpty) {
        debugPrint('⚠️ Connection lost, but salvaging ${fullList.length} spots!');
        
        await _saveToCache(fullList);
        final List<Restaurant> partialRestaurants = await compute(parseRestaurantsInBackground, fullList);
        
        if (mounted) {
          setState(() {
            allRestaurants = partialRestaurants;
            isLoading = false;
            hasError = false; 
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Connection lost. Showing partial map data."),
              backgroundColor: isDarkMode ? Colors.redAccent : Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() { 
            isLoading = false; 
            hasError = true; 
          });
        }
      }
    }
  }

  void _startSimulationTimer() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        // Cap the fake counter so it never passes the ACTUAL fetched data + 950
        int maxSimulated = _fetchedCount + 950; 
        if (_displayFetchedCount < maxSimulated && _displayFetchedCount < 36252) {
          _displayFetchedCount += Random().nextInt(34) + 12; 
          if (_displayFetchedCount > 36252) _displayFetchedCount = 36252;
        }
      });
    });
  }

  Future<void> _fetchUserProfile({bool forceRefresh = false}) async {
    final data = await PassportService.fetchUserProfile(forceRefresh: forceRefresh);
    
    if (mounted && data != null) {
      setState(() {
        _userPhotoUrl = data['photo_url'];
        _userName = data['display_name'];
        _userGender = data['gender'];
        _userAge = data['age'];
      });
    }
  }

  List<Restaurant> get visibleRestaurants {
    return allRestaurants.where((r) {
      if (savedOnly && !savedRestaurantNames.contains(r.name)) return false;
      if (showOpenOnly && !r.isOpenNow) return false;
      if (_showVegetarian && !r.isVegetarian) return false;
      if (_showVegan && !r.isVegan) return false;

      if (_selectedMichelin.isNotEmpty) {
        bool matches = false;
        if (_selectedMichelin.contains("1 Star") && r.michelinStars == 1) matches = true;
        if (_selectedMichelin.contains("2 Stars") && r.michelinStars == 2) matches = true;
        if (_selectedMichelin.contains("3 Stars") && r.michelinStars == 3) matches = true;
        if (_selectedMichelin.contains("Bib Gourmand") && r.bibGourmand) matches = true;
        if (!matches) return false;
      }

      if (_selectedPrices.isNotEmpty && !_selectedPrices.contains(r.price)) return false;

      if (selectedRestaurantName != null && !r.name.toLowerCase().contains(selectedRestaurantName!.toLowerCase())) return false;
      if (selectedCategory != null && !r.cuisine.toLowerCase().contains(selectedCategory!.toLowerCase())) return false;
      
      return true;
    }).toList();
  }

  // 🌟 NEW: Dedicated jump method with Cupertino spinner
  Future<void> _jumpToRestaurant(Restaurant restaurant) async {
    setState(() { _isJumpingToLocation = true; });

    // Give UI thread a breather to render the Cupertino spinner
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() { 
        selectedRestaurantName = restaurant.name; 
        selectedCategory = null; 
      });
      _zoomToResults(visibleRestaurants);
    }

    // Give map tiles time to load into memory
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() { _isJumpingToLocation = false; });
      
      // Auto-open the detail sheet for the premium feel
      showModalBottomSheet(
        context: context, 
        isScrollControlled: true, 
        useSafeArea: true, 
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        builder: (context) => RestaurantDetailSheet(
          restaurant: restaurant, 
          isDarkMode: isDarkMode, 
          isSaved: savedRestaurantNames.contains(restaurant.name),
          myLocation: myLocation, 
          onFavoriteToggle: () => _toggleFavorite(restaurant.name),
        ),
      );
    }
  }
  
  void _openSearchPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          allRestaurants: allRestaurants,
          availableCategories: dynamicCuisines,
          isDarkMode: isDarkMode,
          onCategorySelected: (category) {
            setState(() { selectedCategory = category; selectedRestaurantName = null; });
            _zoomToResults(visibleRestaurants);
          },
          onRestaurantSelected: (restaurant) {
            _jumpToRestaurant(restaurant); // 🌟 Implemented here
          },
        ),
      ),
    );
  }

  void _openCountryWheel() {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => CountryWheelModal(
        isDarkMode: isDarkMode,
        availableCuisines: dynamicCuisines, 
        onCountrySelected: (country) {
          setState(() { selectedCategory = country; selectedRestaurantName = null; });
          _zoomToResults(visibleRestaurants);
        },
      ),
    );
  }

  void _zoomToResults(List<Restaurant> restaurants) {
    if (restaurants.isEmpty) return;
    if (restaurants.length == 1) { _animatedMapMove(restaurants.first.location, 15.0); return; }
    
    final bounds = LatLngBounds.fromPoints(restaurants.map((r) => r.location).toList());
    try { _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80))); } 
    catch (e) { _animatedMapMove(restaurants.first.location, 14.0); }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    final controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    final Animation<double> animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.move(LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)), zoomTween.evaluate(animation));
    });

    animation.addStatusListener((status) { if (status == AnimationStatus.completed) controller.dispose(); });
    controller.forward();
  }

  void _recenterMap() {
    if (myLocation != null) _animatedMapMove(myLocation!, 15.0);
    else { _animatedMapMove(const LatLng(40.735, -73.99), 13.0); _showLocationDialog(); }
  }

  void _zoom(double amount) {
    _animatedMapMove(_mapController.camera.center, _mapController.camera.zoom + amount);
  }

  String _getNoResultsMessage() {
    if (selectedCategory != null) return "We couldn't find any $selectedCategory places.";
    return "Try adjusting your filters.";
  }

  void _startTextAnimation() {
    _textTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (selectedCategory == null && selectedRestaurantName == null) {
        if (mounted) setState(() => _currentPhraseIndex = (_currentPhraseIndex + 1) % _searchPhrases.length);
      }
    });
  }

  List<Marker> _buildMarkers() {
    return visibleRestaurants.map((restaurant) {
      return Marker(
        point: restaurant.location, width: 50, height: 50,
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context, isScrollControlled: true, useSafeArea: true, clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
              backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              builder: (context) => RestaurantDetailSheet(
                restaurant: restaurant, isDarkMode: isDarkMode, isSaved: savedRestaurantNames.contains(restaurant.name),
                myLocation: myLocation, onFavoriteToggle: () => _toggleFavorite(restaurant.name),
              ),
            );
          },
          child: Icon(Icons.location_on, color: isDarkMode ? Colors.white : Colors.black, size: 50, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
        ),
      );
    }).toList();
  }

  String _formatClusterCount(int count) => count < 1000 ? count.toString() : '${(count / 1000).floor()}k+';

  Widget _buildAvatarContent() {
    if (_userName == null) {
      return const Center(
        child: SizedBox(
          width: 14, height: 14, 
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
        )
      );
    }

    if (_userPhotoUrl == null || _userPhotoUrl!.isEmpty) {
      return Icon(Icons.person, size: 20, color: Colors.grey[600]);
    }

    if (!_userPhotoUrl!.startsWith('http')) {
      return Image.file(
        File(_userPhotoUrl!), 
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.person, size: 20, color: Colors.grey[600]);
        },
      );
    }

    return Image.network(
      _userPhotoUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
          )
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.person, size: 20, color: Colors.grey[600]);
      },
    );
  }

  Widget _buildSystemStatus() {
    if (!_isOffline && !_isGpsDisabled) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: _isOffline ? const Color(0xFFD32F2F) : const Color(0xFFFFA000), 
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isOffline ? Icons.wifi_off : Icons.location_disabled, 
              color: Colors.white, 
              size: 16
            ),
            const SizedBox(width: 8),
            Text(
              _isOffline ? "YOU ARE OFFLINE" : "LOCATION SERVICES DISABLED",
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold, 
                fontSize: 12,
                letterSpacing: 1.0
              ),
            ),
            if (!_isOffline && _isGpsDisabled) ...[
               const SizedBox(width: 12),
               GestureDetector(
                 onTap: Geolocator.openLocationSettings,
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                   decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                   child: const Text("ENABLE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                 ),
               )
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _saveToCache(List<dynamic> jsonList) async {
    try {
      final file = await _localFile;
      final jsonString = jsonEncode(jsonList);
      await file.writeAsString(jsonString);
      debugPrint("💾 SUCCESS: Saved ${jsonList.length} restaurants to local device storage!");
    } catch (e) {
      debugPrint("🚨 Error saving to cache: $e");
    }
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_tutorial') ?? false;

    if (!hasSeen) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _showTutorial();
      });
    }
  }

  void _showTutorial() {
    TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black, 
      paddingFocus: 10,
      opacityShadow: 0.9, 
      hideSkip: true, 
      onFinish: () {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('has_seen_tutorial', true);
        });
      },
      onSkip: () {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('has_seen_tutorial', true);
        });
        return true; 
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "search_target",
        keyTarget: _searchKey,
        shape: ShapeLightFocus.RRect, 
        radius: 10, 
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: _buildTutorialText("THE VAULT", "17,000 hidden gems across all 5 boroughs.\n\nTap here to search or filter by Michelin stars, vegan, and more.", controller),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "wheel_target",
        keyTarget: _wheelKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildTutorialText("THE SPIN", "Can't decide? Spin the global wheel and let fate choose your next cuisine.", controller),
          ),
        ],
      ),
      TargetFocus(
        identify: "passport_target",
        keyTarget: _passportKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildTutorialText("THE COLLECTION", "Your Gourmet Passport. Check in to spots, collect official stamps, and build your culinary visa.", controller),
          ),
        ],
      ),
      TargetFocus(
        identify: "profile_target",
        keyTarget: _profileKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: _buildTutorialText("THE DIPLOMAT", "Upgrade your status. Manage your records, official ID photo, and passports here.", controller, isLast: true),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildTutorialText(String title, String description, TutorialCoachMarkController controller, {bool isLast = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title, 
          style: const TextStyle(
            fontFamily: 'AppleGaramond', 
            fontWeight: FontWeight.bold, 
            color: Colors.white, 
            fontSize: 32, 
            letterSpacing: 1.5
          )
        ),
        const SizedBox(height: 12),
        Text(
          description, 
          style: const TextStyle(
            color: Colors.white70, 
            fontSize: 18, 
            height: 1.4,
            fontWeight: FontWeight.w500,
          )
        ),
        const SizedBox(height: 28), 
        
        Row(
          children: [
            ElevatedButton(
              onPressed: () => isLast ? controller.skip() : controller.next(), 
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(
                isLast ? "DONE" : "NEXT", 
                style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14)
              ),
            ),
            const SizedBox(width: 20),
            
            if (!isLast)
              GestureDetector(
                onTap: () => controller.skip(),
                child: const Text(
                  "SKIP TUTORIAL", 
                  style: TextStyle(
                    fontFamily: 'Courier', 
                    color: Colors.white54, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 12, 
                    letterSpacing: 1.0
                  )
                ),
              ),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat, 
      body: Stack(
        children: [
          // --- MAP LAYER ---
          GestureDetector(
            onDoubleTapDown: (details) {
              final latlng = _mapController.camera.pointToLatLng(Point(details.localPosition.dx, details.localPosition.dy));
              _animatedMapMove(latlng, min(_mapController.camera.zoom + 1, 18.0));
            },
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: const LatLng(40.735, -73.99), initialZoom: 12.5, backgroundColor: Colors.transparent, interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.doubleTapZoom)),
              children: [
                TileLayer(
                  urlTemplate: isDarkMode ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png' : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                  subdomains: const ['a', 'b', 'c'], retinaMode: true,
                  tileProvider: CachedTileProvider(), 
                ),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45, size: const Size(40, 40), alignment: Alignment.center, padding: const EdgeInsets.all(50),
                    markers: _buildMarkers(),
                    onClusterTap: (cluster) => _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(cluster.markers.map((m) => m.point).toList()), padding: const EdgeInsets.all(50))),
                    builder: (context, markers) => Container(
                      decoration: BoxDecoration(color: isDarkMode ? Colors.white : Colors.black, shape: BoxShape.circle, border: Border.all(color: isDarkMode ? Colors.black : Colors.white, width: 2)),
                      child: Center(child: FittedBox(child: Padding(padding: const EdgeInsets.all(4.0), child: Text(_formatClusterCount(markers.length), style: TextStyle(color: isDarkMode ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 14))))),
                    ),
                  ),
                ),
                if (myLocation != null) MarkerLayer(markers: [Marker(point: myLocation!, width: 20, height: 20, child: Container(decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)])))]),
              ],
            ),
          ),

          // 🌟 NEW: FIRST LOAD PREMIUM PROGRESS BAR
          if (isLoading && allRestaurants.isEmpty)
            Positioned.fill(
              child: Container(
                color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF9F9F9),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CupertinoActivityIndicator(radius: 14),
                      const SizedBox(height: 16),
                      // ... inside the first load loading block
                      SizedBox(
                        width: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            // 👈 UPDATE THIS TO USE THE DISPLAY COUNT
                            value: _displayFetchedCount / 36252, 
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDarkMode ? Colors.white : Colors.black,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        // 👈 UPDATE THIS TO USE THE DISPLAY COUNT
                        "Fetching $_displayFetchedCount of 36252 restaurants...",
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // --- EMPTY STATE ---
          if (!isLoading && !hasError && visibleRestaurants.isEmpty)
             Positioned.fill(
              child: Stack(
                children: [
                  BackdropFilter(filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), child: Container(color: Colors.black.withOpacity(0.0))),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E1E1E).withOpacity(0.85) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(25), border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white54, width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, spreadRadius: 10)]),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.explore_off_rounded, size: 48, color: isDarkMode ? Colors.grey[400] : Colors.grey[500]),
                          const SizedBox(height: 16),
                          Text("No Spots Found", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: isDarkMode ? Colors.white : Colors.black)),
                          const SizedBox(height: 8),
                          Text(_getNoResultsMessage(), textAlign: TextAlign.center, style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600], fontSize: 16)),
                          const SizedBox(height: 24),
                          TextButton(
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), backgroundColor: isDarkMode ? Colors.white : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                            onPressed: () => setState(() { selectedCategory = null; selectedRestaurantName = null; _selectedMichelin.clear(); _selectedPrices.clear(); showOpenOnly = false; savedOnly = false; _showVegetarian = false; _showVegan = false; _fetchRestaurants(); }),
                            child: Text("Clear Filters", style: TextStyle(color: isDarkMode ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // --- LOADING / ERROR ---
          if (hasError) Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.wifi_off, size: 64, color: Colors.grey), const SizedBox(height: 16), const Text("No Connection", style: TextStyle(fontSize: 20)), ElevatedButton(onPressed: _fetchRestaurants, child: const Text("Retry"))])),
          
          // --- UI: SEARCH & FILTER BAR ---
          if (!hasError)
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SafeArea(
                child: Column(
                  children: [
                    GestureDetector(
                      key: _searchKey, 
                      onTap: _openSearchPage,
                      child: Container(
                        margin: const EdgeInsets.all(16), 
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, 
                          borderRadius: BorderRadius.circular(10), 
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))]
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: isDarkMode ? Colors.white : Colors.black),
                            const SizedBox(width: 8),
                            
                            Expanded(
                              child: (selectedCategory == null && selectedRestaurantName == null)
                                  ? SizedBox(
                                      height: 24, 
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 800), 
                                        child: Text(
                                          _searchPhrases[_currentPhraseIndex], 
                                          key: ValueKey(_searchPhrases[_currentPhraseIndex]), 
                                          style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)
                                        )
                                      )
                                    )
                                  : Text(
                                      selectedRestaurantName != null ? "Searching: \"$selectedRestaurantName\"" : "Filtering: $selectedCategory", 
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold), 
                                      overflow: TextOverflow.ellipsis
                                    ),
                            ),

                            if (selectedCategory != null || selectedRestaurantName != null)
                              GestureDetector(
                                onTap: () => setState(() { selectedCategory = null; selectedRestaurantName = null; }), 
                                child: Container(
                                  padding: const EdgeInsets.all(4), 
                                  margin: const EdgeInsets.only(left: 8), 
                                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), shape: BoxShape.circle), 
                                  child: Icon(Icons.close, size: 16, color: isDarkMode ? Colors.white : Colors.black)
                                )
                              ),

                            const SizedBox(width: 8),

                            GestureDetector(
                              key: _profileKey, 
                              onTap: () async {
                                await openProfileScreen(
                                  context, 
                                  name: _userName,
                                  photoUrl: _userPhotoUrl,
                                  gender: _userGender,
                                  age: _userAge
                                );
                                
                                await _fetchUserProfile(forceRefresh: true);
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: ClipOval(
                                  child: _buildAvatarContent(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    _buildSystemStatus(),

                    MapFilterBar(
                      isDarkMode: isDarkMode,
                      showOpenOnly: showOpenOnly,
                      savedOnly: savedOnly,
                      showVegetarian: _showVegetarian,
                      showVegan: _showVegan,
                      selectedMichelin: _selectedMichelin,
                      selectedPrices: _selectedPrices,
                      onOpenChanged: (v) { setState(() => showOpenOnly = v); _fetchRestaurants(); },
                      onSavedChanged: (v) => setState(() => savedOnly = v),
                      onVegChanged: (v) => setState(() => _showVegetarian = v),
                      onVeganChanged: (v) => setState(() => _showVegan = v),
                      onMichelinChanged: (v) => setState(() => _selectedMichelin = v),
                      onPriceChanged: (v) => setState(() => _selectedPrices = v),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- BOTTOM RIGHT BUTTONS ---
          if (!hasError)
          Align(
            alignment: Alignment.bottomRight,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0, bottom: 30.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton(key: _wheelKey, mini: true, heroTag: "wheel_btn", backgroundColor: isDarkMode ? Colors.indigoAccent : Colors.deepPurpleAccent, foregroundColor: Colors.white, elevation: 6, onPressed: _openCountryWheel, child: const Icon(Icons.casino)),
                    const SizedBox(height: 12),
                    FloatingActionButton(mini: true, heroTag: "theme_btn", backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white, foregroundColor: isDarkMode ? Colors.white : Colors.black, elevation: 4, onPressed: _toggleTheme, child: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode)),
                    FloatingActionButton(mini: true, heroTag: "gps_btn", backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white, foregroundColor: isDarkMode ? Colors.white : Colors.black, elevation: 4, onPressed: _recenterMap, child: Icon(myLocation == null ? CupertinoIcons.location_slash_fill : CupertinoIcons.location_fill)),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(color: isDarkMode ? Colors.grey[800] : Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(Icons.add, color: isDarkMode ? Colors.white : Colors.black), onPressed: () => _zoom(1)), Container(height: 1, width: 30, color: Colors.grey.withOpacity(0.3)), IconButton(icon: Icon(Icons.remove, color: isDarkMode ? Colors.white : Colors.black), onPressed: () => _zoom(-1))]),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🌟 NEW: JUMPING TO LOCATION OVERLAY
          if (_isJumpingToLocation)
            Positioned.fill(
              child: Container(
                color: isDarkMode ? Colors.black54 : Colors.white54, 
                child: const Center(
                  child: CupertinoActivityIndicator(radius: 16),
                ),
              ),
            ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        key: _passportKey, 
        backgroundColor: Colors.amber,
        child: const Icon(Icons.filter_none, color: Colors.black),
        onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PassportCollectionScreen(
                    initialBookId: null, 
                  )
                ),
              );
            },
      ),
    );
  }
}

// 🛠️ THIS MUST LIVE OUTSIDE OF ANY CLASS
List<Restaurant> parseRestaurantsInBackground(List<dynamic> responseData) {
  return responseData.map((json) => Restaurant.fromMap(json)).toList();
}