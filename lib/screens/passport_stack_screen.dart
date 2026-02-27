// ... imports ... (Same as before)
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/restaurant.dart';
// import '../widgets/immigration_stamp.dart';
import '../widgets/passport_card.dart';
import 'dart:ui'; 
import 'passport_detail_screen.dart';
import '../services/passport_service.dart';
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/passport_full_dialog.dart'; 
import 'paywall_screen.dart';
import '../logic/passport_brain.dart';

class PassportStackScreen extends StatefulWidget {
  final Restaurant? incomingRestaurant;
  final String? bookId; 
  final String? skuType;
  final bool isReadOnly; 
  // 👇 ADD THESE CALLBACKS
  final VoidCallback? onStampComplete;
  final ValueChanged<bool>? onButtonVisibilityChanged;
  final ValueChanged<String>? onRequestBookSwitch; // 👈 NEW
  final Restaurant? autoTriggerRestaurant; // 👈 NEW
  final VoidCallback? onAutoTriggerComplete; // 👈 NEW

  const PassportStackScreen({
    super.key,
    this.incomingRestaurant,
    this.bookId,
    this.skuType = 'free_tier',
    this.isReadOnly = false,
    this.onStampComplete, // 👈 NEW CALLBACK
    this.onButtonVisibilityChanged, // 👈 NEW CALLBACK
    this.onRequestBookSwitch, // 👈 NEW CALLBACK
    this.autoTriggerRestaurant,
    this.onAutoTriggerComplete,
  });

  @override
  State<PassportStackScreen> createState() => _PassportStackScreenState();
}

class _PassportStackScreenState extends State<PassportStackScreen>
    with TickerProviderStateMixin {
  
  bool _isLoading = true;
  String _passportSku = 'free_tier';
  String _userName = "TRAVELER";

  String _stampingName = ""; 
  
  String? _photoUrl;
  String? _gender;
  int? _age;
  
  List<Map<String, dynamic>> userVisas = []; 
  List<Map<String, String>> collectedStamps = [];

  int _activeIndex = 0;
  int _totalCards = 1; 

  // --- ANIMATION CONTROLLERS ---
  final ValueNotifier<double> _dragNotifier = ValueNotifier(0.0);
  late AnimationController _slideController;
  late Animation<double> _slideAnim;
  late AnimationController _stampController;
  late Animation<double> _scaleAnim;
  late AnimationController _buttonController;
  late Animation<Offset> _buttonSlideAnim;
  // late AnimationController _zoomController;
  // late Animation<double> _zoomAnim;

  final AudioPlayer _player = AudioPlayer();
  final GlobalKey _stackKey = GlobalKey();
  final List<GlobalKey> slotKeys = List.generate(4, (_) => GlobalKey());
  final GlobalKey _cardContainerKey = GlobalKey();

  final Color _stackBackgroundColor = Colors.transparent;
  final Color _detailBackgroundColor = const Color(0xFFF2F2F2);
  
  bool _showStampButton = false; 
  bool _isStampingSequence = false;
  bool _isStampActionPending = false; 

  int _targetSlotIndex = 0;
  bool _duplicateApproved = false; 
  Offset _targetStampOffset = Offset.zero;
  Size _targetSlotSize = Size.zero;
  bool _protocolRunning = false;

  bool _hasConsumedIncoming = false; // 👈 NEW: Tracks if we've already handled the payload

  @override
  void initState() {
    super.initState();
    _passportSku = widget.skuType ?? 'free_tier';
    
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _stampController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnim = Tween<double>(begin: 3.0, end: 1.0).animate(
      CurvedAnimation(parent: _stampController, curve: Curves.bounceOut),
    );
    _buttonController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _buttonSlideAnim = Tween<Offset>(begin: const Offset(1.5, 1.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.elasticOut),
    );
    // _zoomController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    // _zoomAnim = Tween<double>(begin: 1.0, end: 0.90).animate(
    //   CurvedAnimation(parent: _zoomController, curve: Curves.easeInOut),
    // );

    _player.setPlayerMode(PlayerMode.lowLatency);
    _player.setSource(AssetSource('sounds/thud.mp3'));

    _fetchBookData(); 
    // 🧨 AUTO-TRIGGER
    // If we arrived here via a "Switch & Stamp" command, execute it now.
    if (widget.autoTriggerRestaurant != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
         _executeStampSequence(manualRestaurant: widget.autoTriggerRestaurant);
         widget.onAutoTriggerComplete?.call(); // Clear the flag
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _stampController.dispose();
    _buttonController.dispose();
    // _zoomController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _fetchBookData({bool forceRefresh = false}) async {
    // 🛠 FIX: Check if user is Guest
    final isGuest = Supabase.instance.client.auth.currentUser == null;
    
    // 🚀 FORCE REFRESH FOR GUESTS
    // We intentionally ignore the RAM cache for guests and read straight from disk.
    // This solves the "Stale State" bug where stamps don't appear after navigation.
    if (isGuest) {
      forceRefresh = true;
    }

    // 1. Try Cache (Only for Logged In Users now)
    if (!forceRefresh) {
      final cachedProfile = PassportService.getCachedProfile();
      final cachedBook = (widget.bookId != null) 
          ? PassportService.getCachedBook(widget.bookId!) 
          : null; 

      if (cachedBook != null && cachedBook.isNotEmpty) {
        _applyBookData(cachedBook, cachedProfile);
        return; 
      }
    }

    // 2. Fetch Fresh Data (Disk or Cloud)
    try {
       // 🛠 FIX: Pass 'forceRefresh' down to the service
       // This forces the Service to re-read SharedPreferences for guests
       await PassportService.fetchUserLibrary(forceRefresh: forceRefresh);
       
       String targetId = widget.bookId ?? 'guest_book_local';
       final freshBook = PassportService.getCachedBook(targetId);
       
       if (freshBook != null && freshBook.isNotEmpty) {
         _applyBookData(freshBook, PassportService.getCachedProfile());
       } else {
         if (mounted) setState(() => _isLoading = false);
       }
    } catch (e) {
      debugPrint("Book Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyBookData(Map<String, dynamic> bookData, Map<String, dynamic>? profileData) {
    if (!mounted) return;
    
    // 🛡️ CRITICAL FIX: Wrap in try/catch so the spinner ALWAYS stops
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final emailName = user?.email?.split('@')[0].toUpperCase() ?? "TRAVELER";

      final visasList = List<Map<String, dynamic>>.from(bookData['visas'] ?? []);

      // 🛡️ GHOST BUSTER: SANITIZE SINGLE PAGE BOOKS
      // If DB accidentally has > 1 visa for a Single Page book, hide the extras locally.
      if (bookData['sku_type'] == 'single_page' && visasList.length > 1) {
         // Keep only the first one (The Legitimate Marriage)
         visasList.retainWhere((v) => v == visasList.first);
      }
      
      int activePages = 1 + visasList.length;
      // 🛡️ PHYSICAL CAPACITY CAP
      // Instead of letting the book grow (1 + visas), we lock it to the DB's max_pages.
      int dbMaxPages = bookData['max_pages'] ?? 1; 
      
      final int newTotal = dbMaxPages;
      
      // 🛑 BUG 1 FIX: Don't snap back to the cover if we are already reading!
      // If _isLoading is false, it's a silent background refresh, so we 
      // keep the user's current page (_activeIndex). Otherwise, use the DB's page.
      int newActiveIndex = _isLoading ? (bookData['last_page_index'] ?? 0) : _activeIndex;
      
      final rawStamps = bookData['stamps'] ?? [];
      
      // 🛡️ HYBRID KEY SUPPORT
      // We check for 'restaurant_name' (Cloud/New Guest) AND 'name' (Old Guest)
      final List<Map<String, String>> cleanStamps = List<Map<String, String>>.from(
        rawStamps.map((item) {
          final name = item['restaurant_name'] ?? item['name'] ?? "Unknown";
          final cuisine = item['country_cuisine'] ?? item['cuisine'] ?? "Global";
          
          // Date parsing protection
          String dateStr;
          try {
             // Try parsing 'stamped_at' (ISO) or 'date' (Formatted)
             final rawDate = item['stamped_at'] ?? item['date'];
             if (rawDate != null && rawDate.contains('-')) {
               dateStr = DateFormat('MMM d, yyyy').format(DateTime.parse(rawDate));
             } else {
               dateStr = rawDate ?? "Unknown Date";
             }
          } catch (e) {
             dateStr = "Recent";
          }

          // Inside _applyBookData -> cleanStamps map:
          return {
            'name': name.toString(),
            'date': dateStr,
            'cuisine': cuisine.toString(),
            'lat': item['restaurants']?['lat']?.toString() ?? '0.0',
            'lng': item['restaurants']?['lng']?.toString() ?? '0.0',
            
            // 👇 ADD THIS ONE LINE RIGHT HERE:
            'mta_station_id': item['mta_station_id']?.toString() ?? '', 
          };
        })
      );

      setState(() {
        _passportSku = bookData['sku_type'] ?? 'free_tier';
        _totalCards = newTotal;
        _activeIndex = newActiveIndex;
        _userName = profileData?['display_name'] ?? emailName;
        _photoUrl = profileData?['photo_url'];
        _gender = profileData?['gender'];
        _age = profileData?['age'];
        userVisas = visasList;
        collectedStamps = cleanStamps;
        
        // 🌉 THE BRIDGE: Keep the loading screen up if we have a stamp to process!
        if (widget.incomingRestaurant == null || _hasConsumedIncoming) {
          _isLoading = false; 
        }
      });
      if (widget.incomingRestaurant != null && !_hasConsumedIncoming) {
         _hasConsumedIncoming = true; // 👈 Mark it as eaten!
         WidgetsBinding.instance.addPostFrameCallback((_) {
            _initiateImmigrationProtocol();
         });
      }

    } catch (e) {
      debugPrint("⚠️ Critical Error in _applyBookData: $e");
      // 🛑 EMERGENCY STOP for the spinner
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🕵️ PRE-CHECK: Runs AFTER page flip, BEFORE button shows
  Future<void> _handleIncomingStampTrigger() async {
    final restaurant = widget.incomingRestaurant;
    if (restaurant == null) return;

    // 1. Check for Duplicates
    final bool isDuplicate = collectedStamps.any((s) => 
      (s['name'] ?? s['restaurant_name']) == restaurant.name
    );

    if (isDuplicate) {
      // 🛑 STOP & ASK IMMEDIATELY (Playful Dialog)
      final bool? shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: const Color(0xFFFFFDF7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history, size: 40, color: Color(0xFFD32F2F)),
                ),
                const SizedBox(height: 20),
                const Text(
                  "ALREADY STAMPED!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Courier', fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  "You've already got a stamp for\n'${restaurant.name}'.\n\nWant to double dip?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.4, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: const EdgeInsets.symmetric(vertical: 16), shape: const StadiumBorder()),
                        child: const Text("NAH, CANCEL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: const StadiumBorder()),
                        child: const Text("YEP, STAMP IT!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      );

      // 🚦 DECISION TIME
      if (shouldProceed == true) {
        _duplicateApproved = true; // ✅ Remember they said YES
        _showButton(); // Now show the button
      } 
      // If false, we simply DO NOT show the button. Flow ends.
    } else {
      // Not a duplicate? Show button immediately.
      _showButton();
    }
  }

  void _showButton() {
    if (mounted) {
      setState(() {
        _showStampButton = true;
      });
      _buttonController.forward();
      
      // 🗣️ TELL PARENT: "Button is here. Hide the pill!"
      widget.onButtonVisibilityChanged?.call(true); 
    }
  }


  Future<void> _initiateImmigrationProtocol() async {
    if (_protocolRunning || _showStampButton || _isStampingSequence) return;
    
    // 🌉 Keep the loading bridge active!
    setState(() { _protocolRunning = true; _isLoading = true; });

    final userId = Supabase.instance.client.auth.currentUser?.id;

    // 1. ANALYZE CUISINE
    String rawTag = widget.incomingRestaurant!.cuisine;
    String primaryTag = rawTag.split(';').first.trim();
    String targetCuisine = 'Global';

    try {
      final mappingResponse = await Supabase.instance.client.from('cuisine_mappings').select('target_cuisine').ilike('raw_tag', primaryTag).maybeSingle();
      if (mappingResponse != null) targetCuisine = mappingResponse['target_cuisine'];
      else {
        final visaCheck = await Supabase.instance.client.from('visa_types').select('cuisine').ilike('cuisine', primaryTag).maybeSingle();
        if (visaCheck != null) targetCuisine = visaCheck['cuisine'];
      }
    } catch (e) { debugPrint("Cuisine analysis error: $e"); }

    String targetColor = '#1A237E'; 
    try {
       final colorResponse = await Supabase.instance.client.from('visa_types').select('color_hex').eq('cuisine', targetCuisine).maybeSingle();
       if (colorResponse != null) targetColor = colorResponse['color_hex'];
    } catch (e) {}

    // 2. CONSULT BRAIN
    final library = await PassportService.fetchUserLibrary(forceRefresh: true);
    PassportBrain.instance.syncLibrary(library);

    if (widget.incomingRestaurant != null) {
      final bool isDuplicate = PassportBrain.instance.hasDuplicateStamp(widget.incomingRestaurant!.name);

      if (isDuplicate) {
        final bool? shouldProceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: const Color(0xFFFFFDF7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Color(0xFFFFF0F0), shape: BoxShape.circle),
                    child: const Icon(Icons.history, size: 40, color: Color(0xFFD32F2F)),
                  ),
                  const SizedBox(height: 20),
                  const Text("ALREADY STAMPED!", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Courier', fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5)),
                  const SizedBox(height: 12),
                  Text("You've already got a stamp for\n'${widget.incomingRestaurant!.name}'.\n\nWant to double dip?", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.4, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: const EdgeInsets.symmetric(vertical: 16), shape: const StadiumBorder()), child: const Text("NAH, CANCEL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: const StadiumBorder()), child: const Text("YEP, STAMP IT!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                    ],
                  )
                ],
              ),
            ),
          ),
        );

        if (shouldProceed != true) {
          // 🛑 User cancelled. Drop the bridge, reveal the book, and abort.
          setState(() { _protocolRunning = false; _isLoading = false; });
          return; 
        }
      }
    }

    final decision = await PassportBrain.instance.processStampRequest(widget.incomingRestaurant!);
    
    // 🛑 SCENARIO A: UPGRADE REQUIRED
    if (decision.action == BrainAction.upgrade) {
      if (_passportSku == 'free_tier') {
         // 🛑 Drop bridge to show the book behind the free-tier upgrade dialog
         setState(() { _protocolRunning = false; _isLoading = false; });
         showDialog(context: context, builder: (_) => const PassportFullDialog());
         return;
      }
      
      final reason = decision.reason ?? "No available space.";
      bool wantsUpgrade = await _showDynamicUpgradeDialog(targetCuisine, reason);
      
      if (wantsUpgrade) {
         if (mounted) {
           await Navigator.push(context, MaterialPageRoute(builder: (_) => PaywallScreen(
             incomingRestaurant: widget.incomingRestaurant 
           )));
           await _fetchBookData(forceRefresh: true);
           if (mounted) _initiateImmigrationProtocol(); 
         }
      } else {
         // 🛑 User cancelled upgrade. Drop the bridge.
         setState(() { _protocolRunning = false; _isLoading = false; });
      }
      return;
    }

    // 🔀 SCENARIO B: SWITCH BOOK
    if (decision.action == BrainAction.switchAndStamp) {
      setState(() { _protocolRunning = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Switching passport..."), backgroundColor: Color(0xFF1A237E), duration: Duration(milliseconds: 1500))
      );
      widget.onRequestBookSwitch?.call(decision.targetBookId ?? "");
      return; 
    }

    // ✅ SCENARIO C: STAY AND STAMP
    if (decision.action == BrainAction.stayAndStamp) {

      // 1. DO WE NEED A NEW VISA ROW?
      if (decision.requiresNewVisa && userId != null) {
        bool hasCuisine = userVisas.any((v) => v['cuisine'].toString().toLowerCase() == targetCuisine.toLowerCase());
        bool createNew = false;
        
        if (!hasCuisine) {
          createNew = await _showVisaApplicationDialog(targetCuisine, widget.incomingRestaurant!.name);
        } else {
          createNew = await _showExtensionDialog(targetCuisine);
        }

        if (!createNew) {
          // 🛑 User declined the visa. Drop the bridge.
          setState(() { _protocolRunning = false; _isLoading = false; });
          return;
        }

        // 🚀 Optimistic Update
        final newVisa = {
          'id': 'temp_${DateTime.now().millisecondsSinceEpoch}', 
          'user_id': userId,
          'book_id': widget.bookId,
          'cuisine': targetCuisine,
          'created_at': DateTime.now().toIso8601String(),
          'visa_types': {'color_hex': targetColor} 
        };

        setState(() {
          userVisas.add(newVisa);
          if (_passportSku != 'single_page') _totalCards++; 
        });
        
        PassportService.addVisaToCache(widget.bookId!, newVisa);
        Supabase.instance.client.from('user_visas').insert({
          'user_id': userId, 'book_id': widget.bookId, 'cuisine': targetCuisine, 'created_at': DateTime.now().toIso8601String(),
        }).catchError((e) {});
      }

      // 2. NAVIGATION (Find Target Page)
      final currentBook = library.firstWhere((b) => b['id'] == widget.bookId, orElse: () => {});
      int targetPageIndex = PassportBrain.instance.calculateTargetPageIndex(currentBook, targetCuisine);
      if (_passportSku == 'free_tier') targetPageIndex = 0;

      // 🎬 THE BIG REVEAL: All checks passed! Drop the bridge and show the physical book!
      setState(() { _isLoading = false; });
      await Future.delayed(const Duration(milliseconds: 100)); // Tiny pause to let Flutter paint the book

      while (_activeIndex < targetPageIndex) {
         await _programmaticPageFlip();
         if (_activeIndex < targetPageIndex) await Future.delayed(const Duration(milliseconds: 50)); 
      }

      // 3. EXECUTE
      setState(() { _protocolRunning = false; });
      _showButton();
      return;
    }

    setState(() { _protocolRunning = false; _isLoading = false; });
  }

  // --- 🎬 ACT 3: THE IMPACT (Zoom -> Target -> Thud) ---

  Future<void> _executeStampSequence({Restaurant? manualRestaurant}) async {
    if (_isStampActionPending) return; 
    
    final Restaurant? restaurantToStamp = manualRestaurant ?? widget.incomingRestaurant;
    if (restaurantToStamp == null) return;

    // ✂️ DELETE ANY DUPLICATE CHECKS / DIALOGS HERE ✂️

    setState(() {
      _isStampActionPending = true;
      _stampingName = restaurantToStamp.name;
    });

    // 🛠 FIX: Determine the correct cuisine logic
    // 1. Default to Global (Safe fallback)
    String targetCuisine = 'Global'; 

    // 2. CHECK: Is this a Single Visa? (It sits on Page 0 but has a specific cuisine)
    if (_passportSku == 'single_page' && userVisas.isNotEmpty) {
       targetCuisine = userVisas[0]['cuisine'];
    } 
    // 3. CHECK: Is this a Standard/Diplomat on a Visa Page (Index > 0)?
    else if (userVisas.isNotEmpty && _activeIndex > 0) {
       targetCuisine = userVisas[_activeIndex - 1]['cuisine'];
    }

    // Determine slot index for animation
    int currentStampCount = collectedStamps.where((s) => s['cuisine'] == targetCuisine).length;
    
    // Wildcards just count total stamps since they don't filter by cuisine
    if (_passportSku == 'free_tier') currentStampCount = collectedStamps.length;

    _targetSlotIndex = currentStampCount % 4; 

    _buttonController.reverse();
    setState(() { 
      _showStampButton = false; 
      _isStampingSequence = true; 
    });

    // 🗣️ TELL PARENT: "Button is gone. You can show the pill again."
    widget.onButtonVisibilityChanged?.call(false);

    // 🔊 AUDIO SYNC
    await Future.delayed(const Duration(milliseconds: 540));
        
    HapticFeedback.heavyImpact();
    try {
      await _player.stop();
      await _player.setSource(AssetSource('sounds/thud.mp3'));
      await _player.resume();
    } catch (e) { /* ignore audio errors */ }

    // 💾 SAVE DATA
    final newStamp = {
      'id': restaurantToStamp.id.toString(), 
      'name': restaurantToStamp.name,
      'date': DateFormat('MMM d, yyyy').format(DateTime.now()),
      'cuisine': targetCuisine, 
      'mta_station_id': '', // 👈 NEW: Add an empty string so the UI doesn't crash before the DB syncs
    };

    // This handles the decision: Guest -> Disk, User -> Cloud
    await PassportService.addStamp(
      bookId: widget.bookId, 
      stampData: newStamp
    );

    // 🤫 STEP 1 FIX: Silently fetch the updated book from the DB right now! 
    // PostGIS calculates the nearest mta_station_id instantly on the backend.
    // We do NOT "await" this call, so the stamping animation keeps playing smoothly.
    _fetchBookData(forceRefresh: true);

    // Wait for the rest of the animation
    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      setState(() { 
        // Fallback: Add the blank stamp optimistically ONLY if the network 
        // is slow and the background fetch hasn't finished updating the list yet.
        if (!collectedStamps.any((s) => s['name'] == newStamp['name'])) {
          collectedStamps.add(newStamp); 
        }
        _isStampingSequence = false;   
        _isStampActionPending = false; 
      });
      // 🆕 NEW: NOTIFY PARENT TO RELOAD
      widget.onStampComplete?.call();
    }
  }


  // --- PHYSICS & UI HELPERS ---

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _dragNotifier.value += details.delta.dy;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    final double currentDrag = _dragNotifier.value;

    // 👆 SWIPE UP (Dismiss card)
    if (currentDrag < -100 || velocity < -400) {
      if (_activeIndex < _totalCards - 1) {
        _animateCardAway();
      } else {
        _snapBack();
      }
    } 
    // 👇 SWIPE DOWN (Retrieve previous card)
    else if (currentDrag > 50 || velocity > 200) { // Highly sensitive for simulator
      if (_activeIndex > 0) {
        _animateCardRetrieve();
      } else {
        _snapBack();
      }
    } 
    // 🛑 NOT ENOUGH MOVEMENT (Snap back to center)
    else {
      _snapBack();
    }
  }
  void _animateCardAway() {
    final double screenHeight = MediaQuery.of(context).size.height;
    _slideAnim = Tween<double>(begin: _dragNotifier.value, end: -screenHeight).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeIn),
    );
    _slideController.forward(from: 0).then((_) {
      setState(() {
        _activeIndex++;
        _dragNotifier.value = 0; 
      });
      if (widget.bookId != null) {
        PassportService.updateBookPage(widget.bookId!, _activeIndex);
      }
      HapticFeedback.lightImpact();
    });
  }

  void _animateCardRetrieve() {
    final double screenHeight = MediaQuery.of(context).size.height;
    setState(() {
      _activeIndex--; 
      _dragNotifier.value = -screenHeight; 
    });
    if (widget.bookId != null) {
       PassportService.updateBookPage(widget.bookId!, _activeIndex);
    }

    _slideAnim = Tween<double>(begin: -screenHeight, end: 0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );
    _slideController.forward(from: 0).then((_) {
      _dragNotifier.value = 0.0;
      HapticFeedback.mediumImpact();
    });
  }

  Future<void> _programmaticPageFlip() async {
    final double screenHeight = MediaQuery.of(context).size.height;
    _slideAnim = Tween<double>(begin: 0, end: -screenHeight).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeIn), 
    );
    HapticFeedback.mediumImpact();
    _slideController.duration = const Duration(milliseconds: 200); 
    await _slideController.forward(from: 0);
    _slideController.duration = const Duration(milliseconds: 400); 

    if (mounted) {
      setState(() {
        _activeIndex++;
        _dragNotifier.value = 0; 
      });
      if (widget.bookId != null) {
        PassportService.updateBookPage(widget.bookId!, _activeIndex);
      }
    }
    _slideController.reset();
  }

  void _snapBack() {
    _slideAnim = Tween<double>(begin: _dragNotifier.value, end: 0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );
    _slideController.forward(from: 0).then((_) {
       _dragNotifier.value = 0;
    });
  }

  // DIALOGS
  Future<bool> _showVisaApplicationDialog(String cuisine, String restaurantName) async {
    return await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Visa Application",
      barrierColor: Colors.black.withOpacity(0.6), 
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), 
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7), 
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 15))
                  ],
                  border: Border.all(color: Colors.white, width: 2), 
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF1A237E).withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.policy, size: 40, color: Color(0xFF1A237E)),
                    ),
                    const SizedBox(height: 20),
                    const Text("VISA REQUIRED", style: TextStyle(fontFamily: 'Courier', fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3.0, color: Color(0xFF1A237E))),
                    const SizedBox(height: 10),
                    Container(height: 1, width: 40, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    Text("Entry to '$restaurantName' requires an official $cuisine Visa.\n\nDo you wish to issue this travel document?", textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: Text("DECLINE", style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 1)))),
                        const SizedBox(width: 10),
                        Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text("ISSUE VISA", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)))),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ) ?? false;
  }

  // 🛠 NEW: Dynamic dialog that reads the Brain's reason
  Future<bool> _showDynamicUpgradeDialog(String targetCuisine, String reason) async {
    
    // Determine the text based on the Brain's context
    String title = "NO SPACE AVAILABLE";
    String message = "You have no available pages for a $targetCuisine visa in your current library.\n\nExpand your collection to continue stamping!";
    IconData icon = Icons.library_books;
    Color iconColor = Colors.blue[900]!;

    if (reason.toLowerCase().contains("single visa") || reason.toLowerCase().contains("monogamy")) {
       title = "SINGLE VISA LIMIT";
       message = "This passport can only hold one country's visa at a time.\n\nYou are trying to collect a $targetCuisine stamp, but this Single Visa is already assigned to another country.";
       icon = Icons.lock_clock;
       iconColor = Colors.orange[900]!;
    }

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFFFDF7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: iconColor),
              ),
              const SizedBox(height: 20),
              
              Text(
                title, 
                style: const TextStyle(
                  fontFamily: 'Courier', 
                  fontWeight: FontWeight.w900, 
                  fontSize: 20, 
                  letterSpacing: -0.5,
                  color: Colors.black87
                )
              ),
              const SizedBox(height: 12),
              
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E), 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, true), // TRUE = Upgrade
                  child: const Text("UPGRADE PASSPORT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ),
              ),
              const SizedBox(height: 12),
              
              TextButton(
                onPressed: () => Navigator.pop(context, false), // FALSE = Cancel
                child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    ) ?? false;
  }

  Future<bool> _showExtensionDialog(String cuisine) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFFFDF7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFE8EAF6), shape: BoxShape.circle), child: const Icon(Icons.add_to_photos_rounded, size: 40, color: Color(0xFF1A237E))),
              const SizedBox(height: 20),
              const Text("PAGE FULL!", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Courier', fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5)),
              const SizedBox(height: 12),
              Text("Your $cuisine Visa is completely filled.\n\nAdd a fresh page to keep collecting?", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.4, fontWeight: FontWeight.w500)),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: const EdgeInsets.symmetric(vertical: 16), shape: const StadiumBorder()), child: const Text("NO THANKS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: const StadiumBorder()), child: const Text("ADD PAGE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                ],
              )
            ],
          ),
        ),
      ),
    ) ?? false;
  }

  void _onCardTap() {
    // 🛑 1. BOUNCER: PREVENT COVER TAP
    if (_activeIndex == 0 && (_passportSku == 'diplomat_book' || _passportSku == 'standard_book')) {
      return; 
    }

    if (_showStampButton || _isStampingSequence) return; 

    // 🛠 FIX 1: Enforce Capacity
    int filledPagesCount = 1 + userVisas.length; 
    if (_passportSku == 'single_page') filledPagesCount = 1; // Single Visa = 1 Page Max

    bool isAssigned = _activeIndex < filledPagesCount;

    String title = "VACANT PAGE";
    Color? color;
    String? dateIssued;
    List<Map<String, String>> stamps = [];

    if (isAssigned) {
      if (_activeIndex == 0) { 
        // 🛠 FIX 2: TRANSFORM PAGE 0 FOR SINGLE VISA
        if (_passportSku == 'single_page' && userVisas.isNotEmpty) {
           final visa = userVisas[0];
           
           // A. Use Specific Cuisine Title
           title = visa['cuisine'].toString().toUpperCase();
           
           // B. Use Specific Color
           if (visa['visa_types'] != null && visa['visa_types']['color_hex'] != null) {
             color = _parseColor(visa['visa_types']['color_hex']);
           }
           
           // C. Use Date
           if (visa['created_at'] != null) {
              dateIssued = DateFormat('MMM d, yyyy').format(DateTime.parse(visa['created_at']));
           }

           // D. Show ALL stamps (It's the only page)
           stamps = collectedStamps; 
        } else {
           // --- STANDARD BEHAVIOR ---
           title = _passportSku == 'free_tier' ? "TEMP VISA" : "GLOBAL VISA";
           stamps = collectedStamps.where((s) => s['cuisine'] == 'Global').toList();
           if (_passportSku == 'free_tier') stamps = collectedStamps;
        }
      } else {
        // --- PAGES 1+ BEHAVIOR ---
        if (userVisas.length > _activeIndex - 1) {
          final visa = userVisas[_activeIndex - 1];
          title = visa['cuisine'].toString().toUpperCase();
          
          if (visa['visa_types'] != null && visa['visa_types']['color_hex'] != null) {
            color = _parseColor(visa['visa_types']['color_hex']);
          }
          if (visa['created_at'] != null) {
             dateIssued = DateFormat('MMM d, yyyy').format(DateTime.parse(visa['created_at']));
          }

          final allCuisineStamps = collectedStamps.where((s) => s['cuisine'] == visa['cuisine']).toList();
          
          int cuisinePageOrder = 0;
          for (int i = 0; i < _activeIndex - 1; i++) {
            if (userVisas[i]['cuisine'] == visa['cuisine']) {
              cuisinePageOrder++;
            }
          }
          final int skipCount = cuisinePageOrder * 4;
          stamps = allCuisineStamps.skip(skipCount).take(4).toList();
        }
      }
    }

    final String heroTag = 'passport_card_${widget.bookId}_${_activeIndex + 1}';

    final Widget cardWidget = PassportCard(
      pageIndex: _activeIndex,
      passportSku: _passportSku,
      userName: _userName,
      pageStamps: stamps,
      slotKeys: null, 
      cardKey: null,
      useKeys: false, 
      cutoutColor: _detailBackgroundColor, 
      isVacant: !isAssigned,
      visaTitle: title,
      visaDate: dateIssued,
      visaColor: color,
      onNameTap: null,
      photoUrl: _photoUrl,
      gender: _gender,
      age: _age,
    );

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true, 
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: PassportDetailScreen(
              heroTag: heroTag,
              cardWidget: cardWidget,
              backgroundColor: _detailBackgroundColor, 
              // 👇 NEW: Hand the data to the detail screen
              cuisine: title,
              stamps: stamps,
            ),
          );
        },
      ),
    );
  }

  // UI HELPERS (Keep your existing helpers _buildBackgroundCard, _buildActiveCard, _buildCardContent, _parseColor, _showStampSearchSheet, build)
  
  Widget _buildBackgroundCard(int index) {
    int pos = index - _activeIndex;
    double scale = 1.0 - (pos * 0.05);
    double offsetY = pos * 25.0;
    double opacity = 1.0 - (pos * 0.3);
    opacity = opacity.clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(0, -offsetY),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: _buildCardContent(index, useKeys: false), 
        ),
      ),
    );
  }

  // Widget _buildActiveCard(int index) {
  //   return AnimatedBuilder(
  //     animation: _zoomController,
  //     builder: (context, child) {
  //       return Transform.scale(
  //         scale: _isStampingSequence ? _zoomAnim.value : 1.0, 
  //         child: child,
  //       );
  //     },
  //     child: _buildCardContent(index, useKeys: !_isStampingSequence), 
  //   );
  // }

  Widget _buildActiveCard(int index) {
    return _buildCardContent(
      index, 
      useKeys: false, 
      // 👇 NOW THIS WILL WORK
      isFlyingStamp: _isStampingSequence, 
    );
  }
  
  Widget _buildCardContent(int index, {required bool useKeys, bool isFlyingStamp = false}) {
    // =========================================================================
    // 🎚️ FAILSAFE SWITCH: CHOOSE YOUR LOGIC
    // =========================================================================

    // -------------------------------------------------------------------------
    // 🔴 OPTION A: OLD DISTRIBUTED LOGIC (Current)
    // -------------------------------------------------------------------------

    // int filledPagesCount = 1 + userVisas.length; 
    // if (_passportSku == 'single_page') filledPagesCount = 1;

    // bool isAssigned = index < filledPagesCount;

    // String title = "VACANT PAGE";
    // Color? color;
    // String? dateIssued;
    // List<Map<String, String>> stamps = [];

    // if (isAssigned) {
    //   if (index == 0) {
    //     if (_passportSku == 'single_page' && userVisas.isNotEmpty) {
    //        final visa = userVisas[0];
    //        title = visa['cuisine'].toString().toUpperCase();
    //        if (visa['visa_types'] != null && visa['visa_types']['color_hex'] != null) {
    //          color = _parseColor(visa['visa_types']['color_hex']);
    //        }
    //        if (visa['created_at'] != null) {
    //           dateIssued = DateFormat('MMM d, yyyy').format(DateTime.parse(visa['created_at']));
    //        }
    //        stamps = collectedStamps; 
    //     } else {
    //        title = _passportSku == 'free_tier' ? "TEMP VISA" : "GLOBAL VISA";
    //        stamps = collectedStamps.where((s) => s['cuisine'] == 'Global').toList();
    //        if (_passportSku == 'free_tier') stamps = collectedStamps;
    //     }
    //   } else {
    //     if (userVisas.length > index - 1) {
    //       final visa = userVisas[index - 1];
    //       title = visa['cuisine'].toString().toUpperCase();
    //       if (visa['visa_types'] != null && visa['visa_types']['color_hex'] != null) {
    //         color = _parseColor(visa['visa_types']['color_hex']);
    //       }
    //       if (visa['created_at'] != null) {
    //          dateIssued = DateFormat('MMM d, yyyy').format(DateTime.parse(visa['created_at']));
    //       }
    //       final allCuisineStamps = collectedStamps.where((s) => s['cuisine'] == visa['cuisine']).toList();
    //       int cuisinePageOrder = 0;
    //       for (int i = 0; i < index - 1; i++) {
    //         if (userVisas[i]['cuisine'] == visa['cuisine']) {
    //           cuisinePageOrder++;
    //         }
    //       }
    //       final int skipCount = cuisinePageOrder * 4;
    //       stamps = allCuisineStamps.skip(skipCount).take(4).toList();
    //     }
    //   }
    // }
    
    // -------------------------------------------------------------------------
    // 🟢 OPTION B: NEW BRAIN LOGIC 
    // -------------------------------------------------------------------------

    // 🛡️ THE FIX: We build the book object from our stable local state.
    // This prevents the UI from flickering to the 'free_tier' default if the 
    // Service cache is temporarily wiped during a database sync.
    final Map<String, dynamic> fullBook = {
      'sku_type': _passportSku,
      'visas': userVisas,
      'stamps': collectedStamps,
    };
    final ctx = PassportBrain.instance.resolvePageContext(fullBook, index);

    bool isAssigned = !ctx.isVacant;
    String title = ctx.title;
    List<Map<String, String>> stamps = ctx.stamps;
    
    // For colors/dates, we still need a quick lookup since Context is purely data
    Color? color;
    String? dateIssued;
    
    // Quick helper to match the context back to our local styling data
    // (We can move this to Brain later, but keeping it simple for now)
    if (!ctx.isGlobalPage && !ctx.isVacant) {
       final matchingVisa = userVisas.firstWhere(
         (v) => v['cuisine'].toString().toLowerCase() == ctx.targetCuisine.toLowerCase(),
         orElse: () => {}
       );
       if (matchingVisa.isNotEmpty) {
          if (matchingVisa['visa_types'] != null && matchingVisa['visa_types']['color_hex'] != null) {
             color = _parseColor(matchingVisa['visa_types']['color_hex']);
          }
          if (matchingVisa['created_at'] != null) {
             dateIssued = DateFormat('MMM d, yyyy').format(DateTime.parse(matchingVisa['created_at']));
          }
       }
    }

    // */
    // =========================================================================

    return PassportCard(
      // 🛠 FIX: Still need the Key fix from before!
      key: ValueKey('card_${index}_$title'), 
      
      pageIndex: index,
      passportSku: _passportSku,
      userName: _userName,
      pageStamps: stamps,
      slotKeys: (isAssigned && useKeys) ? slotKeys : null, 
      cardKey: (useKeys && isAssigned) ? _cardContainerKey : null,
      useKeys: useKeys,
      cutoutColor: useKeys ? const Color(0xFF111111) : const Color(0xFFF2F2F2), 
      isVacant: !isAssigned,
      visaTitle: title,
      visaDate: dateIssued,
      visaColor: color,
      onAddSlotTap: (_passportSku == 'free_tier' && isAssigned) 
          ? _showStampSearchSheet 
          : null,
      onNameTap: null,
      photoUrl: _photoUrl,
      gender: _gender,
      age: _age,
      isFlying: isFlyingStamp,
      flyingSlotIndex: _targetSlotIndex,
      flyingStampName: _stampingName,
      flyingStampDate: DateFormat('MMM d, yyyy').format(DateTime.now()),
    );
  }

  Color _parseColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  // 1. 🚀 MANUAL STAMPING (The "+" Button)
  Future<void> _showStampSearchSheet() async {
    // 🛑 ARCHIVE INTERCEPTOR
    // Rule: If it's Read-Only AND NOT the Wildcard, we block it.
    // Exception: If it IS the Wildcard, we let them pass (The Mercenary Protocol).
    if (widget.isReadOnly && _passportSku != 'free_tier') {
      final bool? shouldActivate = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: const Color(0xFFFFFDF7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                  child: const Icon(Icons.inventory_2_outlined, size: 32, color: Colors.black87),
                ),
                const SizedBox(height: 20),
                const Text("ARCHIVED VISA", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.0)),
                const SizedBox(height: 12),
                const Text("This Passport is currently in storage.\n\nTo add a stamp, you must first finish your Primary Passport or activate this one manually.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, height: 1.5, fontSize: 14)),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("ACTIVATE", style: TextStyle(fontWeight: FontWeight.bold)))),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (shouldActivate != true) return;

      if (widget.bookId != null) {
        await PassportService.activateBook(widget.bookId!);
      }
    }

    // 🚀 PROCEED (Wildcards skip the check above and land here directly)
    final Restaurant? selected = await showModalBottomSheet<Restaurant>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _StampSearchModal(),
    );
    
    if (selected != null) {
      _executeStampSequence(manualRestaurant: selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 16));
    }
    // ... rest of the stack

    return SizedBox.expand(
      key: _stackKey, 
      child: GestureDetector(
        onVerticalDragEnd: _onVerticalDragEnd,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          alignment: const Alignment(0, 0.2),
          children: [
            for (int i = _totalCards - 1; i > _activeIndex; i--)
              if (i <= _activeIndex + 3) _buildBackgroundCard(i),

            if (_activeIndex < _totalCards)
              GestureDetector(
                onVerticalDragUpdate: _showStampButton ? null : _onVerticalDragUpdate,
                onVerticalDragEnd: _showStampButton ? null : _onVerticalDragEnd,
                onTap: _onCardTap,
                child: ValueListenableBuilder<double>(
                  valueListenable: _dragNotifier,
                  child: RepaintBoundary(
                    child: Hero(
                      tag: 'passport_card_${widget.bookId}_${_activeIndex + 1}', 
                      child: _buildActiveCard(_activeIndex),
                    ),
                  ),
                  builder: (context, dragValue, cachedCard) {
                     return AnimatedBuilder(
                      animation: _slideController,
                      child: cachedCard,
                      builder: (context, child) {
                        double currentY = _slideController.isAnimating ? _slideAnim.value : dragValue;
                        double rotation = currentY * -0.0002;
                        return Transform(
                          transform: Matrix4.identity()..translate(0.0, currentY)..rotateZ(rotation),
                          alignment: Alignment.center,
                          child: child,
                        );
                      },
                    );
                  },
                ),
              ),

            if (_activeIndex > 0 && !_showStampButton && !_isStampingSequence)
              Positioned(
                top: 110, 
                right: 20,
                child: FloatingActionButton.small(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  onPressed: _animateCardRetrieve,
                  child: const Icon(Icons.refresh),
                ),
              ),

            if (_showStampButton)
              Positioned(
                bottom: 50,
                right: 30,
                child: SlideTransition(
                  position: _buttonSlideAnim,
                  child: Transform.rotate(
                    angle: -0.1, 
                    child: FloatingActionButton.extended(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      elevation: 10,
                      icon: const Icon(Icons.verified, size: 28),
                      label: const Text("STAMP PASSPORT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      onPressed: () => _executeStampSequence(),
                    ),
                  ),
                ),
              ),

            // if (_isStampingSequence)
            //   Positioned(
            //     left: _targetStampOffset.dx,
            //     top: _targetStampOffset.dy,
            //     child: SizedBox(
            //       width: _targetSlotSize.width, 
            //       height: _targetSlotSize.height, 
            //       child: Center( 
            //         child: ScaleTransition(
            //           scale: _scaleAnim,
            //           child: Transform.rotate(
            //             // 🛠 FIX: Match the static stamp's rotation logic exactly
            //             angle: ((collectedStamps.length % 4) % 2 == 0) ? -0.1 : 0.1,
            //             child: ImmigrationStamp(
            //               restaurant: _stampingName, 
            //               date: DateFormat('MMM d, yyyy').format(DateTime.now()),
            //             ),
            //           ),
            //         ),
            //       ),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }
}

// ... _StampSearchModal class from previous message ...
class _StampSearchModal extends StatefulWidget {
  const _StampSearchModal();

  @override
  State<_StampSearchModal> createState() => _StampSearchModalState();
}

class _StampSearchModalState extends State<_StampSearchModal> {
  final TextEditingController _controller = TextEditingController();
  List<Restaurant> _results = [];
  bool _loading = false;

  void _search(String query) async {
    if (query.length < 3) return;
    setState(() => _loading = true);
    
    final response = await Supabase.instance.client
        .from('restaurants')
        .select()
        .ilike('name', '%$query%')
        .limit(5);

    if (mounted) {
      setState(() {
        _results = (response as List).map((e) => Restaurant.fromMap(e)).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFFFDFBF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text("LOG A VISIT", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Search restaurant...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 20),
          if (_loading) const CupertinoActivityIndicator(radius: 14),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_,__) => const Divider(),
              itemBuilder: (context, index) {
                final r = _results[index];
                return ListTile(
                  title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(r.cuisine),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => Navigator.pop(context, r),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}