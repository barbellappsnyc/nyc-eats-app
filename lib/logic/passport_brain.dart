import 'dart:async';
import 'package:flutter/foundation.dart';
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

  Future<BrainDecision> processStampRequest(Restaurant restaurant) async {
    if (_isProcessing) return BrainDecision.ignore(); 
    _isProcessing = true;

    try {
      final String rawCuisine = await _determineCuisine(restaurant);
      final String targetCuisine = _capitalize(rawCuisine);
      
      debugPrint("🧠 BRAIN: Analyzing stamp for '${restaurant.name}' ($targetCuisine)...");

      // 👇 MOVE THIS UP: We need to know what book we are holding right now
      final activeBook = _findActiveBook();

      // 1. CHECK PRIORITY: Existing Visa with Space?
      final existingMatch = _findBookWithAvailableVisa(targetCuisine);
      if (existingMatch != null) {
        
        // 🧠 THE FIX: Is the match the exact book we are already holding?
        if (activeBook != null && existingMatch['id'] == activeBook['id']) {
           debugPrint("🧠 BRAIN: Match is the active book. Staying put.");
           return BrainDecision.stayAndStamp(
             bookId: activeBook['id'],
             requiresNewVisa: false, // It already exists!
             visaCuisine: targetCuisine
           );
        }
        
        // It's a different book. Proceed with the switch.
        debugPrint("🧠 BRAIN: Match is in storage. Switching books.");
        return BrainDecision.switchAndStamp(
          targetBookId: existingMatch['id'],
          reason: "Found existing $targetCuisine visa.",
          requiresNewVisa: false,
          visaCuisine: targetCuisine
        );
      }

      // 2. CHECK ACTIVE: Can the current Active Book take a NEW visa?
      if (activeBook != null) {
        // We have an active book, but is it allowed to take this stamp?
        if (_canBookAcceptNewVisa(activeBook, targetCuisine)) {
           return BrainDecision.stayAndStamp(
             bookId: activeBook['id'],
             requiresNewVisa: true,
             visaCuisine: targetCuisine
           );
        } else {
           debugPrint("🧠 BRAIN: Active book ${activeBook['id']} REJECTED the stamp (Full or Monogamy).");
        }
      } else {
         debugPrint("🧠 BRAIN: No Active Book found (All full or archived).");
      }

      // 3. CHECK ARCHIVE: Is there an empty book sitting in storage?
      final emptyBook = _findFirstEmptyBook();
      if (emptyBook != null) {
        return BrainDecision.switchAndStamp(
          targetBookId: emptyBook['id'],
          reason: "Active passport is full. Switching to fresh book.",
          requiresNewVisa: true,
          visaCuisine: targetCuisine
        );
      }

      // 4. DEAD END: No space anywhere.
      // This will trigger the "Upgrade Dialog" in the UI.
      return BrainDecision.upgradeRequired(
        reason: activeBook != null 
            ? "Your current passport is full." 
            : "No valid passport found."
      );

    } catch (e) {
      debugPrint("🧠 BRAIN ERROR: $e");
      return BrainDecision.ignore();
    } finally {
      _isProcessing = false;
    }
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