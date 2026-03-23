import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// 🌟 FIX 1: Added 'as geo' to prevent collisions with Mapbox's Position class
import 'package:geolocator/geolocator.dart' as geo; 
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:nyc_eats/config/cuisine_constants.dart';
import 'package:nyc_eats/models/restaurant.dart';
import 'package:nyc_eats/services/pill_cache.dart';
import 'package:nyc_eats/services/vault_builder.dart';
import 'package:nyc_eats/widgets/restaurant_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- IMPORTS ---
import '../widgets/country_wheel_modal.dart';
import 'search_screen.dart';
import 'profile_edit_screen.dart'; 
import 'passport_collection_screen.dart'; 
import '../services/passport_service.dart'; 
import 'package:connectivity_plus/connectivity_plus.dart'; 
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart'; // Required for HapticFeedback
import '../widgets/map_filter_bar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  MapboxMap? _mapboxController;

  bool _isJumpingToLocation = false;
  bool _isBuildingVault = false;
  bool _hasPerformedInitialCameraFly = false;
  Map<String, String>? _vaultPaths; // 👈 Changed from String? _localVaultPath

  // --- STATE VARIABLES ---
  bool isDarkMode = false;
  
  String? selectedCategory;
  String? selectedRestaurantName;
  LatLng? myLocation;
  
  // Start closer to the target to save network bandwidth on startup
  final CameraOptions initialCamera = CameraOptions(
    center: Point(coordinates: Position(-73.99, 40.75)), 
    zoom: 9.0, // Reduced from 1.0
    pitch: 0.0,
  );
  // The target destination: Mid-Manhattan in flat 2D
  final CameraOptions targetCamera = CameraOptions(
    center: Point(coordinates: Position(-73.98, 40.75)), // Centered exactly on Manhattan
    zoom: 11.5, // The exact zoom level from your screenshot
    pitch: 0.0, // Flat
    bearing: 0.0, // Pointing straight North
  );

  bool _isCheckingLocation = false;

  // 🌟 FIX 1: Applied 'geo.' prefix
  StreamSubscription<geo.Position>? _positionStreamSubscription;
  StreamSubscription<geo.ServiceStatus>? _serviceStatusStreamSubscription;

  Set<String> savedRestaurantNames = {};
  
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isGpsDisabled = false; 

  String? _userPhotoUrl;
  String? _userName;
  String? _userGender;
  int? _userAge;

  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _wheelKey = GlobalKey();
  final GlobalKey _passportKey = GlobalKey();

  int _currentPhraseIndex = 0;
  Timer? _textTimer;
  final List<String> _searchPhrases = [
    "Hungry?", "Nom nom nom...", "Where to next?", "Craving something?", "Let's eat!", "Find a hidden gem..."
  ];

  // --- FILTER STATE ---
  bool showOpenOnly = false;
  bool savedOnly = false;
  bool _showVegetarian = false;
  bool _showVegan = false;
  Set<String> _selectedMichelin = {};
  Set<String> _selectedPrices = {};
  
  Map<String, String> _restaurantHours = {};

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
    _initLocationService();
  }

  @override
  void dispose() {
    _textTimer?.cancel();
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
      }
    }
  }

  Future<void> _fastBootSequence() async {
    _loadTheme();
    await _loadCachedLocation(); 

    _fetchUserProfile();
    PassportService.prewarmCache();
    await _loadFavorites(); 
    
    if (mounted) setState(() => _isBuildingVault = true);
    try {
      // 🌟 THE FIX: Force it to true just for this run to download the hours!
      // (You can change this back to false tomorrow)
      _vaultPaths = await VaultBuilder.buildVaultIfNeeded();
      
      if (_vaultPaths != null && _vaultPaths!['hours'] != null) {
        final hoursFile = File(_vaultPaths!['hours']!);
        if (await hoursFile.exists()) {
          final hoursStr = await hoursFile.readAsString();
          
          // 🌟 THE FIX: Pass jsonDecode to a background isolate!
          final decoded = await compute(jsonDecode, hoursStr) as Map<String, dynamic>; 
          
          _restaurantHours = decoded.map((key, value) => MapEntry(key, value.toString()));
        }
      }
      if (_mapboxController != null && _vaultPaths != null) {
        _setupMapboxLayers(_vaultPaths!); 
      }
    } catch (e) {
      debugPrint("🚨 Vault creation failed: $e");
    } finally {
      if (mounted) setState(() => _isBuildingVault = false);
    }
    
    _initLocationService();
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
    
    _serviceStatusStreamSubscription = geo.Geolocator.getServiceStatusStream().listen((geo.ServiceStatus status) {
      if (mounted) {
        setState(() {
          _isGpsDisabled = (status == geo.ServiceStatus.disabled);
          if (_isGpsDisabled) myLocation = null; 
        });
      }
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    bool hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (mounted) {
      setState(() => _isOffline = !hasConnection);
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

    // 🌟 THE FIX: Instantly command Mapbox to swap the base tiles.
    // We use STANDARD for the colorful light mode, and DARK for dark mode.
    if (_mapboxController != null) {
      _mapboxController!.loadStyleURI(
        isDarkMode ? MapboxStyles.DARK : MapboxStyles.STANDARD
      );
    }
  }

  Future<void> _checkLocationOnResume() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted && myLocation == null) _showLocationDialog();
    else _checkPermissionAndListen();
  }

  Future<void> _initLocationService() async {
    final permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.whileInUse || permission == geo.LocationPermission.always) {
      _startListening();
    } else {
      _checkPermissionAndListen();
    }
  }

  Future<void> _checkPermissionAndListen() async {
    if (_isCheckingLocation) return;
    _isCheckingLocation = true;
    try {
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) return;
      }
      if (permission == geo.LocationPermission.deniedForever) return;
      
      _startListening();
    } finally {
      _isCheckingLocation = false;
    }
  }

  void _startListening() {
    geo.Geolocator.getLastKnownPosition().then((pos) {
      if (pos != null && myLocation == null) {
         setState(() => myLocation = LatLng(pos.latitude, pos.longitude));
      }
    });

    _positionStreamSubscription = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.high, distanceFilter: 10)
    ).listen((geo.Position position) {
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
          TextButton(child: const Text("Turn On"), onPressed: () { Navigator.pop(context); geo.Geolocator.openLocationSettings(); }),
        ],
      ),
    );
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
  
  // map_screen.dart

  void _openSearchPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          // ⚠️ We no longer pass allRestaurants!
          // We pass the static categories from your constants
          availableCategories: CuisineConstants.emojiPalettes.keys.toList(), 
          isDarkMode: isDarkMode,
          onCategorySelected: (category) {
            setState(() { selectedCategory = category; selectedRestaurantName = null; });
            _fetchRestaurants(); // 🌟 ADD THIS
          },
          onRestaurantSelected: (restaurant) {
            setState(() { selectedRestaurantName = restaurant.name; selectedCategory = null; }); // Make sure state is updated
            _fetchRestaurants(); // 🌟 ADD THIS
            _jumpToRestaurant(restaurant);
          },
        ),
      ),
    );
  }

  Future<void> _jumpToRestaurant(Restaurant restaurant) async {
    // Uses setCamera instead of flyTo to instantly snap to the coordinates
    _mapboxController?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(restaurant.location.longitude, restaurant.location.latitude)),
        zoom: 16.0,
      ),
    );
    _fetchAndShowRestaurant(restaurant.id);
  }

  void _openCountryWheel() {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => CountryWheelModal(
        isDarkMode: isDarkMode,
        availableCuisines: const [], // Empty for now
        onCountrySelected: (country) {
          setState(() { selectedCategory = country; selectedRestaurantName = null; });
          _fetchRestaurants(); // 🌟 ADD THIS
        },
      ),
    );
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
     _mapboxController?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(destLocation.longitude, destLocation.latitude)),
          zoom: destZoom,
        ),
        MapAnimationOptions(duration: 1500)
     );
  }

  // 🌟 ADD THIS HELPER TO MAP SCREEN
  String _formatCategoryDisplay(String category) {
    String formatted = category.split('_').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
    String emoji = CuisineConstants.emojiPalettes[category]?.first ?? '🍽️';
    if (category.toLowerCase() == 'hot_dog') emoji = '🌭';
    return '$formatted $emoji';
  }

  void _recenterMap() {
    if (myLocation != null) _animatedMapMove(myLocation!, 15.0);
    else { _animatedMapMove(const LatLng(40.735, -73.99), 13.0); _showLocationDialog(); }
  }

  void _zoom(double amount) {
    if (_mapboxController != null) {
      _mapboxController!.getCameraState().then((cameraState) {
        final currentZoom = cameraState.zoom;
        _mapboxController!.flyTo(
          CameraOptions(zoom: currentZoom + amount),
          MapAnimationOptions(duration: 300)
        );
      });
    }
  }

  void _startTextAnimation() {
    _textTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (selectedCategory == null && selectedRestaurantName == null) {
        if (mounted) setState(() => _currentPhraseIndex = (_currentPhraseIndex + 1) % _searchPhrases.length);
      }
    });
  }

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
                 onTap: geo.Geolocator.openLocationSettings,
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

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();

    final String? stage = prefs.getString('tutorial_stage');
    if (stage == 'final_map_screen') {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _showFinalTutorial();
      });
      return; 
    }

    final hasSeen = prefs.getBool('has_seen_tutorial') ?? false;
    if (hasSeen) return;

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _showTutorial();
    });
  }

  void _showFinalTutorial() {
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: "search_target_final",
          keyTarget: _searchKey,
          shape: ShapeLightFocus.RRect,
          radius: 10,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("THE JOURNEY BEGINS", style: TextStyle(fontFamily: 'AppleGaramond', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 32, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    const Text("Collect a stamp from your favourite restaurant! Try it out!\n\nWelcome to NYC Eats, and Happy Journey!", style: TextStyle(color: Colors.white70, fontSize: 18, height: 1.4, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: () {
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setBool('has_seen_tutorial', true);
                          prefs.remove('tutorial_stage'); 
                        });
                        controller.skip(); 
                      }, 
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                      child: const Text("FINISH TOUR", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
      ],
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.9,
      hideSkip: true,
    ).show(context: context);
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
          prefs.setString('tutorial_stage', 'collection_screen'); 
          _handlePassportTap(); 
        });
      },
      onSkip: () {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('has_seen_tutorial', true);
          prefs.remove('tutorial_stage'); 
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
              child: _buildTutorialText("THE VAULT", "36,000+ restaurants across all 5 boroughs.\n\nTap here to search or filter by Michelin stars, vegan, and more.", controller),
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
        identify: "profile_target",
        keyTarget: _profileKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: _buildTutorialText("THE DIPLOMAT", "Upgrade your status. Manage your records, official ID photo, and passports here.", controller), 
            ),
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
            builder: (context, controller) => _buildTutorialText("THE COLLECTION", "Your Gourmet Passport. Check in to spots, collect official stamps, and build your culinary visa.", controller, isLast: true), 
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
              onPressed: () => controller.next(), 
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

  Future<void> _handlePassportTap() async {
    final prefs = await SharedPreferences.getInstance();
    final bool showNote = prefs.getBool('show_traveler_note') ?? true;
    final String? tutorialStage = prefs.getString('tutorial_stage');

    if (!showNote || tutorialStage == 'collection_screen') {
      _navigateToPassport();
      return;
    }

    bool doNotShowAgain = true; 

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF1A1A1A), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFFF5F5F5)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "A Note to the Travelers",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'AppleGaramond',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF5F5F5), 
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              const Text(
                                "    No subscriptions. No ads.\n\n"
                                "    I am tired of apps charging \$4.99 a month for eternity just to make the ads go away, or locking basic functionality behind a paywall. The core of this app—exploring 36,000+ restaurants across New York City—will always be free. It is a labor of love for a city I deeply admire, and a service for the people who make it great.\n\n"
                                "    Collecting visas and immigration stamps is also free (limited to 4 on the Wild Card Visa page). If you wish to expand your collection, you can purchase a new Passport, and you will own it forever.\n\n"
                                "    No hidden charges. No other BS. Just how a real passport works. Your visas and stamps are yours forever; a permanent memoir of your explorations.\n\n"
                                "    Share your passport cards with the world (tag us @nyceats.passports if you’d like!). Bon Appétit, and Happy Journey!\n\n"
                                "    – With love,\n"
                                "    Barbell Apps",
                                style: TextStyle(
                                  fontFamily: 'AppleGaramond',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 16,
                                  color: Color(0xFFE0E0E0),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              GestureDetector(
                                onTap: () {
                                  setDialogState(() => doNotShowAgain = !doNotShowAgain);
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: doNotShowAgain,
                                        onChanged: (val) {
                                          setDialogState(() => doNotShowAgain = val ?? true);
                                        },
                                        activeColor: Colors.white,
                                        checkColor: Colors.black,
                                        side: const BorderSide(color: Colors.white54),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Do not show again",
                                      style: TextStyle(
                                        fontFamily: 'SFPro', 
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    await prefs.setBool('show_traveler_note', !doNotShowAgain);
    _navigateToPassport();
  }

  void _navigateToPassport() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PassportCollectionScreen(
          initialBookId: null,
        )
      ),
    );
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

  // =========================================================================
  // 🗺️ THE MASTER LAYER SETUP (Mapbox Style Engine)
  // =========================================================================
  Future<void> _setupMapboxLayers(Map<String, String> paths) async {
    if (_mapboxController == null) return;

    try {
      // --- 1. THE SOURCES ---
      if (!(await _mapboxController?.style.styleSourceExists("regular-source") ?? false)) {
        await _mapboxController?.style.addSource(GeoJsonSource(id: "regular-source", data: "file://${paths['regular']}", cluster: true, clusterRadius: 50, clusterMaxZoom: 14.0, buffer: 128.0));
      }
      
      // 🌟 THE FIX 1: The "Shadow Source" (No clustering rules applied)
      if (!(await _mapboxController?.style.styleSourceExists("regular-source-unclustered") ?? false)) {
        await _mapboxController?.style.addSource(GeoJsonSource(id: "regular-source-unclustered", data: "file://${paths['regular']}"));
      }

      if (!(await _mapboxController?.style.styleSourceExists("heroes-source") ?? false)) {
        await _mapboxController?.style.addSource(GeoJsonSource(id: "heroes-source", data: "file://${paths['heroes']}", buffer: 128.0));
      }

      // --- 2. DEFAULT CLUSTERS ---
      if (!(await _mapboxController?.style.styleLayerExists("cluster-circles") ?? false)) {
        await _mapboxController?.style.addLayer(CircleLayer(id: "cluster-circles", sourceId: "regular-source"));
      }
      await _mapboxController?.style.setStyleLayerProperty("cluster-circles", "filter", ["has", "point_count"]);
      await _mapboxController?.style.setStyleLayerProperty("cluster-circles", "circle-color", isDarkMode ? "#1E1E1E" : "#FFFFFF");
      await _mapboxController?.style.setStyleLayerProperty("cluster-circles", "circle-stroke-color", isDarkMode ? "#FFFFFF" : "#000000"); 
      await _mapboxController?.style.setStyleLayerProperty("cluster-circles", "circle-stroke-width", 3.5); 
      await _mapboxController?.style.setStyleLayerProperty("cluster-circles", "circle-radius", ["step", ["get", "point_count"], 18, 100, 22, 1000, 26]);

      if (!(await _mapboxController?.style.styleLayerExists("cluster-text") ?? false)) {
        await _mapboxController?.style.addLayer(SymbolLayer(id: "cluster-text", sourceId: "regular-source"));
      }
      await _mapboxController?.style.setStyleLayerProperty("cluster-text", "filter", ["has", "point_count"]);
      await _mapboxController?.style.setStyleLayerProperty("cluster-text", "text-field", ["case", ["<", ["get", "point_count"], 1000], ["to-string", ["get", "point_count"]], ["concat", ["to-string", ["floor", ["/", ["get", "point_count"], 1000]]], "k+"]]);
      await _mapboxController?.style.setStyleLayerProperty("cluster-text", "text-font", ["Source Code Pro Bold", "Open Sans Bold", "Arial Unicode MS Bold"]);
      await _mapboxController?.style.setStyleLayerProperty("cluster-text", "text-size", 14.0);
      await _mapboxController?.style.setStyleLayerProperty("cluster-text", "text-color", isDarkMode ? "#FFFFFF" : "#000000");
      await _mapboxController?.style.setStyleLayerProperty("cluster-text", "text-allow-overlap", true);
      await _mapboxController?.style.setStyleLayerProperty("cluster-text", "text-ignore-placement", true);

      // --- 3. EMOJI LOGIC ---
      final starsVal = ["to-number", ["get", "michelin_stars"], 0];
      final bibCheck = ["==", ["downcase", ["to-string", ["get", "bib_gourmand"]]], "true"];
      final ringType = ["case", [">", starsVal, 0], "gold", bibCheck, "red", "black"];
      
      List<dynamic> emojiCode = ["case"];
      for (var cuisineKeyword in CuisineConstants.emojiPalettes.keys) {
        emojiCode.add(["in", cuisineKeyword.toLowerCase(), ["downcase", ["to-string", ["get", "cuisine"]]]]);
        emojiCode.add(cuisineKeyword); 
      }
      emojiCode.add("default");
      final dynamicIconImage = ["concat", "pill-", emojiCode, "-", ringType, "-", ["to-string", starsVal]];
      final dynamicIconSize = ["interpolate", ["linear"], ["zoom"], 8.0, 0.40, 11.0, 0.55, 14.0, 0.75, 16.0, 0.90];

      // --- 4. REGULAR HIERARCHY LAYERS ---
      if (!(await _mapboxController?.style.styleLayerExists("regular-bubbles") ?? false)) {
        await _mapboxController?.style.addLayer(SymbolLayer(id: "regular-bubbles", sourceId: "regular-source", minZoom: 14.0, iconAllowOverlap: false, iconPitchAlignment: IconPitchAlignment.VIEWPORT));
      }
      await _mapboxController?.style.setStyleLayerProperty("regular-bubbles", "filter", ["!", ["has", "point_count"]]);
      await _mapboxController?.style.setStyleLayerProperty("regular-bubbles", "icon-image", dynamicIconImage);
      await _mapboxController?.style.setStyleLayerProperty("regular-bubbles", "icon-size", dynamicIconSize);

      if (!(await _mapboxController?.style.styleLayerExists("heroes-bib-bubbles") ?? false)) {
        await _mapboxController?.style.addLayer(SymbolLayer(id: "heroes-bib-bubbles", sourceId: "heroes-source", minZoom: 13.0, iconAllowOverlap: true, iconPitchAlignment: IconPitchAlignment.VIEWPORT));
      }
      await _mapboxController?.style.setStyleLayerProperty("heroes-bib-bubbles", "filter", ["all", bibCheck, ["==", starsVal, 0]]);
      await _mapboxController?.style.setStyleLayerProperty("heroes-bib-bubbles", "icon-image", dynamicIconImage);
      await _mapboxController?.style.setStyleLayerProperty("heroes-bib-bubbles", "icon-size", dynamicIconSize);

      if (!(await _mapboxController?.style.styleLayerExists("heroes-1-bubbles") ?? false)) {
        await _mapboxController?.style.addLayer(SymbolLayer(id: "heroes-1-bubbles", sourceId: "heroes-source", minZoom: 12.0, iconAllowOverlap: true, iconPitchAlignment: IconPitchAlignment.VIEWPORT));
      }
      await _mapboxController?.style.setStyleLayerProperty("heroes-1-bubbles", "filter", ["==", starsVal, 1]);
      await _mapboxController?.style.setStyleLayerProperty("heroes-1-bubbles", "icon-image", dynamicIconImage);
      await _mapboxController?.style.setStyleLayerProperty("heroes-1-bubbles", "icon-size", dynamicIconSize);

      if (!(await _mapboxController?.style.styleLayerExists("heroes-3-2-bubbles") ?? false)) {
        await _mapboxController?.style.addLayer(SymbolLayer(id: "heroes-3-2-bubbles", sourceId: "heroes-source", minZoom: 8.0, iconAllowOverlap: true, iconPitchAlignment: IconPitchAlignment.VIEWPORT));
      }
      await _mapboxController?.style.setStyleLayerProperty("heroes-3-2-bubbles", "filter", [">=", starsVal, 2]);
      await _mapboxController?.style.setStyleLayerProperty("heroes-3-2-bubbles", "symbol-sort-key", ["case", ["==", starsVal, 3], 2, ["==", starsVal, 2], 1, 0]); 
      await _mapboxController?.style.setStyleLayerProperty("heroes-3-2-bubbles", "icon-image", dynamicIconImage);
      await _mapboxController?.style.setStyleLayerProperty("heroes-3-2-bubbles", "icon-size", dynamicIconSize);

      // --- 5. FILTER OVERRIDE LAYERS (Zoom 1.0+) ---
      final hideCommand = ["==", ["get", "id"], -1];

      // 🌟 THE FIX 2: Point the filtered regular bubbles to the new "Shadow Source"
      if (!(await _mapboxController?.style.styleLayerExists("filtered-regular-bubbles") ?? false)) {
        await _mapboxController?.style.addLayer(SymbolLayer(id: "filtered-regular-bubbles", sourceId: "regular-source-unclustered", minZoom: 1.0, iconAllowOverlap: false, iconPitchAlignment: IconPitchAlignment.VIEWPORT));
      }
      await _mapboxController?.style.setStyleLayerProperty("filtered-regular-bubbles", "filter", hideCommand); 
      await _mapboxController?.style.setStyleLayerProperty("filtered-regular-bubbles", "icon-image", dynamicIconImage);
      await _mapboxController?.style.setStyleLayerProperty("filtered-regular-bubbles", "icon-size", dynamicIconSize);

      if (!(await _mapboxController?.style.styleLayerExists("filtered-bib-bubbles") ?? false)) {
        await _mapboxController?.style.addLayer(SymbolLayer(id: "filtered-bib-bubbles", sourceId: "heroes-source", minZoom: 1.0, iconAllowOverlap: true, iconPitchAlignment: IconPitchAlignment.VIEWPORT));
      }
      await _mapboxController?.style.setStyleLayerProperty("filtered-bib-bubbles", "filter", hideCommand);
      await _mapboxController?.style.setStyleLayerProperty("filtered-bib-bubbles", "icon-image", dynamicIconImage);
      await _mapboxController?.style.setStyleLayerProperty("filtered-bib-bubbles", "icon-size", dynamicIconSize);

      // ... your existing code ...
    if (!(await _mapboxController?.style.styleLayerExists("filtered-1-bubbles") ?? false)) {
      await _mapboxController?.style.addLayer(SymbolLayer(id: "filtered-1-bubbles", sourceId: "heroes-source", minZoom: 1.0, iconAllowOverlap: true, iconPitchAlignment: IconPitchAlignment.VIEWPORT));
    }
    await _mapboxController?.style.setStyleLayerProperty("filtered-1-bubbles", "filter", hideCommand);
    await _mapboxController?.style.setStyleLayerProperty("filtered-1-bubbles", "icon-image", dynamicIconImage);
    await _mapboxController?.style.setStyleLayerProperty("filtered-1-bubbles", "icon-size", dynamicIconSize);

    // 🌟 THE FIX: Force the location puck to be the absolute top layer
    await _mapboxController?.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      showAccuracyRing: true,
    ));

  } catch (e) {
    debugPrint("🚨 Layer Error: $e");
  }
} // <-- End of _setupMapboxLayers

  // =========================================================================
  // 👆 4. THE INTERACTION BRIDGE (Mapbox Tap Listener)
  // =========================================================================
  Future<void> _handleMapTap(MapContentGestureContext context) async {
    if (_mapboxController == null) return;

    try {
      final screenCoord = await _mapboxController!.pixelForCoordinate(context.point);

      // Increased back to 25.0 to ensure it catches fat-finger taps 
      // on the far edges of your wide custom pills.
      final double tapRadius = 25.0; 
      final Map<String, dynamic> tapBoxMap = {
        "min": {"x": screenCoord.x - tapRadius, "y": screenCoord.y - tapRadius},
        "max": {"x": screenCoord.x + tapRadius, "y": screenCoord.y + tapRadius}
      };

      final geometry = RenderedQueryGeometry(
        value: jsonEncode(tapBoxMap),
        type: Type.SCREEN_BOX, 
      );

      final options = RenderedQueryOptions(layerIds: [
        "heroes-3-2-bubbles", 
        "filtered-1-bubbles",       // 🌟 ADDED
        "heroes-1-bubbles",   
        "filtered-bib-bubbles",     // 🌟 ADDED
        "heroes-bib-bubbles", 
        "filtered-regular-bubbles", // 🌟 ADDED
        "regular-bubbles",    
        "cluster-circles"     
      ]);
      
      final features = await _mapboxController!.queryRenderedFeatures(geometry, options);

      if (features.isNotEmpty) {
        
        // 🌟 THE FIX: The Priority Funnel updated with overrides
        final List<String> layerPriority = [
          "heroes-3-2-bubbles",
          "filtered-1-bubbles",       // 🌟 ADDED
          "heroes-1-bubbles",
          "filtered-bib-bubbles",     // 🌟 ADDED
          "heroes-bib-bubbles",
          "filtered-regular-bubbles", // 🌟 ADDED
          "regular-bubbles",
          "cluster-circles"
        ];

        Map<String, dynamic>? selectedFeatureProps;
        Map<String, dynamic>? selectedFeatureGeom;
        bool isClusterTap = false;

        // Funnel through our strict hierarchy
        for (String layerId in layerPriority) {
          
          // 🌟 THE FIX: Mapbox stores layers in a list on the parent object
          final match = features.firstWhere(
            (f) => f?.layers?.contains(layerId) == true, 
            orElse: () => null
          );

          if (match != null) {
            final rawFeature = match.queriedFeature?.feature as Map?;
            if (rawFeature != null) {
              final featureMap = Map<String, dynamic>.from(rawFeature);
              
              final rawProps = featureMap['properties'] as Map?;
              selectedFeatureProps = rawProps != null ? Map<String, dynamic>.from(rawProps) : null;
              
              final rawGeom = featureMap['geometry'] as Map?;
              selectedFeatureGeom = rawGeom != null ? Map<String, dynamic>.from(rawGeom) : null;
              
              isClusterTap = layerId == "cluster-circles";
              break; // Found the absolute highest-priority target! Stop looking.
            }
          }
        }

        if (selectedFeatureProps == null) return;

        // --- Execute the Interaction ---
        final isCluster = isClusterTap || selectedFeatureProps['cluster'] == true || selectedFeatureProps.containsKey('point_count');
        
        if (isCluster) {
            final coords = selectedFeatureGeom?['coordinates'] as List<dynamic>?;
            if (coords != null && coords.length >= 2) {
              final currentZoom = await _mapboxController!.getCameraState().then((s) => s.zoom);
              _mapboxController!.flyTo(
                CameraOptions(
                  center: Point(coordinates: Position((coords[0] as num).toDouble(), (coords[1] as num).toDouble())), 
                  zoom: currentZoom + 2.5 
                ),
                MapAnimationOptions(duration: 500)
              );
            }
            return; 
        }

        // Must be a restaurant! Open the sheet.
        if (selectedFeatureProps['id'] != null) {
          final int restaurantId = int.parse(selectedFeatureProps['id'].toString());
          _fetchAndShowRestaurant(restaurantId);
        }
      }
    } catch (e) {
      debugPrint("🚨 Tap query error: $e");
    }
  }

  // =========================================================================
  // 📡 5. SUPABASE SINGLE QUERY & UI TRIGGER
  // =========================================================================
  Future<void> _fetchAndShowRestaurant(int restaurantId) async {
    // 🌟 THE FIX: Removed the _isJumpingToLocation = true loader!
    
    try {
      final data = await Supabase.instance.client
          .from('restaurants')
          .select()
          .eq('id', restaurantId)
          .single();

      final restaurant = Restaurant.fromMap(data);

      if (mounted) {
        // Slide up your beautiful Detail Sheet instantly
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
    } catch (e) {
      debugPrint("🚨 Supabase single fetch error: $e");
    }
  }

  // =========================================================================
  // 🔍 INSTANT MAPBOX FILTER ENGINE
  // =========================================================================
  void _fetchRestaurants() async {
    if (_mapboxController == null) return;

    final clusterBase = ["has", "point_count"];
    final starsVal = ["to-number", ["get", "michelin_stars"], 0];
    final bibCheck = ["==", ["downcase", ["to-string", ["get", "bib_gourmand"]]], "true"];

    final regularBase = ["!", ["has", "point_count"]];
    final bibBase = ["all", bibCheck, ["==", starsVal, 0]];
    final star1Base = ["==", starsVal, 1];
    final star32Base = [">=", starsVal, 2];

    List<dynamic> userFilters = ["all"]; 

    if (selectedRestaurantName != null) {
      userFilters.add(["==", ["get", "name"], selectedRestaurantName]);
    } else if (selectedCategory != null) {
      userFilters.add(["==", ["downcase", ["to-string", ["get", "cuisine"]]], selectedCategory!.toLowerCase()]);
    }

    if (_showVegetarian) userFilters.add(["==", ["downcase", ["to-string", ["get", "is_vegetarian"]]], "true"]);
    if (_showVegan) userFilters.add(["==", ["downcase", ["to-string", ["get", "is_vegan"]]], "true"]);

    if (savedOnly) {
      if (savedRestaurantNames.isEmpty) {
        userFilters.add(["==", ["get", "id"], -1]); 
      } else {
        userFilters.add(["in", ["get", "name"], ["literal", savedRestaurantNames.toList()]]);
      }
    }

    if (_selectedPrices.isNotEmpty) {
      userFilters.add(["in", ["get", "price"], ["literal", _selectedPrices.toList()]]);
    }

    if (_selectedMichelin.isNotEmpty) {
      List<dynamic> michelinOr = ["any"]; 
      if (_selectedMichelin.contains("Bib Gourmand")) michelinOr.add(bibCheck);
      if (_selectedMichelin.contains("1 Star")) michelinOr.add(["==", starsVal, 1]);
      if (_selectedMichelin.contains("2 Stars")) michelinOr.add(["==", starsVal, 2]);
      if (_selectedMichelin.contains("3 Stars")) michelinOr.add(["==", starsVal, 3]);
      userFilters.add(michelinOr);
    }

    // 🌟 THE FIX: "Open Now" Engine
    if (showOpenOnly) {
       List<int> openIds = [];
       final nycTime = DateTime.now().toUtc().subtract(const Duration(hours: 4)); 
       
       _restaurantHours.forEach((id, hoursString) {
          if (OSMTimeParser.isOpen(hoursString, nycTime)) {
             openIds.add(int.parse(id));
          }
       });

       if (openIds.isEmpty) {
          userFilters.add(["==", ["get", "id"], -1]); 
       } else {
          userFilters.add(["in", ["get", "id"], ["literal", openIds]]);
       }
    }

    // 🌟 THE FIX: Flatten the array so Mapbox doesn't crash on nested "all" statements
    List<dynamic> combine(List<dynamic> base) {
      if (userFilters.length == 1) return base;
      return ["all", base, ...userFilters.sublist(1)];
    }

    try {
      bool hasActiveFilters = userFilters.length > 1;
      final hideCommand = ["==", ["get", "id"], -1];

      if (hasActiveFilters) {
        // 1. HIDE DEFAULT HIERARCHY
        await _mapboxController?.style.setStyleLayerProperty("cluster-circles", "filter", hideCommand);
        await _mapboxController?.style.setStyleLayerProperty("cluster-text", "filter", hideCommand);
        await _mapboxController?.style.setStyleLayerProperty("regular-bubbles", "filter", hideCommand);
        await _mapboxController?.style.setStyleLayerProperty("heroes-bib-bubbles", "filter", hideCommand);
        await _mapboxController?.style.setStyleLayerProperty("heroes-1-bubbles", "filter", hideCommand);

        // 2. SHOW OVERRIDE LAYERS GLOBALLY
        await _mapboxController?.style.setStyleLayerProperty("filtered-regular-bubbles", "filter", combine(regularBase));
        await _mapboxController?.style.setStyleLayerProperty("filtered-bib-bubbles", "filter", combine(bibBase));
        await _mapboxController?.style.setStyleLayerProperty("filtered-1-bubbles", "filter", combine(star1Base));
        await _mapboxController?.style.setStyleLayerProperty("heroes-3-2-bubbles", "filter", combine(star32Base)); 
      } else {
        // 1. RESTORE DEFAULT HIERARCHY
        await _mapboxController?.style.setStyleLayerProperty("cluster-circles", "filter", clusterBase);
        await _mapboxController?.style.setStyleLayerProperty("cluster-text", "filter", clusterBase);
        await _mapboxController?.style.setStyleLayerProperty("regular-bubbles", "filter", regularBase);
        await _mapboxController?.style.setStyleLayerProperty("heroes-bib-bubbles", "filter", bibBase);
        await _mapboxController?.style.setStyleLayerProperty("heroes-1-bubbles", "filter", star1Base);
        await _mapboxController?.style.setStyleLayerProperty("heroes-3-2-bubbles", "filter", star32Base);

        // 2. HIDE OVERRIDE LAYERS
        await _mapboxController?.style.setStyleLayerProperty("filtered-regular-bubbles", "filter", hideCommand);
        await _mapboxController?.style.setStyleLayerProperty("filtered-bib-bubbles", "filter", hideCommand);
        await _mapboxController?.style.setStyleLayerProperty("filtered-1-bubbles", "filter", hideCommand);
      }
    } catch (e) {
      debugPrint("🚨 Filter Update Error: $e");
    }
  }

  @override
  build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat, 
      body: Stack(
        children: [
          // --- 1. MAP LAYER ---
          MapWidget(
            key: const ValueKey("mapboxWidget"),
            cameraOptions: initialCamera,
            // 🌟 Use STANDARD instead of LIGHT to keep the vibrant colors
            styleUri: isDarkMode ? MapboxStyles.DARK : MapboxStyles.STANDARD, 
            onMapCreated: (MapboxMap map) {
              _mapboxController = map; 
              
              // 🌟 THE NEW CODE: Turn on the native Location Puck!
              _mapboxController?.location.updateSettings(LocationComponentSettings(
                enabled: true,
                pulsingEnabled: true, // Gives it a cool radar pulse effect
                showAccuracyRing: true, // Shows the transparent circle of GPS accuracy
              ));
              
              _mapboxController?.gestures.updateSettings(GesturesSettings(
                pitchEnabled: false,
              ));

              _mapboxController?.scaleBar.updateSettings(ScaleBarSettings(
                enabled: false,
              ));

              _mapboxController?.compass.updateSettings(CompassSettings(
                position: OrnamentPosition.TOP_RIGHT,
                marginTop: 100.0, 
              ));

              _mapboxController?.logo.updateSettings(LogoSettings(
                position: OrnamentPosition.BOTTOM_LEFT,
                marginBottom: 90.0,
              ));

              _mapboxController?.attribution.updateSettings(AttributionSettings(
                position: OrnamentPosition.BOTTOM_LEFT,
                marginBottom: 90.0,
                marginLeft: 90.0, 
              ));
            },
            onTapListener: _handleMapTap,
            onStyleImageMissingListener: (StyleImageMissingEventData event) async {
              final String missingId = event.id; 
              if (!missingId.startsWith("pill-")) return;
              final parts = missingId.split("-");
              if (parts.length >= 4) {
                final int stars = int.tryParse(parts.last) ?? 0;
                final String ringType = parts[parts.length - 2];
                final String cuisine = parts.sublist(1, parts.length - 2).join("-");
                // The PillCache naturally respects the isDarkMode flag!
                final pillData = await PillCache.getOrGeneratePill(missingId, cuisine, ringType, stars, isDarkMode);
                await _mapboxController?.style.addStyleImage(
                  missingId, 1.0, MbxImage(width: pillData.width, height: pillData.height, data: pillData.data), 
                  false, [], [], null
                );
              }
            },
            onStyleLoadedListener: (StyleLoadedEventData data) {
              // 1. Instantly rebuild the data layers on top of the new base map
              if (_vaultPaths != null) _setupMapboxLayers(_vaultPaths!); 
              
              // 2. 🌟 THE FIX: Only jump the camera on the very first app launch
              if (!_hasPerformedInitialCameraFly) {
                _hasPerformedInitialCameraFly = true;
                _mapboxController?.flyTo(
                  CameraOptions(
                    center: myLocation != null 
                      ? Point(coordinates: Position(myLocation!.longitude, myLocation!.latitude))
                      : targetCamera.center,
                    zoom: 14.0,
                  ),
                  MapAnimationOptions(duration: 1500), 
                );
              }
            },
          ),
          
          // ===================================================================
          // 2. UI: DYNAMIC PILL SEARCH BAR & FILTERS
          // ===================================================================
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Container(
                              key: _searchKey, // 🌟 THE FIX: Put the tutorial key back!
                              margin: const EdgeInsets.fromLTRB(16, 20, 16, 6), 
                              height: 64, 
                              // ... (Keep the rest of your beautiful styling exactly as is)
                      padding: const EdgeInsets.only(left: 24, right: 12), 
                      decoration: BoxDecoration(
                      // 🌟 1. Lighten the dark mode grey slightly (from 2C2C2E to 3A3A3C)
                      color: isDarkMode ? const Color(0xFF3A3A3C) : Colors.white,
                      borderRadius: BorderRadius.circular(100), 
                      
                      // 🌟 2. The "Hairline Border" (Only visible in Dark Mode)
                      border: isDarkMode 
                          ? Border.all(color: Colors.white.withOpacity(0.15), width: 1.0) 
                          : null,
                          
                      boxShadow: [
                        BoxShadow(
                          // 🌟 3. Make the dark mode shadow much wider and darker to create a "void" around the pill
                          color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.12), 
                          blurRadius: isDarkMode ? 24 : 12, 
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 22, color: isDarkMode ? Colors.white : Colors.black),
                          const SizedBox(width: 14), 
                          Expanded(
                            child: GestureDetector(
                              onTap: _openSearchPage,
                              child: Container(
                                color: Colors.transparent, 
                                child: (selectedCategory == null && selectedRestaurantName == null)
                                    ? AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 400),
                                        transitionBuilder: (Widget child, Animation<double> animation) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              position: Tween<Offset>(begin: const Offset(-0.03, 0), end: Offset.zero).animate(animation),
                                              child: Align(alignment: Alignment.centerLeft, child: child),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          _searchPhrases[_currentPhraseIndex],
                                          key: ValueKey(_searchPhrases[_currentPhraseIndex]),
                                          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black.withOpacity(0.6), fontSize: 17, fontFamily: 'SF Pro Text', fontWeight: FontWeight.w600, letterSpacing: -0.4),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                      : Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          // 🌟 THE FIX: Pass the raw category through the visual formatter!
                                          selectedRestaurantName != null 
                                              ? "Searching: \"$selectedRestaurantName\"" 
                                              : "Filtering: ${_formatCategoryDisplay(selectedCategory!)}",
                                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 17, fontFamily: 'SF Pro Text', fontWeight: FontWeight.w800, letterSpacing: -0.4),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          // 🌟 CLEAR BUTTON
                          if (selectedCategory != null || selectedRestaurantName != null)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact(); 
                                setState(() {
                                  selectedCategory = null;
                                  selectedRestaurantName = null;
                                });
                                _fetchRestaurants(); // 🌟 Instantly syncs the map back to default!
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(color: isDarkMode ? Colors.white10 : Colors.black12, shape: BoxShape.circle),
                                child: Icon(Icons.close, size: 16, color: isDarkMode ? Colors.white : Colors.black),
                              ),
                            ),

                          // PROFILE AVATAR
                          GestureDetector(
                            key: _profileKey,
                            onTap: () async {
                              HapticFeedback.lightImpact(); 
                              await openProfileScreen(context, name: _userName, photoUrl: _userPhotoUrl, gender: _userGender, age: _userAge);
                              await _fetchUserProfile(forceRefresh: true);
                            },
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle, border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.05), width: 1)),
                              child: ClipOval(child: _buildAvatarContent()),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildSystemStatus(),

                    // 🌟 HORIZONTAL FILTER BAR (Hooked up to fetchRestaurants)
                    MapFilterBar(
                      isDarkMode: isDarkMode,
                      showOpenOnly: showOpenOnly,
                      savedOnly: savedOnly,
                      showVegetarian: _showVegetarian,
                      showVegan: _showVegan,
                      selectedMichelin: _selectedMichelin,
                      selectedPrices: _selectedPrices,
                      onOpenChanged: (v) { setState(() => showOpenOnly = v); _fetchRestaurants(); },
                      onSavedChanged: (v) { setState(() => savedOnly = v); _fetchRestaurants(); },
                      onVegChanged: (v) { setState(() => _showVegetarian = v); _fetchRestaurants(); },
                      onVeganChanged: (v) { setState(() => _showVegan = v); _fetchRestaurants(); },
                      onMichelinChanged: (v) { setState(() => _selectedMichelin = v); _fetchRestaurants(); },
                      onPriceChanged: (v) { setState(() => _selectedPrices = v); _fetchRestaurants(); },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===================================================================
          // 3. BOTTOM RIGHT BUTTONS
          // ===================================================================
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

          // ===================================================================
          // 4. OVERLAYS
          // ===================================================================
          if (_isJumpingToLocation)
            Positioned.fill(
              child: Container(
                color: isDarkMode ? Colors.black54 : Colors.white54, 
                child: const Center(
                  child: CupertinoActivityIndicator(radius: 16),
                ),
              ),
            ),

          if (_isBuildingVault)
            Positioned.fill(
              child: Container(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CupertinoActivityIndicator(radius: 20),
                    const SizedBox(height: 24),
                    Text(
                      "Stamping your initial visa...",
                      style: TextStyle(
                        fontFamily: 'AppleGaramond',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Securing local coordinates. This only happens once.",
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      
      // =======================================================================
      // 5. FAB (PASSPORT)
      // =======================================================================
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

// Put this at the very bottom of map_screen.dart
class OSMTimeParser {
  static bool isOpen(String hoursStr, DateTime now) {
    if (hoursStr.contains('24/7')) return true;
    
    final days = ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'];
    final todayIdx = now.weekday - 1;
    final todayStr = days[todayIdx];
    final currentMinutes = now.hour * 60 + now.minute;
    
    final lowerStr = hoursStr.toLowerCase();
    
    // 1. Check if the string applies to today
    final hasDays = RegExp(r'[a-z]{2}').hasMatch(lowerStr);
    bool matchesDay = false;
    
    if (!hasDays) {
       matchesDay = true; // No days specified, assume everyday
    } else {
       if (lowerStr.contains(todayStr)) {
         matchesDay = true;
       } else {
         // Check ranges like "mo-fr" or "fr-su"
         final rangeReg = RegExp(r'([a-z]{2})\s*-\s*([a-z]{2})');
         for (final match in rangeReg.allMatches(lowerStr)) {
            final d1 = days.indexOf(match.group(1)!);
            final d2 = days.indexOf(match.group(2)!);
            if (d1 != -1 && d2 != -1) {
               if (d1 <= d2 && todayIdx >= d1 && todayIdx <= d2) matchesDay = true;
               else if (d1 > d2 && (todayIdx >= d1 || todayIdx <= d2)) matchesDay = true; // Crosses Sunday
            }
         }
       }
    }
    
    if (!matchesDay) return false;
    
    // 2. Extract times and check cross-midnight logic
    final timeReg = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})');
    final matches = timeReg.allMatches(lowerStr);
    
    if (matches.isEmpty) return true; // Unparseable, default to open
    
    for (final m in matches) {
      final start = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
      int end = int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!);
      
      if (end < start) end += 24 * 60; // Opens past midnight
      
      int checkTime = currentMinutes;
      if (currentMinutes < start && end > 24*60 && currentMinutes < (end - 24*60)) {
         checkTime += 24 * 60; // Push current time to "tomorrow" context
      }
      
      if (checkTime >= start && checkTime <= end) return true;
    }
    return false;
  }
}