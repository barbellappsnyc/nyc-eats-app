import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nyc_eats/services/telemetry_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../services/passport_service.dart';
import 'package:intl/intl.dart';

// 🧠 THE PASSPORT BRAIN
// The central intelligence that decides WHERE a stamp goes.
class PassportBrain {
  // Singleton Pattern
  static final PassportBrain _instance = PassportBrain._internal();
  static PassportBrain get instance => _instance;
  PassportBrain._internal();

  // 🔒 STATE
  List<Map<String, dynamic>> _library = [];
  bool _isProcessing = false;

  // ---------------------------------------------------------------------------
  // 1. 🏁 INITIALIZATION & REFRESH
  // ---------------------------------------------------------------------------

  /// Call this when the app starts or after a purchase.
  Future<void> reloadLibrary() async {
    _library = await PassportService.fetchUserLibrary(forceRefresh: true);
    _applyJustInTimeIndexing(); // 👈 Fixes the NULL page_index issue
    debugPrint("🧠 BRAIN: Library reloaded. ${_library.length} books indexed.");
  }

  /// 🧠 SYNC: Called by PassportService whenever data is fetched.
  /// This keeps the Brain's inventory up-to-date without a circular fetch loop.
  void syncLibrary(List<Map<String, dynamic>> library) {
    _library = library;
    _applyJustInTimeIndexing();
    debugPrint("🧠 BRAIN: Library synced from Service. ${_library.length} books.");
    }

  /// 🛠 JIT INDEXING: Sorts visas by date and assigns page numbers in memory.
  void _applyJustInTimeIndexing() {
    for (var book in _library) {
      final String sku = book['sku_type'] ?? 'free_tier';
      
      // Free/Single have no cover page. Standard/Diplomat start at Page 1.
      // (Index 0 is the Cover).
      int pageCounter = (sku == 'standard_book' || sku == 'diplomat_book') ? 1 : 1; 

      List visas = book['visas'] ?? [];
      // Sort: Oldest First
      visas.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));

      for (var visa in visas) {
        visa['jit_page_index'] = pageCounter;
        pageCounter++;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 2. 🤖 THE DECISION ENGINE
  // ---------------------------------------------------------------------------

  /// 🧠 THE MASTER ROUTING ENGINE (The Waterfall)
  /// Determines exactly which book receives the incoming stamp.
  Future<BrainDecision> processStampRequest(Restaurant restaurant) async {
    if (_isProcessing) return BrainDecision.ignore();
    _isProcessing = true;

    try {
      final String rawCuisine = await _determineCuisine(restaurant);
      final String targetCuisine = _capitalize(rawCuisine);

      debugPrint("🧠 BRAIN: Analyzing stamp for '${restaurant.name}' ($targetCuisine)...");

      // ---------------------------------------------------------
      // 🛫 PRE-FLIGHT CHECKS
      // ---------------------------------------------------------
      
      // 1. Filter the Library (The Premium Bypass)
      // If the user owns ANY paid book, the Wildcard ('free_tier') becomes invisible.
      final List<Map<String, dynamic>> eligibleBooks = _getEligibleBooks();
      
      if (eligibleBooks.isEmpty) {
        // Should theoretically never happen if a guest book exists, but safety first.
        return BrainDecision.upgradeRequired(reason: "No valid passport found.");
      }

      // ---------------------------------------------------------
      // 🌊 THE DECISION WATERFALL
      // ---------------------------------------------------------

      // PHASE 1: THE MAGNET PROTOCOL (Group Cuisines)
      // Do we have an existing OPEN visa for this exact cuisine?
      final magnetBook = _findBookWithExistingVisa(eligibleBooks, targetCuisine);
      if (magnetBook != null) {
        final activeBook = _findActiveBook();
        final bool isCurrentBook = activeBook != null && activeBook['id'] == magnetBook['id'];

        if (isCurrentBook) {
           debugPrint("🧠 BRAIN: Magnet Protocol -> Stay in active book.");
           return BrainDecision.stayAndStamp(
             bookId: magnetBook['id'],
             requiresNewVisa: false,
             visaCuisine: targetCuisine
           );
        } else {
           debugPrint("🧠 BRAIN: Magnet Protocol -> Switching to Book ${magnetBook['id']}");
           return BrainDecision.switchAndStamp(
             targetBookId: magnetBook['id'],
             reason: "Found existing $targetCuisine visa.",
             requiresNewVisa: false,
             visaCuisine: targetCuisine
           );
        }
      }

      // PHASE 2 & 3: THE BLANK CANVAS / LONE WOLF PROTOCOL
      // We need a new slot. Find the OLDEST eligible book that has space.
      // (This handles Standard pages, empty Single Visas, and the Wildcard all in one)
      final candidateBook = _findOldestBookWithSpace(eligibleBooks, targetCuisine);
      
      if (candidateBook != null) {
        final activeBook = _findActiveBook();
        final bool isCurrentBook = activeBook != null && activeBook['id'] == candidateBook['id'];
        
        // Check if we need to create a new visa (Standard) or just stamp (Wildcard/Single)
        // For Standard/Diplomat, we always 'requireNewVisa' if it's a new cuisine.
        // For Single/Wildcard, the 'visa' is the book itself.
        final sku = candidateBook['sku_type'] ?? 'free_tier';
        final bool isMultiPage = sku.contains('standard') || sku.contains('diplomat');
        
        if (isCurrentBook) {
           debugPrint("🧠 BRAIN: Blank Canvas -> Using active book.");
           return BrainDecision.stayAndStamp(
             bookId: candidateBook['id'],
             requiresNewVisa: isMultiPage, 
             visaCuisine: targetCuisine
           );
        } else {
           debugPrint("🧠 BRAIN: Blank Canvas -> Switching to Book ${candidateBook['id']}");
           return BrainDecision.switchAndStamp(
             targetBookId: candidateBook['id'],
             reason: "Found available space in inventory.",
             requiresNewVisa: isMultiPage,
             visaCuisine: targetCuisine
           );
        }
      }

      // PHASE 4: DEAD END (The Paywall)
      debugPrint("🧠 BRAIN: Dead End. Upgrade required.");

      // 📡 TELEMETRY: Stamp Rejected (User intent blocked by game rules)
      TelemetryService.logInteraction(
        actionType: 'stamp_rejected',
        metadata: {
          'reason': 'upgrade_required_no_space',
          'attempted_cuisine': targetCuisine,
        }
      );

      return BrainDecision.upgradeRequired(
        reason: "No available space for $targetCuisine."
      );

    } catch (e) {
      debugPrint("🧠 BRAIN ERROR: $e");
      return BrainDecision.ignore();
    } finally {
      _isProcessing = false;
    }
  }

  // ---------------------------------------------------------
  // 🕵️ NEW INTELLIGENCE HELPERS
  // ---------------------------------------------------------

  /// Returns the list of books the Brain is allowed to touch.
  /// If user has PAID books, the 'free_tier' is excluded.
  List<Map<String, dynamic>> _getEligibleBooks() {
    final hasPaidBooks = _library.any((b) => (b['sku_type'] ?? 'free_tier') != 'free_tier');
    
    if (hasPaidBooks) {
      // 🛡️ Premium Bypass: Hide the Wildcard
      return _library.where((b) => (b['sku_type'] ?? 'free_tier') != 'free_tier').toList();
    } else {
      // Free User: Can only use what they have (likely just the Wildcard)
      return _library;
    }
  }

  /// Phase 1 Helper: Finds the oldest book that ALREADY has this cuisine active
  Map<String, dynamic>? _findBookWithExistingVisa(List<Map<String, dynamic>> books, String cuisine) {
    final sorted = List<Map<String, dynamic>>.from(books);
    sorted.sort((a, b) {
       final tA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
       final tB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
       return tA.compareTo(tB);
    });

    final targetLower = cuisine.toLowerCase();

    for (var book in sorted) {
      final sku = book['sku_type'] ?? 'free_tier';
      final stamps = book['stamps'] as List? ?? [];
      final visas = book['visas'] as List? ?? []; // 👈 We must check the visas array

      if (sku == 'free_tier') continue;

      // Single Visa Logic
      if (sku.contains('single')) {
        String? assignedCuisine;
        if (visas.isNotEmpty) {
           assignedCuisine = visas.first['cuisine']?.toString().toLowerCase();
        } else if (stamps.isNotEmpty) {
           assignedCuisine = stamps.first['cuisine']?.toString().toLowerCase();
        }

        if (assignedCuisine == targetLower && stamps.length < 4) {
          return book;
        }
      }

      // Standard/Diplomat Logic
      if (sku.contains('standard') || sku.contains('diplomat')) {
        // Do we have a visa issued for this cuisine?
        final hasVisa = visas.any((v) => (v['cuisine'] ?? '').toString().toLowerCase() == targetLower);
        
        if (hasVisa) {
           // Ensure the page isn't full
           final cuisineStamps = stamps.where((s) => (s['cuisine'] ?? '').toString().toLowerCase() == targetLower).toList();
           if (cuisineStamps.length < 4) {
             return book;
           }
        }
      }
    }
    return null;
  }

  /// Phase 2/3 Helper: Finds the oldest book that CAN take a new stamp/visa
  Map<String, dynamic>? _findOldestBookWithSpace(List<Map<String, dynamic>> books, String cuisine) {
    final sorted = List<Map<String, dynamic>>.from(books);
    sorted.sort((a, b) {
       final tA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
       final tB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
       return tA.compareTo(tB);
    });

    for (var book in sorted) {
      final sku = book['sku_type'] ?? 'free_tier';
      final stamps = book['stamps'] as List? ?? [];
      final visas = book['visas'] as List? ?? [];
      
      // Smart Capacity Check
      int maxPages = 1;
      if (sku.contains('standard')) maxPages = 6;
      if (sku.contains('diplomat')) maxPages = 21;

      if (book['status'] == 'archived') continue;
      if (stamps.length >= (maxPages * 4)) continue;

      if (sku == 'free_tier') {
        return book;
      }
      else if (sku.contains('single')) {
        // Single Visa is ONLY a blank canvas if it has zero visas and zero stamps
        if (visas.isEmpty && stamps.isEmpty) return book;
      }
      else {
        // Standard/Diplomat: Can we add a new page?
        // We check if the number of issued visas is less than the book's page limit
        if (visas.length < maxPages) {
          return book; 
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 2.5 🧠 CONTEXT ENGINE (The "Read" Logic)
  // ---------------------------------------------------------------------------

  PageContext resolvePageContext(Map<String, dynamic> book, int pageIndex) {
    final String sku = book['sku_type'] ?? 'free_tier';
    final List visas = book['visas'] ?? [];
    
    // 🛠 FIX: Safely convert AND FORMAT the stamps
    final List<Map<String, String>> stamps = (book['stamps'] as List? ?? []).map((item) {
      final s = item as Map<String, dynamic>;
      
      // 📅 DATE FIXER logic
      String formattedDate = "Recent";
      final rawDate = s['stamped_at'] ?? s['date'];
      
      if (rawDate != null) {
        try {
          // If it's a long database string (e.g. 2026-02-14T12:00:00...), parse it.
          if (rawDate.toString().contains('T') || rawDate.toString().contains('-')) {
             final dt = DateTime.parse(rawDate.toString());
             formattedDate = DateFormat('MMM d, yyyy').format(dt);
          } else {
             // It might already be formatted (e.g. "Feb 14, 2026")
             formattedDate = rawDate.toString();
          }
        } catch (e) {
          formattedDate = rawDate.toString();
        }
      }

      return {
        'restaurant_name': (s['restaurant_name'] ?? s['name'] ?? '').toString(),
        'name': (s['restaurant_name'] ?? s['name'] ?? '').toString(),
        'country_cuisine': (s['country_cuisine'] ?? s['cuisine'] ?? 'Global').toString(),
        'cuisine': (s['country_cuisine'] ?? s['cuisine'] ?? 'Global').toString(),
        'date': formattedDate, // 👈 Now using the clean version
      };
    }).toList();

    // A. SINGLE PAGE / SINGLE VISA LOGIC
    if (sku == 'single_page') {
      if (visas.isEmpty) {
        return PageContext(
          title: "SINGLE ENTRY",
          targetCuisine: "Global",
          isGlobalPage: true,
          isVacant: true,
          stamps: []
        );
      } else {
        final visa = visas.first;
        final String cuisine = visa['cuisine'].toString();
        
        return PageContext(
          title: cuisine.toUpperCase(),
          targetCuisine: cuisine,
          isGlobalPage: false,
          isVacant: false,
          stamps: stamps
        );
      }
    }

    // B. WILDCARD LOGIC
    if (sku == 'free_tier') {
      return PageContext(
        title: "TOURIST STATUS",
        targetCuisine: "Global",
        isGlobalPage: true,
        isVacant: false,
        stamps: stamps 
      );
    }

    // C. STANDARD / DIPLOMAT LOGIC
    // Page 0 = Cover / Global Page
    if (pageIndex == 0) {
      final globalStamps = stamps.where((s) => 
        (s['country_cuisine'] ?? s['cuisine']).toString().toLowerCase() == 'global'
      ).toList();

      return PageContext(
        title: "GLOBAL VISA",
        targetCuisine: "Global",
        isGlobalPage: true,
        isVacant: false,
        stamps: globalStamps
      );
    }

    // Page 1+ = Specific Visas
    final int visaIndex = pageIndex - 1;

    if (visaIndex < visas.length) {
      final visa = visas[visaIndex];
      final String cuisine = visa['cuisine'].toString();

      final allCuisineStamps = stamps.where((s) => 
        (s['country_cuisine'] ?? s['cuisine']).toString().toLowerCase() == cuisine.toLowerCase()
      ).toList();

      int previousPagesOfSameCuisine = 0;
      for (int i = 0; i < visaIndex; i++) {
        if (visas[i]['cuisine'].toString().toLowerCase() == cuisine.toLowerCase()) {
          previousPagesOfSameCuisine++;
        }
      }

      final int skipCount = previousPagesOfSameCuisine * 4;
      final pageStamps = allCuisineStamps.skip(skipCount).take(4).toList();

      return PageContext(
        title: cuisine.toUpperCase(),
        targetCuisine: cuisine,
        isGlobalPage: false,
        isVacant: false,
        stamps: pageStamps
      );
    }

    // Case: Vacant Slot
    return PageContext(
      title: "VACANT PAGE",
      targetCuisine: "Global",
      isGlobalPage: true,
      isVacant: true,
      stamps: []
    );
  }

  // ---------------------------------------------------------------------------
  // 2.6 🧭 NAVIGATION ENGINE (The "Where" Logic)
  // ---------------------------------------------------------------------------

  /// Tells the UI which page index to flip to for a specific cuisine.
  int calculateTargetPageIndex(Map<String, dynamic> book, String targetCuisine) {
    final String sku = book['sku_type'] ?? 'free_tier';
    final List visas = book['visas'] ?? [];

    // A. SINGLE PAGE / WILDCARD
    // They essentially only have one functional stamping ground (Index 0).
    // (Even though Single Page technically has a cover, we treat the Visa as the main view).
    if (sku == 'single_page' || sku == 'free_tier') {
      return 0; 
    }

    // B. STANDARD / DIPLOMAT
    // Page 0 is Cover. Page 1+ are Visas.
    
    // 1. Look for existing visa
    for (int i = 0; i < visas.length; i++) {
      if (visas[i]['cuisine'].toString().toLowerCase() == targetCuisine.toLowerCase()) {
        return i + 1; // Found it! (Add 1 because Index 0 is Cover)
      }
    }

    // 2. If not found, it goes in the next available slot.
    // (e.g. if we have 2 visas, they are at Index 1 and 2. Next slot is Index 3).
    return visas.length + 1;
  }

  // ---------------------------------------------------------------------------
  // 3. 🕵️ INVENTORY SCANNERS
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // 3. 🕵️ INVENTORY SCANNERS (The Fix)
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? _findActiveBook() {
    // 🛠 FIX: Use a loop to safely return NULL if not found.
    // The previous 'orElse: () => {}' was returning an empty map,
    // creating a "Phantom Book" that tricked the logic.
    for (var b in _library) {
      if (b['status'] == 'active') return b;
    }
    return null;
  }

  /// Scans ALL books (Active & Archived) for a visa that matches the cuisine
  /// AND has < 4 stamps.
  Map<String, dynamic>? _findBookWithAvailableVisa(String cuisine) {
    for (var book in _library) {
      final List visas = book['visas'] ?? [];
      final List stamps = book['stamps'] ?? [];

      // Find the specific visa for this cuisine
      final matchingVisa = visas.firstWhere(
        (v) => v['cuisine'].toString().toLowerCase() == cuisine.toLowerCase(),
        orElse: () => null
      );

      if (matchingVisa != null) {
        // Check capacity of THIS specific page
        // (We count how many stamps share this cuisine)
        final int stampCount = stamps.where((s) => 
          s['country_cuisine'].toString().toLowerCase() == cuisine.toLowerCase()
        ).length;

        if (stampCount < 4) {
          debugPrint("🧠 BRAIN: Found Match in Book ${book['id']} ($stampCount/4 stamps)");
          return book;
        }
      }
      
      // 🆕 WILDCARD EXCEPTION:
      // Wildcards don't have specific "Visas" per se, they just take stamps.
      // If it's a Wildcard, check if it has space and matches logic.
      if (book['sku_type'] == 'free_tier') {
         if (stamps.length < 4) {
            // Wildcards accept anything, so they are a valid fallback match
            // BUT we prioritize strict matches first. This scanner is usually for
            // finding the "Japanese Page".
         }
      }
    }
    return null;
  }

  Map<String, dynamic>? _findFirstEmptyBook() {
    // Look for a book with 0 stamps and 0 visas
    for (var book in _library) {
      final stamps = book['stamps'] as List? ?? [];
      final visas = book['visas'] as List? ?? [];
      if (stamps.isEmpty && visas.isEmpty) return book;
    }
    return null;
  }

  bool _canBookAcceptNewVisa(Map<String, dynamic> book, String cuisine) {
    final String sku = book['sku_type'] ?? 'free_tier';
    final List visas = book['visas'] ?? [];
    
    // 1. WILDCARD (Max 4 stamps total)
    if (sku == 'free_tier') {
       final stamps = book['stamps'] as List? ?? [];
       return stamps.length < 4;
    }

    // 2. SINGLE VISA (Max 1 Visa)
    if (sku == 'single_page') {
      if (visas.isEmpty) return true; // Empty? Yes.
      
      // Occupied? Only if it matches (Monogamy)
      final existing = visas.first['cuisine'];
      if (existing.toString().toLowerCase() == cuisine.toLowerCase()) {
         // 🛠 FIX: Even if cuisine matches, is it FULL?
         // A Single Visa book cannot grow pages. If it has 4 stamps, it's dead.
         final stamps = book['stamps'] as List? ?? [];
         if (stamps.length >= 4) return false; // 🛑 FULL!
         
         return true; // Match + Space available
      }
      return false; // Wrong Cuisine
    }

    // 3. STANDARD (Max 6 Total Pages -> 5 Visas)
    if (sku == 'standard_book') {
      // 🛠 FIX: Standard has 6 pages total (1 Cover + 5 Visas)
      // If we have < 5 visas, we can ALWAYS add a page (either new cuisine or extension).
      return visas.length < 5; 
    }

    // 4. DIPLOMAT (Max 21 Total Pages -> 20 Visas)
    if (sku == 'diplomat_book') {
      // 🛠 FIX: Diplomat has 21 pages total (1 Cover + 20 Visas)
      return visas.length < 20;
    }

    return false;
  }

  /// Checks if the user has already collected a stamp for this restaurant
  /// anywhere in their entire passport library.
  bool hasDuplicateStamp(String restaurantName) {
    for (var book in _library) {
      final stamps = book['stamps'] as List? ?? [];
      for (var stamp in stamps) {
        final existingName = (stamp['restaurant_name'] ?? stamp['name'])?.toString();
        if (existingName?.toLowerCase() == restaurantName.toLowerCase()) {
          return true; // Found a duplicate!
        }
      }
    }
    return false; // All clear
  }

  // ---------------------------------------------------------------------------
  // 4. 🔮 HELPERS
  // ---------------------------------------------------------------------------

  Future<String> _determineCuisine(Restaurant r) async {
    // 1. Database Lookup (Mappings)
    // We defer to the existing logic, or just use the restaurant's tag for now.
    // Ideally this calls Supabase, but to keep Brain sync, we'll try a basic parse.
    String raw = r.cuisine.split(';').first.trim();
    
    // Quick DB check if possible (Optional optimization)
    try {
      final response = await Supabase.instance.client
          .from('cuisine_mappings')
          .select('target_cuisine')
          .ilike('raw_tag', raw)
          .maybeSingle();
      if (response != null) return response['target_cuisine'];
    } catch (e) {}

    return raw; // Fallback
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}

// 📦 DECISION PACKAGE
class BrainDecision {
  final BrainAction action;
  final String? targetBookId;
  final String? reason;
  final bool requiresNewVisa;
  final String? visaCuisine;

  BrainDecision({
    required this.action, 
    this.targetBookId, 
    this.reason,
    this.requiresNewVisa = false,
    this.visaCuisine,
  });

  factory BrainDecision.ignore() => BrainDecision(action: BrainAction.ignore);
  
  factory BrainDecision.stayAndStamp({
    required String bookId, 
    required bool requiresNewVisa, 
    String? visaCuisine
  }) => BrainDecision(
    action: BrainAction.stayAndStamp,
    targetBookId: bookId,
    requiresNewVisa: requiresNewVisa,
    visaCuisine: visaCuisine
  );

  factory BrainDecision.switchAndStamp({
    required String targetBookId, 
    required String reason,
    bool requiresNewVisa = false,
    String? visaCuisine
  }) => BrainDecision(
    action: BrainAction.switchAndStamp,
    targetBookId: targetBookId,
    reason: reason,
    requiresNewVisa: requiresNewVisa,
    visaCuisine: visaCuisine
  );

  factory BrainDecision.upgradeRequired({required String reason}) => 
      BrainDecision(action: BrainAction.upgrade, reason: reason);
}

enum BrainAction {
  ignore,         // Do nothing (processing or invalid)
  stayAndStamp,   // Stamp the current book
  switchAndStamp, // Switch to another book, then stamp
  upgrade         // Show Paywall
}

// 📖 CONTEXT PACKAGE (The "Read" Result)
// This tells the UI exactly what to draw, so it doesn't have to guess.
class PageContext {
  final String title;        // Display Title (e.g. "INDIAN", "GLOBAL VISA")
  final String targetCuisine; // The actual tag for the DB (e.g. "Indian", "Global")
  final bool isGlobalPage;   // True if it's a cover or generic page
  final bool isVacant;       // True if this slot is empty
  final List<Map<String, String>> stamps; // The exact stamps to show

  PageContext({
    required this.title,
    required this.targetCuisine,
    required this.isGlobalPage,
    required this.isVacant,
    required this.stamps,
  });
}