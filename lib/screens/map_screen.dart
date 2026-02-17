import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
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
import 'auth_screen.dart'; // <--- Add this
import 'profile_edit_screen.dart'; // 👈 Import new file
import 'passport_collection_screen.dart'; // 👈 Import the collection
import '../services/passport_service.dart'; // 👈 Import the service
import 'package:connectivity_plus/connectivity_plus.dart'; // 👈 NEW
import '../services/tile_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();

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

  bool _isCheckingLocation = false;

  bool _showVegetarian = false;
  bool _showVegan = false;

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusStreamSubscription;

  final Set<String> _savedRestaurants = {};

  // 🔌 CONNECTIVITY STATE
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isGpsDisabled = false; // Tracks if the System Toggle is off

  // Inside _MapScreenState class:
  // 👇 ADD THESE 4 LINES HERE
  String? _userPhotoUrl;
  String? _userName;
  String? _userGender;
  int? _userAge;

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

    // 🔌 START LISTENING
    _initConnectivityListener();

    // 🚀 STEP 1: LOAD EVERYTHING INSTANTLY
    _fastBootSequence();
  }

  Future<void> _safeInit() async {
    _fetchUserProfile(); // 👈 Add this call
    PassportService.prewarmCache();

    await _loadTheme();
    await _loadFavorites();
    await _fetchRestaurants();
    
    _initLocationService();


  }

  @override
  void dispose() {
    _textTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSubscription?.cancel();
    _serviceStatusStreamSubscription?.cancel();
    _connectivitySubscription?.cancel(); // 👈 Don't forget this!
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
    // 1. Load Theme & Ghost Location (Instant)
    _loadTheme();
    await _loadCachedLocation(); 

    // 2. Fetch Data
    _fetchUserProfile();
    PassportService.prewarmCache();
    await _loadFavorites();
    await _fetchRestaurants();
    
    // 3. Start GPS
    _initLocationService();

    // 🕵️ BACKGROUND TASK: PRE-LOAD DARK MAP
    // We wait 3 seconds so we don't slow down the initial UI animation
    Future.delayed(const Duration(seconds: 3), () {
      // Coordinates: NYC (40.735, -73.99) | isDarkMode: true
      MapHeater.preCacheTiles(40.735, -73.99, true); 
      debugPrint("🌑 Dark Mode Map warming up in background...");
    });
  }

  // 💾 NEW: CACHE LOADER (The Speed Trick)
  Future<void> _loadCachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final double? lat = prefs.getDouble('last_known_lat');
    final double? lng = prefs.getDouble('last_known_lng');

    if (lat != null && lng != null) {
      if (mounted) {
        setState(() {
          myLocation = LatLng(lat, lng);
        });
        // 🎥 MOVE CAMERA INSTANTLY TO GHOST LOCATION
        // We do this via a slight delay to ensure the map widget is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(myLocation!, 14.0);
        });
      }
    }
  }

  // 💾 NEW: CACHE SAVER
  Future<void> _saveLocationToCache(LatLng position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_known_lat', position.latitude);
    await prefs.setDouble('last_known_lng', position.longitude);
  }

  void _initConnectivityListener() {
    // 1. Check current status
    Connectivity().checkConnectivity().then((results) {
       _updateConnectionStatus(results);
    });

    // 2. Listen for changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    
    // 3. Listen for GPS Toggle (Service Status)
    _serviceStatusStreamSubscription = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (mounted) {
        setState(() {
          _isGpsDisabled = (status == ServiceStatus.disabled);
          if (_isGpsDisabled) myLocation = null; // Hide the blue dot
        });
      }
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // If ANY result is not 'none', we have connection.
    bool hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (mounted) {
      setState(() => _isOffline = !hasConnection);
    }
  }

  // --- THEME & FAVORITES ---
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

  // --- LOCATION SERVICES ---
  Future<void> _checkLocationOnResume() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted && myLocation == null) _showLocationDialog();
    else _checkPermissionAndListen();
  }

  // 📡 UPDATED LOCATION SERVICE
  Future<void> _initLocationService() async {
    // Check if permission is already granted from previous run
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      _startListening();
    } else {
      // Only ask if we really need to (don't block the UI)
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
    // 1. Try Native Last Known (Backup to our cache)
    Geolocator.getLastKnownPosition().then((pos) {
      if (pos != null && myLocation == null) {
         setState(() => myLocation = LatLng(pos.latitude, pos.longitude));
      }
    });

    // 2. Start the Real Stream
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
    ).listen((Position position) {
      final newLoc = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() { myLocation = newLoc; });
        // 💾 SAVE IT FOR NEXT TIME
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

  // --- DATA ---
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

  // 🌟 NEW: ISOLATE FUNCTION (Must be static or top-level)
  static List<Restaurant> _parseRestaurantsInBackground(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Restaurant.fromMap(json)).toList();
  }

  Future<List<Restaurant>> _loadFromCache() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        // 🌟 OPTIMIZATION: Parse in background thread
        return await compute(_parseRestaurantsInBackground, contents);
      }
    } catch (e) { debugPrint("Error reading cache: $e"); }
    return [];
  }

  // 🌟 OPTIMIZED: PARALLEL FETCHING
  Future<void> _fetchRestaurants() async {
    setState(() { isLoading = true; hasError = false; });

    // 1. Try Cache First
    final cachedData = await _loadFromCache();
    if (cachedData.isNotEmpty) {
      setState(() { allRestaurants = cachedData; isLoading = false; });
    }

    try {
      // 2. Fetch Fresh Data (Parallelized)
      // First, fetch the COUNT to know how many pages we need
      // ADD THIS:
      final int totalCount = await Supabase.instance.client
        .from('restaurants')
        .count();
      const int batchSize = 1000;
      final int totalPages = (totalCount / batchSize).ceil();

      // Create a list of Futures (requests) to fire simultaneously
      List<Future<List<dynamic>>> futures = [];
      for (int i = 0; i < totalPages; i++) {
        final start = i * batchSize;
        final end = start + batchSize - 1;
        futures.add(
          Supabase.instance.client
              .from('restaurants')
              .select()
              .range(start, end)
              .then((value) => value as List<dynamic>)
        );
      }

      // Wait for ALL requests to finish (Parallel execution)
      final List<List<dynamic>> results = await Future.wait(futures);
      
      // Flatten the list
      final List<dynamic> fullList = results.expand((x) => x).toList();

      if (fullList.isNotEmpty) {
        // Save to cache (raw JSON)
        final file = await _localFile;
        await file.writeAsString(jsonEncode(fullList));

        // Parse in background
        final parsed = await compute(_parseRestaurantsInBackground, jsonEncode(fullList));

        if (mounted) {
          setState(() {
            allRestaurants = parsed;
            isLoading = false;
            hasError = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted && allRestaurants.isEmpty) setState(() { isLoading = false; hasError = true; });
    }
  }

  // 🛠 FIX: Add forceRefresh parameter
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

  // --- ACTIONS ---
  
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
            setState(() { selectedRestaurantName = restaurant.name; selectedCategory = null; });
            _zoomToResults(visibleRestaurants);
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
        availableCuisines: dynamicCuisines, // <--- 🌟 PASS THE LIST HERE
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
    // 1. DATA LOADING
    if (_userName == null) {
      return const Center(
        child: SizedBox(
          width: 14, height: 14, 
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
        )
      );
    }

    // 2. NO PHOTO SAVED
    if (_userPhotoUrl == null || _userPhotoUrl!.isEmpty) {
      return Icon(Icons.person, size: 20, color: Colors.grey[600]);
    }

    // 3. LOCAL FILE (Guest Mode)
    if (!_userPhotoUrl!.startsWith('http')) {
      return Image.file(
        File(_userPhotoUrl!), 
        fit: BoxFit.cover,
        // 🛠 FIX: Fallback to Grey Icon if file is missing/corrupt
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.person, size: 20, color: Colors.grey[600]);
        },
      );
    }

    // 4. NETWORK IMAGE (User Mode)
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
      // 🛠 FIX: Fallback to Grey Icon if URL fails
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.person, size: 20, color: Colors.grey[600]);
      },
    );
  }

  // 🚨 SYSTEM STATUS BAR
  Widget _buildSystemStatus() {
    if (!_isOffline && !_isGpsDisabled) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: _isOffline ? const Color(0xFFD32F2F) : const Color(0xFFFFA000), // Red or Orange
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

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat, // Moves to Bottom Left
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
                  // 🌟 NEW: Restored Caching Provider
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
          if (isLoading) const Center(child: CircularProgressIndicator()),

          // --- UI: SEARCH & FILTER BAR ---
          if (!hasError)
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SafeArea(
                child: Column(
                  children: [
                    // Search Bar
                    GestureDetector(
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
                            // 1. SEARCH ICON
                            Icon(Icons.search, color: isDarkMode ? Colors.white : Colors.black),
                            const SizedBox(width: 8),
                            
                            // 2. TEXT (Takes remaining space)
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

                            // 3. CROSS ICON (Rendered LEFT of Profile)
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

                            // 4. SPACER
                            const SizedBox(width: 8),

                            // 5. PROFILE AVATAR (Far Right)
                            GestureDetector(
                              onTap: () async {
                                // Open the profile
                                await openProfileScreen(
                                  context, 
                                  name: _userName,
                                  photoUrl: _userPhotoUrl,
                                  gender: _userGender,
                                  age: _userAge
                                );
                                
                                // 🛠 FIX: Aggressively force a fresh pull from the DB/Cache
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

                    // 🚨 INSERT HERE:
                    _buildSystemStatus(),

                    // Filter Bar
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
                    FloatingActionButton(mini: true, heroTag: "wheel_btn", backgroundColor: isDarkMode ? Colors.indigoAccent : Colors.deepPurpleAccent, foregroundColor: Colors.white, elevation: 6, onPressed: _openCountryWheel, child: const Icon(Icons.casino)),
                    const SizedBox(height: 12),
                    FloatingActionButton(mini: true, heroTag: "theme_btn", backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white, foregroundColor: isDarkMode ? Colors.white : Colors.black, elevation: 4, onPressed: _toggleTheme, child: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode)),
                    FloatingActionButton(mini: true, heroTag: "gps_btn", backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white, foregroundColor: isDarkMode ? Colors.white : Colors.black, elevation: 4, onPressed: _recenterMap, child: Icon(myLocation == null ? Icons.location_disabled : Icons.my_location)),
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
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        child: const Icon(Icons.filter_none, color: Colors.black),
        onPressed: () {
              // 🔓 UNLOCKED LOGIC
              // We removed the "if (session != null)" check.
              // Now, EVERYONE (even guests) gets to enter the Passport Screen.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PassportCollectionScreen(
                    initialBookId: null, // Guests will auto-load the 'Ghost Book'
                  )
                ),
              );
            },
      ),
    );
  }

}
