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
import 'package:nyc_eats/services/telemetry_service.dart';
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
import 'dart:ui' as ui;
// Required for HapticFeedback
import '../widgets/map_filter_bar.dart';
import '../widgets/concierge_overlay.dart'; // Add this near the top
import 'dart:math' as math;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  MapboxMap? _mapboxController;

  final bool _isJumpingToLocation = false;
  bool _isBuildingVault = false;
  bool _isExecutingBoot = false; // 🌟 THE BOOT LOCKOUT
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
    center: Point(
      coordinates: Position(-73.98, 40.75),
    ), // Centered exactly on Manhattan
    zoom: 11.5, // The exact zoom level from your screenshot
    pitch: 0.0, // Flat
    bearing: 0.0, // Pointing straight North
  );

  bool _isCheckingLocation = false;
  bool _isFetchingSheet = false;
  bool _isFilteringMap = false;
  bool _showNoResultsOverlay = false; // 🌟 ADD THIS: Tracks empty filter states

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
  final GlobalKey _conciergeKey = GlobalKey(); // 👈 NEW: Hook for the tutorial

  int _currentPhraseIndex = 0;
  Timer? _textTimer;
  final List<String> _searchPhrases = [
    "Hungry?",
    "Nom nom nom...",
    "Where to next?",
    "Craving something?",
    "Let's eat!",
    "Find a hidden gem...",
  ];

  // --- FILTER STATE ---
  bool showOpenOnly = false;
  bool savedOnly = false;
  bool _showVegetarian = false;
  bool _showVegan = false;
  Set<String> _selectedMichelin = {};
  Set<String> _selectedPrices = {};

  Map<String, String> _restaurantHours = {};

  bool _showConcierge = false;

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
    // 🌟 1. THE LOCKOUT: Prevent multiple boot sequences from overlapping
    if (_isExecutingBoot) return;
    _isExecutingBoot = true;

    _loadTheme();
    await _loadCachedLocation();

    _fetchUserProfile();
    PassportService.prewarmCache();
    await _loadFavorites();

    final prefs = await SharedPreferences.getInstance();
    final bool hasStampedVisa =
        prefs.getBool('has_stamped_initial_visa') ?? false;

    if (!hasStampedVisa) {
      if (mounted) setState(() => _isBuildingVault = true);
    }

    try {
      _vaultPaths = await VaultBuilder.buildVaultIfNeeded();

      if (_vaultPaths != null && _vaultPaths!['hours'] != null) {
        final hoursFile = File(_vaultPaths!['hours']!);
        if (await hoursFile.exists()) {
          final hoursStr = await hoursFile.readAsString();
          final decoded =
              await compute(jsonDecode, hoursStr) as Map<String, dynamic>;
          _restaurantHours = decoded.map(
            (key, value) => MapEntry(key, value.toString()),
          );
        }
      }

      if (_mapboxController != null && _vaultPaths != null) {
        _setupMapboxLayers(_vaultPaths!);
      }

      if (!hasStampedVisa) {
        await prefs.setBool('has_stamped_initial_visa', true);
      }
    } catch (e) {
      debugPrint("🚨 Vault creation failed: $e");
    } finally {
      // 🌟 2. THE QUEUE: Only drop the shield and show the tutorial IF we succeeded.
      final bool isComplete =
          prefs.getBool('has_stamped_initial_visa') ?? false;

      if (isComplete && mounted) {
        setState(() => _isBuildingVault = false);
        _initLocationService();
        _checkAndShowTutorial(); // 🌟 MOVED HERE! The tutorial waits in line.
      }

      // Unlock the boot sequence
      _isExecutingBoot = false;
    }
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

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );

    _serviceStatusStreamSubscription = geo.Geolocator.getServiceStatusStream()
        .listen((geo.ServiceStatus status) {
          if (mounted) {
            setState(() {
              _isGpsDisabled = (status == geo.ServiceStatus.disabled);
              if (_isGpsDisabled) myLocation = null;
            });
          }
        });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) async {
    bool hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (mounted) {
      setState(() => _isOffline = !hasConnection);
    }

    // 🌟 THE FIX: If WiFi returns, the shield is up, AND a boot isn't already running, restart the engine!
    if (hasConnection && _isBuildingVault && !_isExecutingBoot) {
      _fastBootSequence();
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() => isDarkMode = prefs.getBool('is_dark_mode') ?? false);
    }

    // 🌟 THE FIX: Force the Mapbox engine to instantly sync with the saved theme
    if (_mapboxController != null) {
      _mapboxController!.loadStyleURI(
        isDarkMode ? MapboxStyles.DARK : MapboxStyles.STANDARD,
      );
    }
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => isDarkMode = !isDarkMode);
    await prefs.setBool('is_dark_mode', isDarkMode);

    // 🌟 THE FIX: Instantly command Mapbox to swap the base tiles.
    // We use STANDARD for the colorful light mode, and DARK for dark mode.
    if (_mapboxController != null) {
      _mapboxController!.loadStyleURI(
        isDarkMode ? MapboxStyles.DARK : MapboxStyles.STANDARD,
      );
    }
  }

  Future<void> _checkLocationOnResume() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted && myLocation == null) {
      _showLocationDialog();
    } else {
      _checkPermissionAndListen();
    }
  }

  Future<void> _initLocationService() async {
    final permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.whileInUse ||
        permission == geo.LocationPermission.always) {
      _startListening();
    } else {
      _checkPermissionAndListen();
    }
  }

  Future<void> _checkPermissionAndListen() async {
    if (_isCheckingLocation) return;
    _isCheckingLocation = true;
    try {
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
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

    _positionStreamSubscription =
        geo.Geolocator.getPositionStream(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((geo.Position position) {
          final newLoc = LatLng(position.latitude, position.longitude);

          if (mounted) {
            setState(() {
              myLocation = newLoc;
            });
            _saveLocationToCache(newLoc);
          }
        });
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(
        0.4,
      ), // 1. Dim the map behind the dialog
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor:
            Colors.transparent, // 2. CRITICAL: Kill default background
        surfaceTintColor:
            Colors.transparent, // 3. CRITICAL: Kill Material 3 white tint
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            28,
          ), // Apple's standard smooth curve
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: 25.0,
              sigmaY: 25.0,
            ), // 4. The heavy glass blur
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                // 5. Very low opacity colors so the blur actually shines through
                color: isDarkMode
                    ? const Color(0xFF1C1C1E).withOpacity(0.55)
                    : const Color(0xFFF2F2F7).withOpacity(0.65),
                // 6. The signature Apple microscopic glass shine border
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 📡 Premium Radar Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.location_slash_fill,
                      size: 36,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 📜 Elegant Title
                  Text(
                    "Location Disabled",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'AppleGaramond',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 💬 Softer, clearer instructions
                  Text(
                    "NYC Eats works best when it can show you the culinary gems hiding right around your corner.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SFPro',
                      fontSize: 15,
                      height: 1.3,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 🔘 The Action Buttons
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Primary Action
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          geo.Geolocator.openLocationSettings();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? Colors.white
                              : Colors.black,
                          foregroundColor: isDarkMode
                              ? Colors.black
                              : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Enable in Settings",
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Secondary Action: Bypass
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Explore Without Location",
                          style: TextStyle(
                            fontFamily: 'SFPro',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchUserProfile({bool forceRefresh = false}) async {
    final data = await PassportService.fetchUserProfile(
      forceRefresh: forceRefresh,
    );

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
            setState(() {
              selectedCategory = category;
              selectedRestaurantName = null;
            });
            _fetchRestaurants(); // 🌟 ADD THIS
          },
          onRestaurantSelected: (restaurant) {
            setState(() {
              selectedRestaurantName = restaurant.name;
              selectedCategory = null;
            }); // Make sure state is updated
            _fetchRestaurants(); // 🌟 ADD THIS
            _jumpToRestaurant(restaurant);
          },
        ),
      ),
    );
  }

  Future<void> _jumpToRestaurant(Restaurant restaurant) async {
    // 🌟 THE MEMORY SWEEP: Dump old images from RAM before the heavy graphic jump
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // 1. Teleport the map
    _mapboxController?.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(
            restaurant.location.longitude,
            restaurant.location.latitude,
          ),
        ),
        zoom: 16.0,
      ),
    );

    // 🌟 THE BREATHER: Give the iPad's Metal GPU 500ms to finish drawing the streets
    await Future.delayed(const Duration(milliseconds: 500));

    // 2. Now that the GPU is resting, pull up the UI sheet
    _fetchAndShowRestaurant(restaurant.id);
  }

  void _openCountryWheel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CountryWheelModal(
        isDarkMode: isDarkMode,
        // 🌟 FIX 1: Feed the wheel the actual cuisines from your database!
        availableCuisines: CuisineConstants.emojiPalettes.keys.toList(),
        onCountrySelected: (country) {
          setState(() {
            // 🌟 FIX 2: Ensure the string is formatted for your Mapbox filter
            selectedCategory = country.toLowerCase();
            selectedRestaurantName = null;
          });

          // Trigger the instant Mapbox UI filter
          _fetchRestaurants();

          // 🌟 FIX 3: The "Reveal" Zoom
          // We must zoom out to a city-wide view so they can see where the new cuisine is located!
          if (_mapboxController != null) {
            _mapboxController!.flyTo(
              CameraOptions(
                center: Point(
                  coordinates: Position(-73.98, 40.75),
                ), // Center of NYC
                zoom: 10.5, // City-wide zoom level
                pitch: 0.0,
              ),
              MapAnimationOptions(duration: 1500),
            );
          }
        },
      ),
    );
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    _mapboxController?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(destLocation.longitude, destLocation.latitude),
        ),
        zoom: destZoom,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }

  // 🌟 ADD THIS HELPER TO MAP SCREEN
  String _formatCategoryDisplay(String category) {
    String formatted = category
        .split('_')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
    String emoji = CuisineConstants.emojiPalettes[category]?.first ?? '🍽️';
    if (category.toLowerCase() == 'hot_dog') emoji = '🌭';
    return '$formatted $emoji';
  }

  void _recenterMap() {
    if (myLocation != null) {
      _animatedMapMove(myLocation!, 15.0);
    } else {
      _animatedMapMove(const LatLng(40.735, -73.99), 13.0);
      _showLocationDialog();
    }
  }

  void _zoom(double amount) {
    if (_mapboxController != null) {
      _mapboxController!.getCameraState().then((cameraState) {
        final currentZoom = cameraState.zoom;
        _mapboxController!.flyTo(
          CameraOptions(zoom: currentZoom + amount),
          MapAnimationOptions(duration: 300),
        );
      });
    }
  }

  void _startTextAnimation() {
    _textTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (selectedCategory == null && selectedRestaurantName == null) {
        if (mounted) {
          setState(
            () => _currentPhraseIndex =
                (_currentPhraseIndex + 1) % _searchPhrases.length,
          );
        }
      }
    });
  }

  Widget _buildAvatarContent() {
    if (_userName == null) {
      return const Center(
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
        ),
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
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.black,
            ),
          ),
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
      curve: Curves.easeOutBack,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                // Frosted grey for offline, amber for GPS disabled
                color: _isOffline
                    ? (isDarkMode
                          ? Colors.black.withOpacity(0.65)
                          : Colors.white.withOpacity(0.85))
                    : const Color(0xFFFFA000).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isOffline
                      ? (isDarkMode ? Colors.white24 : Colors.black12)
                      : Colors.white30,
                  width: 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    _isOffline
                        ? CupertinoIcons.wifi_exclamationmark
                        : Icons.location_disabled,
                    color: _isOffline ? Colors.amber[700] : Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOffline
                              ? "YOU ARE OFFLINE"
                              : "LOCATION SERVICES DISABLED",
                          style: TextStyle(
                            color: _isOffline
                                ? (isDarkMode ? Colors.white : Colors.black87)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'SFPro',
                            fontSize: 13,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (_isOffline) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Map exploration available. Connect to the internet to view profiles and collect stamps.",
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                              fontFamily: 'SFPro',
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!_isOffline && _isGpsDisabled) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: geo.Geolocator.openLocationSettings,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "ENABLE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
                    const Text(
                      "THE JOURNEY BEGINS",
                      style: TextStyle(
                        fontFamily: 'AppleGaramond',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 32,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Collect a stamp from your favourite restaurant! Try it out!\n\nWelcome to NYC Eats, and Happy Journey!",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: () {
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setBool('has_seen_tutorial', true);
                          prefs.remove('tutorial_stage');
                        });
                        controller.skip();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text(
                        "FINISH TOUR",
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
              child: _buildTutorialText(
                "THE VAULT",
                "36,000+ restaurants across all 5 boroughs.\n\nTap here to search or filter by Michelin stars, vegan, and more.",
                controller,
              ),
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
            builder: (context, controller) => _buildTutorialText(
              "THE SPIN",
              "Can't decide? Spin the global wheel and let fate choose your next cuisine.",
              controller,
            ),
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
              child: _buildTutorialText(
                "THE DIPLOMAT",
                "Upgrade your status. Manage your records, official ID photo, and passports here.",
                controller,
              ),
            ),
          ),
        ],
      ),
      // 🌟 NEW: The Concierge Tutorial Step
      TargetFocus(
        identify: "concierge_target",
        keyTarget: _conciergeKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildTutorialText(
              "THE CONCIERGE",
              "Summon your personal guide. We'll scan a 1-mile radius to find the highest-rated culinary gems right around the corner.",
              controller,
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
            // 🌟 THE FIX: Removed `isLast: true`. It will now default to "NEXT" and keep the Skip button!
            builder: (context, controller) => _buildTutorialText(
              "THE COLLECTION",
              "Your Gourmet Passport. Check in to spots, collect official stamps, and build your culinary visa.",
              controller,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildTutorialText(
    String title,
    String description,
    TutorialCoachMarkController controller, {
    bool isLast = false,
  }) {
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
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                isLast ? "DONE" : "NEXT",
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
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
                    letterSpacing: 1.0,
                  ),
                ),
              ),
          ],
        ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
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
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFFF5F5F5),
                            ),
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
                                  setDialogState(
                                    () => doNotShowAgain = !doNotShowAgain,
                                  );
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
                                          setDialogState(
                                            () => doNotShowAgain = val ?? true,
                                          );
                                        },
                                        activeColor: Colors.white,
                                        checkColor: Colors.black,
                                        side: const BorderSide(
                                          color: Colors.white54,
                                        ),
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
        builder: (context) =>
            const PassportCollectionScreen(initialBookId: null),
      ),
    );
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(
      () => savedRestaurantNames =
          (prefs.getStringList('saved_restaurants') ?? []).toSet(),
    );
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
    await prefs.setStringList(
      'saved_restaurants',
      savedRestaurantNames.toList(),
    );
  }

  Future<void> _setupMapboxLayers(Map<String, String> paths) async {
    if (_mapboxController == null) return;

    try {
      final sourceExists =
          await _mapboxController?.style.styleSourceExists("regular-source") ??
          false;
      if (sourceExists) {
        debugPrint("Mapbox sources already exist. Skipping rebuild.");
        return;
      }

      // --- 1. THE LOCAL SOURCES ---
      await _mapboxController?.style.addSource(
        GeoJsonSource(
          id: "regular-source",
          data: "file://${paths['regular']}",
          cluster: true,
          clusterRadius: 75, // 🌟 Sweet spot for your UI width
          clusterMaxZoom:
              20.0, // 🌟 THE HYDRA KILLER: Cluster infinitely to street level
          buffer: 128.0,
        ),
      );
      await _mapboxController?.style.addSource(
        GeoJsonSource(
          id: "heroes-source",
          data: "file://${paths['heroes']}",
          buffer: 128.0,
        ),
      );

      // 🌟 THE INJECTOR VESSEL: Match the infinite clustering!
      await _mapboxController?.style.addSource(
        GeoJsonSource(
          id: "search-source",
          data: '{"type":"FeatureCollection","features":[]}',
          cluster: true,
          clusterRadius: 75, // 🌟 Match regular-source
          clusterMaxZoom: 20.0, // 🌟 Match regular-source
          buffer: 128.0,
        ),
      );

      // --- 2. DEFAULT CLUSTER LAYERS ---
      await _mapboxController?.style.addLayer(
        CircleLayer(id: "cluster-circles", sourceId: "regular-source"),
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-circles",
        "filter",
        ["has", "point_count"],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-circles",
        "circle-color",
        isDarkMode ? "#1E1E1E" : "#FFFFFF",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-circles",
        "circle-stroke-color",
        isDarkMode ? "#FFFFFF" : "#000000",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-circles",
        "circle-stroke-width",
        3.5,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-circles",
        "circle-radius",
        [
          "step",
          ["get", "point_count"],
          18,
          100,
          22,
          1000,
          26,
        ],
      );

      // 🌟 1. UPDATE DEFAULT CLUSTER TEXT
      await _mapboxController?.style.addLayer(
        SymbolLayer(
          id: "cluster-text",
          sourceId: "regular-source",
          textAllowOverlap: true, // 🌟 FORCED IN CONSTRUCTOR
          textIgnorePlacement: true, // 🌟 FORCED IN CONSTRUCTOR
        ),
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-text",
        "filter",
        ["has", "point_count"],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-text",
        "text-field",
        [
          "case",
          [
            "<",
            ["get", "point_count"],
            1000,
          ],
          [
            "to-string",
            ["get", "point_count"],
          ],
          [
            "concat",
            [
              "to-string",
              [
                "floor",
                [
                  "/",
                  ["get", "point_count"],
                  1000,
                ],
              ],
            ],
            "k+",
          ],
        ],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-text",
        "text-font",
        ["Source Code Pro Bold", "Open Sans Bold", "Arial Unicode MS Bold"],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-text",
        "text-size",
        14.0,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-text",
        "text-color",
        isDarkMode ? "#FFFFFF" : "#000000",
      );

      // --- 3. PILL CONFIGURATION ---
      final starsVal = [
        "to-number",
        ["get", "michelin_stars"],
        0,
      ];
      final bibCheck = [
        "==",
        [
          "downcase",
          [
            "to-string",
            ["get", "bib_gourmand"],
          ],
        ],
        "true",
      ];
      final ringType = [
        "case",
        [">", starsVal, 0],
        "gold",
        bibCheck,
        "red",
        "black",
      ];
      final notCluster = [
        "!",
        ["has", "point_count"],
      ]; // 🌟 Helper to prevent drawing pins under clusters

      List<dynamic> emojiCode = ["case"];
      for (var cuisineKeyword in CuisineConstants.emojiPalettes.keys) {
        emojiCode.add([
          "in",
          cuisineKeyword.toLowerCase(),
          [
            "downcase",
            [
              "to-string",
              ["get", "cuisine"],
            ],
          ],
        ]);
        emojiCode.add(cuisineKeyword);
      }
      emojiCode.add("default");
      final dynamicIconImage = [
        "concat",
        "pill-",
        emojiCode,
        "-",
        ringType,
        "-",
        ["to-string", starsVal],
      ];
      final dynamicIconSize = [
        "interpolate",
        ["linear"],
        ["zoom"],
        8.0,
        0.40,
        11.0,
        0.55,
        14.0,
        0.75,
        16.0,
        0.90,
      ];

      // --- 4. DEFAULT REGULAR & HERO LAYERS ---

      await _mapboxController?.style.addLayer(
        SymbolLayer(
          id: "regular-bubbles",
          sourceId: "regular-source",
          minZoom: 1.0,
          iconAllowOverlap: false, // 🌟 Turn the collision bouncer back on
          // 🌟 (Make sure iconIgnorePlacement is completely deleted from this layer)
          iconPitchAlignment: IconPitchAlignment.VIEWPORT,
        ),
      );

      await _mapboxController?.style.setStyleLayerProperty(
        "regular-bubbles",
        "filter",
        notCluster,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "regular-bubbles",
        "icon-image",
        dynamicIconImage,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "regular-bubbles",
        "icon-size",
        dynamicIconSize,
      );

      await _mapboxController?.style.addLayer(
        SymbolLayer(
          id: "heroes-bib-bubbles",
          sourceId: "heroes-source",
          minZoom: 13.0,
          iconAllowOverlap: true,
          iconPitchAlignment: IconPitchAlignment.VIEWPORT,
        ),
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-bib-bubbles",
        "filter",
        [
          "all",
          bibCheck,
          ["==", starsVal, 0],
        ],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-bib-bubbles",
        "icon-image",
        dynamicIconImage,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-bib-bubbles",
        "icon-size",
        dynamicIconSize,
      );

      await _mapboxController?.style.addLayer(
        SymbolLayer(
          id: "heroes-1-bubbles",
          sourceId: "heroes-source",
          minZoom: 12.0,
          iconAllowOverlap: true,
          iconPitchAlignment: IconPitchAlignment.VIEWPORT,
        ),
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-1-bubbles",
        "filter",
        ["==", starsVal, 1],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-1-bubbles",
        "icon-image",
        dynamicIconImage,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-1-bubbles",
        "icon-size",
        dynamicIconSize,
      );

      await _mapboxController?.style.addLayer(
        SymbolLayer(
          id: "heroes-3-2-bubbles",
          sourceId: "heroes-source",
          minZoom: 8.0,
          iconAllowOverlap: true,
          iconPitchAlignment: IconPitchAlignment.VIEWPORT,
        ),
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-3-2-bubbles",
        "filter",
        [">=", starsVal, 2],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-3-2-bubbles",
        "symbol-sort-key",
        [
          "case",
          ["==", starsVal, 3],
          2,
          ["==", starsVal, 2],
          1,
          0,
        ],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-3-2-bubbles",
        "icon-image",
        dynamicIconImage,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-3-2-bubbles",
        "icon-size",
        dynamicIconSize,
      );

      // --- 5. 🌟 THE SEARCH LAYERS (The proper hierarchy) ---

      // A. Search Clusters
      await _mapboxController?.style.addLayer(
        CircleLayer(id: "search-cluster-circles", sourceId: "search-source"),
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-circles",
        "filter",
        ["has", "point_count"],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-circles",
        "circle-color",
        isDarkMode ? "#1E1E1E" : "#FFFFFF",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-circles",
        "circle-stroke-color",
        "#FFB300",
      ); // Amber border so you know it's a search result!
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-circles",
        "circle-stroke-width",
        3.5,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-circles",
        "circle-radius",
        [
          "step",
          ["get", "point_count"],
          18,
          100,
          22,
          1000,
          26,
        ],
      );

      // 🌟 2. UPDATE SEARCH CLUSTER TEXT
      await _mapboxController?.style.addLayer(
        SymbolLayer(
          id: "search-cluster-text",
          sourceId: "search-source",
          textAllowOverlap: true, // 🌟 FORCED IN CONSTRUCTOR
          textIgnorePlacement: true, // 🌟 FORCED IN CONSTRUCTOR
        ),
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-text",
        "filter",
        ["has", "point_count"],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-text",
        "text-field",
        [
          "case",
          [
            "<",
            ["get", "point_count"],
            1000,
          ],
          [
            "to-string",
            ["get", "point_count"],
          ],
          [
            "concat",
            [
              "to-string",
              [
                "floor",
                [
                  "/",
                  ["get", "point_count"],
                  1000,
                ],
              ],
            ],
            "k+",
          ],
        ],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-text",
        "text-font",
        ["Source Code Pro Bold", "Open Sans Bold", "Arial Unicode MS Bold"],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-text",
        "text-size",
        14.0,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-text",
        "text-color",
        isDarkMode ? "#FFFFFF" : "#000000",
      );

      // B. Search Regular
      await _mapboxController?.style.addLayer(
        SymbolLayer(
          id: "search-regular-bubbles",
          sourceId: "search-source",
          iconAllowOverlap: true,
          iconPitchAlignment: IconPitchAlignment.VIEWPORT,
        ),
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-regular-bubbles",
        "filter",
        notCluster,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-regular-bubbles",
        "icon-image",
        dynamicIconImage,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-regular-bubbles",
        "icon-size",
        dynamicIconSize,
      );

      // C. Search Bib
      await _mapboxController?.style.addLayer(
        SymbolLayer(
          id: "search-bib-bubbles",
          sourceId: "search-source",
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconPitchAlignment: IconPitchAlignment.VIEWPORT,
        ),
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-bib-bubbles",
        "filter",
        [
          "all",
          notCluster,
          bibCheck,
          ["==", starsVal, 0],
        ],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-bib-bubbles",
        "icon-image",
        dynamicIconImage,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-bib-bubbles",
        "icon-size",
        dynamicIconSize,
      );

      // D. Search 1-Star
      await _mapboxController?.style.addLayer(
        SymbolLayer(
          id: "search-1-bubbles",
          sourceId: "search-source",
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconPitchAlignment: IconPitchAlignment.VIEWPORT,
        ),
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-1-bubbles",
        "filter",
        [
          "all",
          notCluster,
          ["==", starsVal, 1],
        ],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-1-bubbles",
        "icon-image",
        dynamicIconImage,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-1-bubbles",
        "icon-size",
        dynamicIconSize,
      );

      // E. Search 3 & 2-Star (Rendered last, stays on top!)
      await _mapboxController?.style.addLayer(
        SymbolLayer(
          id: "search-3-2-bubbles",
          sourceId: "search-source",
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconPitchAlignment: IconPitchAlignment.VIEWPORT,
        ),
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-3-2-bubbles",
        "filter",
        [
          "all",
          notCluster,
          [">=", starsVal, 2],
        ],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-3-2-bubbles",
        "symbol-sort-key",
        [
          "case",
          ["==", starsVal, 3],
          2,
          ["==", starsVal, 2],
          1,
          0,
        ],
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-3-2-bubbles",
        "icon-image",
        dynamicIconImage,
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-3-2-bubbles",
        "icon-size",
        dynamicIconSize,
      );

      // Start all search layers hidden
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-circles",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-text",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-regular-bubbles",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-bib-bubbles",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-1-bubbles",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-3-2-bubbles",
        "visibility",
        "none",
      );

      // NATIVE LOCATION PUCK
      await _mapboxController?.location.updateSettings(
        LocationComponentSettings(enabled: false),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      await _mapboxController?.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: true,
        ),
      );
    } catch (e) {
      debugPrint("🚨 Layer Error: $e");
    }
  }

  // =========================================================================
  // 👆 4. THE INTERACTION BRIDGE (Mapbox Tap Listener)
  // =========================================================================
  Future<void> _handleMapTap(MapContentGestureContext context) async {
    if (_mapboxController == null) return;

    try {
      final screenCoord = await _mapboxController!.pixelForCoordinate(
        context.point,
      );
      final double tapRadius = 25.0;
      final Map<String, dynamic> tapBoxMap = {
        "min": {"x": screenCoord.x - tapRadius, "y": screenCoord.y - tapRadius},
        "max": {"x": screenCoord.x + tapRadius, "y": screenCoord.y + tapRadius},
      };

      final geometry = RenderedQueryGeometry(
        value: jsonEncode(tapBoxMap),
        type: Type.SCREEN_BOX,
      );

      final options = RenderedQueryOptions(
        layerIds: [
          "search-heroes-3-2-bubbles",
          "heroes-3-2-bubbles",
          "search-heroes-1-bubbles",
          "heroes-1-bubbles",
          "search-bib-bubbles",
          "heroes-bib-bubbles",
          "search-regular-bubbles",
          "regular-bubbles",
          "search-cluster-circles",
          "cluster-circles",
        ],
      );

      final features = await _mapboxController!.queryRenderedFeatures(
        geometry,
        options,
      );

      if (features.isNotEmpty) {
        final List<String> layerPriority = [
          "search-heroes-3-2-bubbles",
          "heroes-3-2-bubbles",
          "search-heroes-1-bubbles",
          "heroes-1-bubbles",
          "search-bib-bubbles",
          "heroes-bib-bubbles",
          "search-regular-bubbles",
          "regular-bubbles",
          "search-cluster-circles",
          "cluster-circles",
        ];

        // 🌟 1. NEW HELPER VARIABLES
        Map<String, dynamic>? selectedFeatureProps;
        Map<String, dynamic>? selectedFeatureGeom;
        Map<String, dynamic>? selectedRawFeature; // 🌟 SAVES THE RAW FEATURE
        bool isClusterTap = false;
        bool isSearchLayerTap = false; // 🌟 TRACKS WHICH SOURCE WAS TAPPED

        // Funnel through our strict hierarchy
        for (String layerId in layerPriority) {
          final match = features.firstWhere(
            (f) => f?.layers.contains(layerId) == true,
            orElse: () => null,
          );

          if (match != null) {
            final rawFeature = match.queriedFeature.feature as Map?;
            if (rawFeature != null) {
              final featureMap = Map<String, dynamic>.from(rawFeature);

              selectedRawFeature = featureMap; // 🌟 SAVE IT HERE!

              final rawProps = featureMap['properties'] as Map?;
              selectedFeatureProps = rawProps != null
                  ? Map<String, dynamic>.from(rawProps)
                  : null;

              final rawGeom = featureMap['geometry'] as Map?;
              selectedFeatureGeom = rawGeom != null
                  ? Map<String, dynamic>.from(rawGeom)
                  : null;

              isClusterTap =
                  layerId == "cluster-circles" ||
                  layerId == "search-cluster-circles";
              isSearchLayerTap = layerId.startsWith("search-");

              break;
            }
          }
        }

        if (selectedFeatureProps == null) return;

        // --- Execute the Interaction ---
        final isCluster =
            isClusterTap ||
            selectedFeatureProps['cluster'] == true ||
            selectedFeatureProps.containsKey('point_count');

        if (isCluster) {
          final currentZoom = await _mapboxController!.getCameraState().then(
            (s) => s.zoom,
          );

          // 🌟 THE FIX: Lowered altitude trigger to 16.0
          if (currentZoom >= 16.0 && selectedRawFeature != null) {
            try {
              String sourceToQuery = isSearchLayerTap
                  ? "search-source"
                  : "regular-source";

              final extensionValue = await _mapboxController!
                  .getGeoJsonClusterLeaves(
                    sourceToQuery,
                    selectedRawFeature,
                    50,
                    0,
                  );

              if (mounted) {
                // 🌟 THE FIX: Send EVERYTHING. The Omni-parser will find the data.
                _showClusterCrackerSheet(
                  extensionValue.value ??
                      extensionValue.featureCollection ??
                      extensionValue,
                );
              }
            } catch (e) {
              debugPrint("🚨 Failed to crack cluster: $e");
            }
            return;
          }

          // Normal Zoom-In behavior for zooming out
          final coords = selectedFeatureGeom?['coordinates'] as List<dynamic>?;
          if (coords != null && coords.length >= 2) {
            _mapboxController!.flyTo(
              CameraOptions(
                center: Point(
                  coordinates: Position(
                    (coords[0] as num).toDouble(),
                    (coords[1] as num).toDouble(),
                  ),
                ),
                zoom: currentZoom + 2.5,
              ),
              MapAnimationOptions(duration: 500),
            );
          }
          return;
        }

        // Must be a restaurant! Open the sheet.
        if (selectedFeatureProps['id'] != null) {
          final int restaurantId = int.parse(
            selectedFeatureProps['id'].toString(),
          );
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
    // 🌟 1. THE OFFLINE BOUNCER
    if (_isOffline) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(
                  CupertinoIcons.wifi_exclamationmark,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Connect to the internet to view restaurant profiles.",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'SFPro',
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.amber[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return; // Stop the function dead in its tracks
    }

    // 🌟 2. THE DOUBLE-TAP BOUNCER
    if (_isFetchingSheet) return;

    // 🌟 3. Lock the door
    _isFetchingSheet = true;

    // ... (Keep the rest of your try/catch Supabase logic exactly the same)

    try {
      final data = await Supabase.instance.client
          .from('restaurants')
          .select()
          .eq('id', restaurantId)
          .single();

      final restaurant = Restaurant.fromMap(data);

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
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
    } finally {
      // 🌟 3. Unlock the door once the data is fetched (or if it crashes)
      // We use a tiny 300ms delay to ensure the bottom sheet has enough time
      // to physically animate up and block the screen before unlocking.
      Future.delayed(const Duration(milliseconds: 300), () {
        _isFetchingSheet = false;
      });
    }
  }

  // =========================================================================
  // 🏢 THE CLUSTER CRACKER MENU (For co-located restaurants)
  // =========================================================================
  void _showClusterCrackerSheet(dynamic leavesData) {
    if (leavesData == null) return;

    List<dynamic> leaves = [];

    // 🌟 THE OMNI-PARSER: Mapbox returns strongly-typed objects that break standard Map casting.
    // We force it through a JSON serialization tunnel to strip the types and get pure Maps.
    try {
      String jsonStr;
      try {
        jsonStr = jsonEncode(leavesData); // Tries standard encode
      } catch (_) {
        jsonStr = jsonEncode(
          (leavesData as dynamic).toJson(),
        ); // Fallback to Mapbox's native .toJson()
      }

      final decoded = jsonDecode(jsonStr);

      if (decoded is List) {
        leaves = decoded;
      } else if (decoded is Map && decoded.containsKey('features')) {
        leaves = decoded['features'] as List<dynamic>;
      } else if (decoded is Map && decoded.containsKey('value')) {
        final inner = decoded['value'];
        if (inner is List) {
          leaves = inner;
        } else if (inner is Map && inner.containsKey('features'))
          leaves = inner['features'];
      }
    } catch (e) {
      debugPrint("🚨 Omni-Parser Failed: $e");
    }

    List<Map<String, dynamic>> restaurantsInBuilding = [];

    for (var leaf in leaves) {
      try {
        // Now that the types are stripped, this standard Map cast will work flawlessly
        final feature = leaf as Map<String, dynamic>;
        final props = feature['properties'] as Map<String, dynamic>;

        // Mapbox converts ID to a string or int depending on the build, so check for name
        if (props.containsKey('name')) {
          restaurantsInBuilding.add(props);
        }
      } catch (e) {
        debugPrint("🚨 Failed to parse leaf: $e");
      }
    }

    if (restaurantsInBuilding.isEmpty) {
      debugPrint(
        "🚨 Cluster Cracker Aborted: No valid restaurants found in the parsed leaves.",
      );
      return;
    }

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // The Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.domain,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Multiple Locations Here",
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontFamily: 'AppleGaramond',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(color: isDarkMode ? Colors.white10 : Colors.black12),

                // The List of Restaurants
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: restaurantsInBuilding.length,
                    itemBuilder: (context, index) {
                      final r = restaurantsInBuilding[index];

                      // Extract pill design logic for the leading icon
                      final stars =
                          int.tryParse(
                            r['michelin_stars']?.toString() ?? '0',
                          ) ??
                          0;
                      final isBib =
                          r['bib_gourmand']?.toString().toLowerCase() == 'true';
                      Color ringColor = Colors.transparent;
                      if (stars > 0) {
                        ringColor = const Color(0xFFFFD700); // Gold
                      } else if (isBib)
                        ringColor = Colors.redAccent;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: ringColor != Colors.transparent
                                ? Border.all(color: ringColor, width: 2)
                                : null,
                            color: isDarkMode
                                ? Colors.white10
                                : Colors.black.withOpacity(0.05),
                          ),
                          child: Center(
                            child: Text(
                              _formatCategoryDisplay(
                                r['cuisine']?.toString() ?? '',
                              ).split(' ').last, // Gets the emoji
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        title: Text(
                          r['name']?.toString() ?? 'Unknown',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'SFPro',
                          ),
                        ),
                        subtitle: Text(
                          "${_formatCategoryDisplay(r['cuisine']?.toString() ?? '').replaceAll(RegExp(r'[^\w\s]'), '')} • ${r['price']?.toString() ?? '\$'}",
                          style: TextStyle(
                            color: isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        onTap: () {
                          // Close the cracker menu
                          Navigator.pop(context);
                          // Pass the selected ID to your existing full-screen logic
                          final id = int.tryParse(r['id']?.toString() ?? '');
                          if (id != null) {
                            _fetchAndShowRestaurant(id);
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // 🔍 INSTANT MAPBOX FILTER ENGINE
  // =========================================================================
  void _fetchRestaurants() async {
    if (_mapboxController == null) return;

    bool hasActiveFilters =
        selectedCategory != null ||
        selectedRestaurantName != null ||
        _showVegetarian ||
        _showVegan ||
        savedOnly ||
        _selectedPrices.isNotEmpty ||
        _selectedMichelin.isNotEmpty ||
        showOpenOnly;

    // 🌟 INSTANT REACTION: Turn on the bridge immediately
    if (mounted) setState(() => _isFilteringMap = true);

    // Helper to clear map if a filter combination returns zero results
    Future<void> injectEmptySearch() async {
      if (mounted) {
        setState(() => _showNoResultsOverlay = true); // 🌟 SHOW THE OVERLAY
      }
      await _mapboxController?.style.setStyleSourceProperty(
        "search-source",
        "data",
        '{"type": "FeatureCollection", "features": []}',
      );

      // Hide default
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-circles",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-text",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "regular-bubbles",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-bib-bubbles",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-1-bubbles",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-3-2-bubbles",
        "visibility",
        "none",
      );

      // Show Search Layers
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-circles",
        "visibility",
        "visible",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-text",
        "visibility",
        "visible",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-regular-bubbles",
        "visibility",
        "visible",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-bib-bubbles",
        "visibility",
        "visible",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-1-bubbles",
        "visibility",
        "visible",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-3-2-bubbles",
        "visibility",
        "visible",
      );
    }

    try {
      if (!hasActiveFilters) {
        // 🌟 RESET: Restore default hierarchy, hide the search layers & no-results overlay
        if (mounted) setState(() => _showNoResultsOverlay = false);

        await _mapboxController?.style.setStyleLayerProperty(
          "search-cluster-circles",
          "visibility",
          "none",
        );
        await _mapboxController?.style.setStyleLayerProperty(
          "search-cluster-text",
          "visibility",
          "none",
        );
        await _mapboxController?.style.setStyleLayerProperty(
          "search-regular-bubbles",
          "visibility",
          "none",
        );
        await _mapboxController?.style.setStyleLayerProperty(
          "search-bib-bubbles",
          "visibility",
          "none",
        );
        await _mapboxController?.style.setStyleLayerProperty(
          "search-1-bubbles",
          "visibility",
          "none",
        );
        await _mapboxController?.style.setStyleLayerProperty(
          "search-3-2-bubbles",
          "visibility",
          "none",
        );

        await _mapboxController?.style.setStyleLayerProperty(
          "cluster-circles",
          "visibility",
          "visible",
        );
        await _mapboxController?.style.setStyleLayerProperty(
          "cluster-text",
          "visibility",
          "visible",
        );
        await _mapboxController?.style.setStyleLayerProperty(
          "regular-bubbles",
          "visibility",
          "visible",
        );
        await _mapboxController?.style.setStyleLayerProperty(
          "heroes-bib-bubbles",
          "visibility",
          "visible",
        );
        await _mapboxController?.style.setStyleLayerProperty(
          "heroes-1-bubbles",
          "visibility",
          "visible",
        );
        await _mapboxController?.style.setStyleLayerProperty(
          "heroes-3-2-bubbles",
          "visibility",
          "visible",
        );
        return;
      }

      // 🌟 OFFLINE CHECK
      if (_isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Search mapping requires an internet connection.",
              style: TextStyle(fontFamily: 'SFPro'),
            ),
            backgroundColor: Colors.amber[800],
          ),
        );
        return;
      }

      // 🌟 BUILD SUPABASE QUERY
      var query = Supabase.instance.client.from('restaurants').select();

      if (selectedRestaurantName != null) {
        query = query.eq('name', selectedRestaurantName!);
      } else if (selectedCategory != null) {
        query = query.ilike('cuisine', '%${selectedCategory!}%');
      }

      if (_showVegetarian) query = query.eq('is_vegetarian', true);
      if (_showVegan) query = query.eq('is_vegan', true);

      if (savedOnly) {
        if (savedRestaurantNames.isEmpty) {
          await injectEmptySearch();
          return;
        } else {
          query = query.inFilter('name', savedRestaurantNames.toList());
        }
      }

      if (_selectedPrices.isNotEmpty) {
        query = query.inFilter('price', _selectedPrices.toList());
      }

      if (_selectedMichelin.isNotEmpty) {
        List<String> orConditions = [];
        if (_selectedMichelin.contains("Bib Gourmand")) {
          orConditions.add('bib_gourmand.eq.true');
        }
        if (_selectedMichelin.contains("1 Star")) {
          orConditions.add('michelin_stars.eq.1');
        }
        if (_selectedMichelin.contains("2 Stars")) {
          orConditions.add('michelin_stars.eq.2');
        }
        if (_selectedMichelin.contains("3 Stars")) {
          orConditions.add('michelin_stars.eq.3');
        }

        if (orConditions.isNotEmpty) {
          query = query.or(orConditions.join(','));
        }
      }

      if (showOpenOnly) {
        List<int> openIds = [];
        final nycTime = DateTime.now().toUtc().subtract(
          const Duration(hours: 4),
        );
        _restaurantHours.forEach((id, hoursString) {
          if (OSMTimeParser.isOpen(hoursString, nycTime)) {
            openIds.add(int.parse(id));
          }
        });

        if (openIds.length > 400) openIds = openIds.sublist(0, 400);

        if (openIds.isEmpty) {
          await injectEmptySearch();
          return;
        } else {
          query = query.inFilter('id', openIds);
        }
      }

      // 🌟 FETCH & CONVERT (Limit applied!)
      final data = await query.limit(2000);

      // 🌟 CHECK FOR EMPTY DATA
      if (data.isEmpty) {
        await injectEmptySearch();
        return;
      }

      // 🌟 HIDE OVERLAY ON SUCCESS
      if (mounted) setState(() => _showNoResultsOverlay = false);

      List<Map<String, dynamic>> features = data.map((r) {
        return {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [r['lng'], r['lat']],
          },
          "properties": r,
        };
      }).toList();

      final String geoJsonPayload = jsonEncode({
        "type": "FeatureCollection",
        "features": features,
      });

      // 🌟 INJECT & SWAP LAYERS
      await _mapboxController?.style.setStyleSourceProperty(
        "search-source",
        "data",
        geoJsonPayload,
      );

      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-circles",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "cluster-text",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "regular-bubbles",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-bib-bubbles",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-1-bubbles",
        "visibility",
        "none",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "heroes-3-2-bubbles",
        "visibility",
        "none",
      );

      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-circles",
        "visibility",
        "visible",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-cluster-text",
        "visibility",
        "visible",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-regular-bubbles",
        "visibility",
        "visible",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-bib-bubbles",
        "visibility",
        "visible",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-1-bubbles",
        "visibility",
        "visible",
      );
      await _mapboxController?.style.setStyleLayerProperty(
        "search-3-2-bubbles",
        "visibility",
        "visible",
      );
    } catch (e) {
      debugPrint("🚨 Injector Error: $e");
    } finally {
      // 🌟 DROP THE BRIDGE: Whether it succeeds or fails, kill the loader when done.
      if (mounted) setState(() => _isFilteringMap = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // 🌟 For Android: Controls the color of the icons directly
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        // 🌟 For iOS: Tells the OS the background is dark, so it makes the icons white
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );

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

              // 🌟 THE FIX: The microsecond the engine turns over, force it to sync with the app's saved memory.
              _mapboxController?.loadStyleURI(
                isDarkMode ? MapboxStyles.DARK : MapboxStyles.STANDARD,
              );

              // 🌟 Turn on the native Location Puck!
              _mapboxController?.location.updateSettings(
                LocationComponentSettings(
                  enabled: true,
                  pulsingEnabled: true, // Gives it a cool radar pulse effect
                  showAccuracyRing:
                      true, // Shows the transparent circle of GPS accuracy
                ),
              );

              _mapboxController?.gestures.updateSettings(
                GesturesSettings(pitchEnabled: false),
              );

              _mapboxController?.scaleBar.updateSettings(
                ScaleBarSettings(enabled: false),
              );

              _mapboxController?.compass.updateSettings(
                CompassSettings(
                  position: OrnamentPosition.TOP_RIGHT,
                  marginTop: 100.0,
                ),
              );

              _mapboxController?.logo.updateSettings(
                LogoSettings(
                  position: OrnamentPosition.BOTTOM_LEFT,
                  marginBottom: 90.0,
                ),
              );

              _mapboxController?.attribution.updateSettings(
                AttributionSettings(
                  position: OrnamentPosition.BOTTOM_LEFT,
                  marginBottom: 90.0,
                  marginLeft: 90.0,
                ),
              );
            },
            onTapListener: _handleMapTap,
            onStyleImageMissingListener:
                (StyleImageMissingEventData event) async {
                  final String missingId = event.id;
                  if (!missingId.startsWith("pill-")) return;
                  final parts = missingId.split("-");
                  if (parts.length >= 4) {
                    final int stars = int.tryParse(parts.last) ?? 0;
                    final String ringType = parts[parts.length - 2];
                    final String cuisine = parts
                        .sublist(1, parts.length - 2)
                        .join("-");
                    // The PillCache naturally respects the isDarkMode flag!
                    final pillData = await PillCache.getOrGeneratePill(
                      missingId,
                      cuisine,
                      ringType,
                      stars,
                      isDarkMode,
                    );
                    await _mapboxController?.style.addStyleImage(
                      missingId,
                      1.0,
                      MbxImage(
                        width: pillData.width,
                        height: pillData.height,
                        data: pillData.data,
                      ),
                      false,
                      [],
                      [],
                      null,
                    );
                  }
                },
            onStyleLoadedListener: (StyleLoadedEventData data) async {
              // 🌟 INCREASE DELAY: Give the map 1.5 seconds to render the streets first
              await Future.delayed(const Duration(milliseconds: 1500));

              if (_vaultPaths != null) _setupMapboxLayers(_vaultPaths!);

              // 2. Only jump the camera on the very first app launch
              if (!_hasPerformedInitialCameraFly) {
                _hasPerformedInitialCameraFly = true;
                _mapboxController?.flyTo(
                  CameraOptions(
                    center: myLocation != null
                        ? Point(
                            coordinates: Position(
                              myLocation!.longitude,
                              myLocation!.latitude,
                            ),
                          )
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
                      padding: const EdgeInsets.only(left: 24, right: 12),
                      decoration: BoxDecoration(
                        // 🌟 1. Lighten the dark mode grey slightly (from 2C2C2E to 3A3A3C)
                        color: isDarkMode
                            ? const Color(0xFF3A3A3C)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(100),

                        // 🌟 2. The "Hairline Border" (Only visible in Dark Mode)
                        border: isDarkMode
                            ? Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1.0,
                              )
                            : null,

                        boxShadow: [
                          BoxShadow(
                            // 🌟 3. Make the dark mode shadow much wider and darker to create a "void" around the pill
                            color: Colors.black.withOpacity(
                              isDarkMode ? 0.4 : 0.12,
                            ),
                            blurRadius: isDarkMode ? 24 : 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 22,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: GestureDetector(
                              onTap: _openSearchPage,
                              child: Container(
                                color: Colors.transparent,
                                child:
                                    (selectedCategory == null &&
                                        selectedRestaurantName == null)
                                    ? AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 400,
                                        ),
                                        transitionBuilder:
                                            (
                                              Widget child,
                                              Animation<double> animation,
                                            ) {
                                              return FadeTransition(
                                                opacity: animation,
                                                child: SlideTransition(
                                                  position: Tween<Offset>(
                                                    begin: const Offset(
                                                      -0.03,
                                                      0,
                                                    ),
                                                    end: Offset.zero,
                                                  ).animate(animation),
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: child,
                                                  ),
                                                ),
                                              );
                                            },
                                        child: Text(
                                          _searchPhrases[_currentPhraseIndex],
                                          key: ValueKey(
                                            _searchPhrases[_currentPhraseIndex],
                                          ),
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white70
                                                : Colors.black.withOpacity(0.6),
                                            fontSize: 17,
                                            fontFamily: 'SF Pro Text',
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.4,
                                          ),
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
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            fontSize: 17,
                                            fontFamily: 'SF Pro Text',
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.4,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          // 🌟 CLEAR BUTTON
                          if (selectedCategory != null ||
                              selectedRestaurantName != null)
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
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white10
                                      : Colors.black12,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),

                          // PROFILE AVATAR
                          GestureDetector(
                            key: _profileKey,
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await openProfileScreen(
                                context,
                                name: _userName,
                                photoUrl: _userPhotoUrl,
                                gender: _userGender,
                                age: _userAge,
                              );
                              await _fetchUserProfile(forceRefresh: true);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDarkMode
                                      ? Colors.white12
                                      : Colors.black.withOpacity(0.05),
                                  width: 1,
                                ),
                              ),
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
                      onOpenChanged: (v) {
                        setState(() => showOpenOnly = v);
                        _fetchRestaurants();
                      },
                      onSavedChanged: (v) {
                        setState(() => savedOnly = v);
                        _fetchRestaurants();
                      },
                      onVegChanged: (v) {
                        setState(() => _showVegetarian = v);
                        _fetchRestaurants();
                      },
                      onVeganChanged: (v) {
                        setState(() => _showVegan = v);
                        _fetchRestaurants();
                      },
                      onMichelinChanged: (v) {
                        setState(() => _selectedMichelin = v);
                        _fetchRestaurants();
                      },
                      onPriceChanged: (v) {
                        setState(() => _selectedPrices = v);
                        _fetchRestaurants();
                      },
                    ),

                    // 🌟 THE NO RESULTS OVERLAY (Moved inside the Column for dynamic responsive anchoring)
                    if (_showNoResultsOverlay && !_isFilteringMap)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 16.0,
                          left: 16.0,
                          right: 16.0,
                        ), // Anchors dynamically!
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  isDarkMode ? 0.3 : 0.08,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: 40.0,
                                sigmaY: 40.0,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 36,
                                ),
                                decoration: BoxDecoration(
                                  // Your updated opacity values here
                                  color: isDarkMode
                                      ? const Color(
                                          0xFF1C1C1E,
                                        ).withOpacity(0.40)
                                      : Colors.white.withOpacity(0.50),
                                  border: Border.all(
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.15)
                                        : Colors.white.withOpacity(0.5),
                                    width: 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.black.withOpacity(0.04),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.search,
                                        size: 36,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      "No Results Found",
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                        fontFamily: 'AppleGaramond',
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Try adjusting your filters or zooming out to cast a wider net across the city.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black87,
                                        fontFamily: 'SFPro',
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    SizedBox(
                                      width: 200,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          setState(() {
                                            selectedCategory = null;
                                            selectedRestaurantName = null;
                                            showOpenOnly = false;
                                            savedOnly = false;
                                            _showVegetarian = false;
                                            _showVegan = false;
                                            _selectedMichelin.clear();
                                            _selectedPrices.clear();
                                          });
                                          _fetchRestaurants();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                          foregroundColor: isDarkMode
                                              ? Colors.black
                                              : Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          "Clear Filters",
                                          style: TextStyle(
                                            fontFamily: 'SFPro',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
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
                    // 🌟 CONCIERGE BUTTON
                    // 🌟 CONCIERGE BUTTON
                    FloatingActionButton(
                      key: _conciergeKey,
                      heroTag: 'concierge_btn',
                      mini: true,
                      backgroundColor: isDarkMode
                          ? Colors.grey[800]
                          : Colors.white,
                      // Dim the icon to grey if offline to give a visual clue
                      foregroundColor: _isOffline
                          ? Colors.grey
                          : Colors.amber[700],
                      elevation: 6,
                      onPressed: () {
                        // 🌟 THE OFFLINE BOUNCER
                        if (_isOffline) {
                          HapticFeedback.heavyImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                "The Concierge requires an active internet connection to scan the area.",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'SFPro',
                                ),
                              ),
                              backgroundColor: Colors.redAccent[700],
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              margin: const EdgeInsets.only(
                                bottom: 20,
                                left: 20,
                                right: 20,
                              ),
                            ),
                          );
                          return; // Bounce them
                        }

                        setState(() {
                          _showConcierge = true;
                        });
                        TelemetryService.logInteraction(
                          actionType: 'concierge_summoned',
                        );
                      },
                      child: const Icon(Icons.room_service),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      key: _wheelKey,
                      mini: true,
                      heroTag: "wheel_btn",
                      backgroundColor: isDarkMode
                          ? Colors.indigoAccent
                          : Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      elevation: 6,
                      onPressed: _openCountryWheel,
                      child: const Icon(Icons.casino),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      mini: true,
                      heroTag: "theme_btn",
                      backgroundColor: isDarkMode
                          ? Colors.grey[800]
                          : Colors.white,
                      foregroundColor: isDarkMode ? Colors.white : Colors.black,
                      elevation: 4,
                      onPressed: _toggleTheme,
                      child: Icon(
                        isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      ),
                    ),
                    FloatingActionButton(
                      mini: true,
                      heroTag: "gps_btn",
                      backgroundColor: isDarkMode
                          ? Colors.grey[800]
                          : Colors.white,
                      foregroundColor: isDarkMode ? Colors.white : Colors.black,
                      elevation: 4,
                      onPressed: _recenterMap,
                      child: Icon(
                        myLocation == null
                            ? CupertinoIcons.location_slash_fill
                            : CupertinoIcons.location_fill,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.add,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            onPressed: () => _zoom(1),
                          ),
                          Container(
                            height: 1,
                            width: 30,
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.remove,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            onPressed: () => _zoom(-1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===================================================================
          // 4. OVERLAYS & CONCIERGE
          // ===================================================================

          // 🌟 THE NEW CONCIERGE OVERLAY
          if (_showConcierge && myLocation != null)
            ConciergeOverlay(
              isDarkMode: isDarkMode,
              userLocation: LatLng(myLocation!.latitude, myLocation!.longitude),
              // 👇 REMOVED: allRestaurants: const [],
              onClose: () {
                setState(() {
                  _showConcierge = false;
                });
              },
              onRestaurantTapped: (Restaurant r) {
                // ... your bottom sheet code remains exactly the same
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => RestaurantDetailSheet(
                    restaurant: r,
                    isDarkMode: isDarkMode,
                    // 🌟 FIX: Connects to your actual map_screen state variables!
                    isSaved: savedRestaurantNames.contains(r.name),
                    myLocation: myLocation,
                    onFavoriteToggle: () => _toggleFavorite(r.name),
                  ),
                );
              },
            ),

          // 🌟 THE FILTER BRIDGE: A sleek, highly visible loading pill
          if (_isFilteringMap)
            Positioned(
              top:
                  160, // 🌟 Pushed down further to clear the horizontal filter bar
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    30,
                  ), // Flawless rounded edges
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: 15.0,
                      sigmaY: 15.0,
                    ), // Heavier glass blur
                    child: Container(
                      // 🌟 Bigger padding for a larger pill footprint
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        // Slightly more opaque so it punches through the map background
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.75)
                            : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white30
                              : Colors.black12, // Stronger border
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🌟 Bigger Apple-style spinner
                          const CupertinoActivityIndicator(radius: 12),
                          const SizedBox(width: 12),
                          Text(
                            "Updating Map...",
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontFamily: 'SFPro',
                              fontSize: 15, // 🌟 Larger text
                              fontWeight: FontWeight.w700, // 🌟 Bolder text
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (_isJumpingToLocation)
            Positioned.fill(
              child: Container(
                color: isDarkMode ? Colors.black54 : Colors.white54,
                child: const Center(
                  child: CupertinoActivityIndicator(radius: 16),
                ),
              ),
            ),

          // 🌟 THE FIX: The new gorgeous loading overlay
          if (_isBuildingVault)
            Positioned.fill(
              child: VaultLoadingOverlay(
                isDarkMode: isDarkMode,
                isOffline: _isOffline,
              ),
            ),
        ],
      ),
      // =======================================================================
      // 5. FAB (PASSPORT)
      // =======================================================================
      // 🌟 THE FIX: Completely hide the FAB if the loading screen is active
      floatingActionButton: _isBuildingVault
          ? null
          : FloatingActionButton(
              key: _passportKey,
              backgroundColor: Colors.amber,
              child: const Icon(Icons.filter_none, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const PassportCollectionScreen(initialBookId: null),
                  ),
                );
              },
            ),
    );
  }
}

// =========================================================================
// 🌟 THE SMOKE & MIRRORS LOADING SCREEN (V3 - THE SIRI ORB)
// =========================================================================
class VaultLoadingOverlay extends StatefulWidget {
  final bool isDarkMode;
  final bool isOffline;

  const VaultLoadingOverlay({
    super.key,
    required this.isDarkMode,
    required this.isOffline,
  });

  @override
  State<VaultLoadingOverlay> createState() => _VaultLoadingOverlayState();
}

// 🌟 Changed to TickerProviderStateMixin to handle multiple animation controllers!
class _VaultLoadingOverlayState extends State<VaultLoadingOverlay>
    with TickerProviderStateMixin {
  int _fakeCount = 0;
  Timer? _timer;
  late DateTime _startTime;

  late AnimationController _pulseController;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    // The Throbbing Core
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    // The Rotating Siri Aura
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _startFakeCounter();
  }

  void _startFakeCounter() {
    _timer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (widget.isOffline) {
        _startTime = _startTime.add(const Duration(milliseconds: 40));
        return;
      }

      if (mounted) {
        final elapsedMs = DateTime.now().difference(_startTime).inMilliseconds;

        setState(() {
          int targetCount = (elapsedMs * 4.78).round();

          if (targetCount > 35850) {
            targetCount = 35850 + ((elapsedMs - 7500) / 300).round();
            if (targetCount > 35999) targetCount = 35999;
          }

          if (targetCount > _fakeCount) _fakeCount = targetCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressPercentage = (_fakeCount / 36000).clamp(0.0, 1.0);
    final accentColor = widget.isOffline
        ? Colors.redAccent
        : (widget.isDarkMode ? Colors.white : Colors.black);

    // 🌟 Forces the battery and time to be black on the white screen
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
          child: Container(
            color: widget.isDarkMode
                ? const Color(0xFF121212).withOpacity(0.85)
                : const Color(0xFFF5F5F7).withOpacity(0.95),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🌟 1. THE SIRI ORB (V3.3 - Flawless Continuous Mesh & Throbbing Core)
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Center(
                    // 🌟 FIX 1: The pulse is back! Wrapping the entire orb in the scale animation.
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: widget.isOffline
                              ? 1.0
                              : 1.0 + (_pulseController.value * 0.08),
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: Colors.black, // The deep black core
                              shape: BoxShape.circle,
                              boxShadow: widget.isOffline
                                  ? [
                                      BoxShadow(
                                        color: Colors.redAccent.withOpacity(
                                          0.4,
                                        ),
                                        blurRadius: 30,
                                        spreadRadius: 10,
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                            ),
                            child: ClipOval(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Layer A: The Continuous Swirling Smoke
                                  if (!widget.isOffline)
                                    AnimatedBuilder(
                                      animation: _rotationController,
                                      builder: (context, child) {
                                        return ImageFiltered(
                                          imageFilter: ui.ImageFilter.blur(
                                            sigmaX: 14.0,
                                            sigmaY: 14.0,
                                          ),
                                          child: Container(
                                            // 🌟 Make this larger than 90x90 so the blur doesn't fade at the edges
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: SweepGradient(
                                                // 🌟 FIX 2: Rotate the gradient mathematically. No more shutter!
                                                transform: GradientRotation(
                                                  _rotationController.value *
                                                      2 *
                                                      math.pi,
                                                ),
                                                colors: [
                                                  const Color(
                                                    0xFF007AFF,
                                                  ).withOpacity(0.85), // Blue
                                                  const Color(
                                                    0xFFFF2D55,
                                                  ).withOpacity(0.85), // Red
                                                  const Color(
                                                    0xFFFFCC00,
                                                  ).withOpacity(0.85), // Yellow
                                                  const Color(
                                                    0xFF007AFF,
                                                  ).withOpacity(
                                                    0.85,
                                                  ), // Seamless Loop
                                                ],
                                                stops: const [
                                                  0.0,
                                                  0.33,
                                                  0.66,
                                                  1.0,
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                  // Layer B: The Icon on top
                                  Icon(
                                    widget.isOffline
                                        ? CupertinoIcons.wifi_exclamationmark
                                        : Icons.restaurant,
                                    size: 38,
                                    color: widget.isOffline
                                        ? Colors.redAccent
                                        : Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // 🌟 2. THE TEXT UPDATES
                Text(
                  widget.isOffline ? "SIGNAL LOST" : "INITIALIZING VAULT",
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.0,
                    color: widget.isOffline
                        ? Colors.redAccent
                        : (widget.isDarkMode ? Colors.white54 : Colors.black54),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  widget.isOffline
                      ? "Awaiting Network Connection"
                      : "Fetching Restaurants...",
                  style: TextStyle(
                    fontFamily: 'AppleGaramond',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),

                // The Reassurance Text
                if (!widget.isOffline)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      "This secure download only happens once.\nPlease keep the app open.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'SFPro',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: widget.isDarkMode
                            ? Colors.white54
                            : Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                // 🌟 3. THE PROGRESS BAR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: widget.isDarkMode
                                  ? Colors.white10
                                  : Colors.black12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            height: 4,
                            width:
                                MediaQuery.of(context).size.width *
                                progressPercentage,
                            decoration: BoxDecoration(
                              color: widget.isOffline
                                  ? Colors.redAccent
                                  : (widget.isDarkMode
                                        ? Colors.white
                                        : Colors.black),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 🌟 4. THE DATA READOUT
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.isOffline ? "OFFLINE" : "RESTAURANTS",
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.isDarkMode
                                  ? Colors.white30
                                  : Colors.black38,
                            ),
                          ),
                          Text(
                            "${_fakeCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} / 36,000+",
                            style: TextStyle(
                              fontFamily: 'Courier',
                              color: widget.isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 🕒 THE OPEN HOURS PARSER
// =========================================================================
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
            if (d1 <= d2 && todayIdx >= d1 && todayIdx <= d2) {
              matchesDay = true;
            } else if (d1 > d2 && (todayIdx >= d1 || todayIdx <= d2))
              matchesDay = true; // Crosses Sunday
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
      if (currentMinutes < start &&
          end > 24 * 60 &&
          currentMinutes < (end - 24 * 60)) {
        checkTime += 24 * 60; // Push current time to "tomorrow" context
      }

      if (checkTime >= start && checkTime <= end) return true;
    }
    return false;
  }
}
