import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../services/passport_service.dart';

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

  /// The UI calls this: "User wants to stamp Sushi Sho."
  /// The Brain returns a [BrainDecision] telling the UI what to do.
  Future<BrainDecision> processStampRequest(Restaurant restaurant) async {
    if (_isProcessing) return BrainDecision.ignore(); // 🛡️ Prevent Machine-Gun Clicking
    _isProcessing = true;

    try {
      // 🛡️ FIX: Capitalize cuisine to match DB (e.g. "indian" -> "Indian")
      final String rawCuisine = await _determineCuisine(restaurant);
      final String targetCuisine = _capitalize(rawCuisine);
      
      debugPrint("🧠 BRAIN: Analyzing stamp for '${restaurant.name}' ($targetCuisine)...");
      // B. RUN THE INVENTORY SCAN
      // We look for the BEST place to put this stamp.
      
      // 1. CHECK PRIORITY: Existing Visa with Space (Context Switch)
      // "Do I already have a Japanese page somewhere?"
      final existingMatch = _findBookWithAvailableVisa(targetCuisine);
      if (existingMatch != null) {
        return BrainDecision.switchAndStamp(
          targetBookId: existingMatch['id'],
          reason: "Found existing $targetCuisine visa.",
        );
      }

      // 2. CHECK ACTIVE: Can the current Active Book take a NEW visa?
      final activeBook = _findActiveBook();
      if (activeBook != null) {
        if (_canBookAcceptNewVisa(activeBook, targetCuisine)) {
           return BrainDecision.stayAndStamp(
             bookId: activeBook['id'],
             requiresNewVisa: true,
             visaCuisine: targetCuisine
           );
        }
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
  // 3. 🕵️ INVENTORY SCANNERS
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? _findActiveBook() {
    return _library.firstWhere((b) => b['status'] == 'active', orElse: () => {});
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
    
    // 1. WILDCARD (Max 4 stamps total, effectively 1 page)
    if (sku == 'free_tier') {
       final stamps = book['stamps'] as List? ?? [];
       return stamps.length < 4;
    }

    // 2. SINGLE VISA (Max 1 Visa)
    if (sku == 'single_page') {
      if (visas.isEmpty) return true; // Empty? Yes.
      // Occupied? Only if it matches (Monogamy)
      final existing = visas.first['cuisine'];
      return existing.toString().toLowerCase() == cuisine.toLowerCase();
    }

    // 3. STANDARD (Max 5 Visas)
    if (sku == 'standard_book') {
      // Check if we already have this visa (handled by scanner, but double check)
      bool hasIt = visas.any((v) => v['cuisine'].toString().toLowerCase() == cuisine.toLowerCase());
      if (hasIt) return true; // We accept the stamp on the existing page
      
      return visas.length < 5; // Do we have a blank page?
    }

    // 4. DIPLOMAT (Max 20 Visas)
    if (sku == 'diplomat_book') {
      bool hasIt = visas.any((v) => v['cuisine'].toString().toLowerCase() == cuisine.toLowerCase());
      if (hasIt) return true;
      
      return visas.length < 20;
    }

    return false;
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