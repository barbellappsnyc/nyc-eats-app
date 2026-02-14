import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🔌 CONNECTING THE LOGIC ENGINE
import '../logic/passport_rules.dart';
import '../logic/single_visa_rules.dart';
import '../logic/standard_rules.dart';

class PassportService {
  static final SupabaseClient _client = Supabase.instance.client;

  // 🧠 MEMORY CACHE (RAM)
  static List<Map<String, dynamic>>? _libraryCache;
  static Map<String, dynamic>? _profileCache;

  // 1. 🔥 PRE-WARM
  static Future<void> prewarmCache() async {
    await _loadProfileFromDisk();
    
    await Future.wait([
      fetchUserLibrary(forceRefresh: true),
      fetchUserProfile(forceRefresh: true),
    ]);
  }

  // 2. 📚 FETCH LIBRARY (Robust Version)
  static Future<List<Map<String, dynamic>>> fetchUserLibrary({bool forceRefresh = false}) async {
    if (!forceRefresh && _libraryCache != null) return _libraryCache!;

    final userId = _client.auth.currentUser?.id;

    // 👻 GUEST MODE
    if (userId == null) {
      return await _loadGuestBook();
    }

    // ☁️ USER MODE (With Timeout Protection)
    try {
      final response = await _client
          .from('user_passport_books')
          .select('''
            *,
            user_visas ( *, visa_types (color_hex) ),
            collected_stamps ( * )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 5)); // 🛡️ Safety Valve

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

      if (data.isEmpty) return await _loadGuestBook(); // Fallback

      // Sort stamps/visas
      for (var book in data) {
        List visas = List.from(book['user_visas'] ?? []);
        visas.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));
        book['visas'] = visas; 

        List stamps = List.from(book['collected_stamps'] ?? []);
        stamps.sort((a, b) => (a['stamped_at'] ?? '').compareTo(b['stamped_at'] ?? ''));
        book['stamps'] = stamps;
      }

      _libraryCache = data;
      return data;
    } catch (e) {
      debugPrint("⚠️ Cloud Fetch Failed (loading Guest Book instead): $e");
      return await _loadGuestBook();
    }
  }

  // 🛠 HELPER: Load Guest Book (With Corruption Protection)
  static Future<List<Map<String, dynamic>>> _loadGuestBook() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedStamps = prefs.getString('guest_stamps');
      List<dynamic> localStamps = [];
      
      if (storedStamps != null) {
        try {
          localStamps = jsonDecode(storedStamps);
        } catch (e) {
          debugPrint("❌ Corrupt Guest Data detected. Clearing.");
          await prefs.remove('guest_stamps'); 
        }
      }

      final Map<String, dynamic> guestBook = {
        'id': 'guest_book_local',
        'sku_type': 'free_tier',
        'status': 'active',
        'max_pages': 1,
        'cover_color': 'legacy',
        'visas': [], 
        'stamps': localStamps 
      };
      
      _libraryCache = [guestBook];
      return _libraryCache!;
    } catch (e) {
      return []; 
    }
  }
  
  // 3. 👤 FETCH PROFILE
  static Future<Map<String, dynamic>?> fetchUserProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _profileCache != null) return _profileCache;
    
    if (_profileCache == null) {
      await _loadProfileFromDisk();
      if (_profileCache != null && !forceRefresh) return _profileCache;
    }

    final userId = _client.auth.currentUser?.id;
    
    // Guest Logic
    if (userId == null) {
      final prefs = await SharedPreferences.getInstance();
      _profileCache = {
        'display_name': prefs.getString('guest_name') ?? 'TRAVELER',
        'age': prefs.getInt('guest_age') ?? 18,
        'gender': prefs.getString('guest_gender') ?? 'X',
        'photo_url': prefs.getString('guest_photo_local_path'),
      };
      return _profileCache;
    }

    try {
      final data = await _client
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (data != null) {
        _profileCache = data;
        _saveProfileToDisk(data);
      }
      return data;
    } catch (e) {
      return _profileCache;
    }
  }

  // 💾 DISK PERSISTENCE
  static Future<void> _saveProfileToDisk(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_profile', jsonEncode(data));
  }

  static Future<void> _loadProfileFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('cached_user_profile');
    if (raw != null) {
      try {
        _profileCache = jsonDecode(raw);
      } catch (e) {}
    }
  }

  static Future<void> updateLocalProfile(Map<String, dynamic> updates) async {
    if (_profileCache == null) {
      _profileCache = {}; 
    }
    _profileCache!.addAll(updates);
    
    // 1. Save standard cache
    await _saveProfileToDisk(_profileCache!);

    // 2. ALSO SAVE TO GUEST KEYS
    final prefs = await SharedPreferences.getInstance();
    if (updates.containsKey('display_name')) {
      await prefs.setString('guest_name', updates['display_name']);
    }
    if (updates.containsKey('age')) {
      await prefs.setInt('guest_age', updates['age']);
    }
    if (updates.containsKey('gender')) {
      await prefs.setString('guest_gender', updates['gender']);
    }
    
    if (updates.containsKey('photo_url')) {
      final String? url = updates['photo_url'];
      if (url != null) {
        await prefs.setString('guest_photo_local_path', url);
      } else {
        await prefs.remove('guest_photo_local_path'); 
      }
    }
  }

  // 4. 🔍 GETTERS
  static Map<String, dynamic>? getCachedBook(String bookId) {
    if (_libraryCache == null) return null;
    return _libraryCache!.firstWhere(
      (b) => b['id'] == bookId, 
      orElse: () => <String, dynamic>{}
    );
  }
  static Map<String, dynamic>? getCachedProfile() => _profileCache;

  // 5. 🧠 STATE MEMORY
  static void updateBookPage(String bookId, int pageIndex) {
    if (_libraryCache == null) return;
    final bookIndex = _libraryCache!.indexWhere((b) => b['id'] == bookId);
    if (bookIndex != -1) {
      _libraryCache![bookIndex]['last_page_index'] = pageIndex;
    }
  }

  static Future<void> createStarterBook(String userId) async {
    final existing = await _client.from('user_passport_books').select().eq('user_id', userId).maybeSingle();
    if (existing == null) {
      await _client.from('user_passport_books').insert({
        'user_id': userId, 'sku_type': 'free_tier', 'status': 'active', 'max_pages': 1, 'cover_color': 'legacy'
      });
      _libraryCache = null; 
    }
  }
  
  static Future<void> issueVisa(String userId, String bookId, String cuisine) async {
    await _client.from('user_visas').insert({
      'user_id': userId, 'book_id': bookId, 'cuisine': cuisine
    });
    _libraryCache = null; 
  }

  static void addStampToCache(String bookId, Map<String, dynamic> newStamp) {
    if (_libraryCache == null) return;
    
    final bookIndex = _libraryCache!.indexWhere((b) => b['id'] == bookId);
    if (bookIndex != -1) {
      final cacheEntry = {
        'restaurant_name': newStamp['name'] ?? newStamp['restaurant_name'],
        'stamped_at': DateTime.now().toIso8601String(),
        'country_cuisine': newStamp['cuisine'] ?? newStamp['country_cuisine'],
      };
      
      List stamps = List.from(_libraryCache![bookIndex]['stamps'] ?? []);
      stamps.add(cacheEntry);
      stamps.sort((a, b) => (a['stamped_at'] ?? '').compareTo(b['stamped_at'] ?? ''));
      _libraryCache![bookIndex]['stamps'] = stamps;
    }
  }

  static void addVisaToCache(String bookId, Map<String, dynamic> newVisa) {
    if (_libraryCache == null) return;

    final bookIndex = _libraryCache!.indexWhere((b) => b['id'] == bookId);
    if (bookIndex != -1) {
      List visas = List.from(_libraryCache![bookIndex]['visas'] ?? []);
      visas.add(newVisa);
      visas.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));
      _libraryCache![bookIndex]['visas'] = visas;
    }
  }

  // ===========================================================================
  // 🧠 RULES ENGINE: THE NEW INTELLIGENT CORE
  // ===========================================================================

  // 🏭 FACTORY: Get the right rules for the book
  static PassportRules _getRulesForBook(String sku) {
    if (sku == 'single_page') return SingleVisaRules();
    return StandardRules(); // Handles Standard & Diplomat
  }

  // 🚦 THE ROUTER
  // Replaces 'determineStampTarget' with strict logic flow.
  // Returns:
  // - { 'action': 'PROCEED', 'bookId': ..., 'pageIndex': ..., 'requiresNewRow': ... }
  // - { 'action': 'SWITCH_BOOK', 'targetBookId': ... }
  // - { 'action': 'VIOLATION_MONOGAMY' | 'VIOLATION_FULL' ... }
  static Map<String, dynamic> determineStampAction({
    required String targetCuisine,
    required List<Map<String, dynamic>> library,
  }) {
    // 1. Find the Active Book (The King)
    final activeIndex = library.indexWhere((b) => b['status'] == 'active');
    
    if (activeIndex == -1) {
      // Fallback: Check for any Standard/Free book
      return {'action': 'ERROR', 'reason': 'No active passport found.'};
    }

    final activeBook = library[activeIndex];
    final String sku = activeBook['sku_type'] ?? 'free_tier';
    
    // 🆓 Free Tier Bypass (Simple logic)
    if (sku == 'free_tier') {
       final stamps = activeBook['stamps'] as List? ?? [];
       if (stamps.length >= 4) return {'action': 'VIOLATION_FULL'};
       return {
         'action': 'PROCEED',
         'bookId': activeBook['id'],
         'pageIndex': 1,
         'requiresNewRow': false
       };
    }

    // 🤖 LOAD RULES ENGINE
    final rules = _getRulesForBook(sku);
    final String? violation = rules.validateStampAttempt(activeBook, targetCuisine);

    // ✅ SCENARIO A: ALL CLEAR
    if (violation == null) {
      return {
        'action': 'PROCEED',
        'bookId': activeBook['id'],
        'pageIndex': rules.findTargetPageIndex(activeBook, targetCuisine),
        'requiresNewRow': rules.requiresNewVisaRow(activeBook, targetCuisine)
      };
    }

    // 🛑 SCENARIO B: VIOLATION DETECTED
    // Can we "Auto-Switch" to another book?
    if (violation == 'violation_monogamy' || violation == 'violation_full') {
      // Scan the library for a Savior Book
      for (var book in library) {
        if (book['id'] == activeBook['id']) continue; // Skip the failed one
        
        // Only look at "Upgrade" books (Standard/Diplomat)
        final String altSku = book['sku_type'] ?? 'free_tier';
        if (altSku == 'single_page' || altSku == 'free_tier') continue;

        final altRules = StandardRules();
        if (altRules.validateStampAttempt(book, targetCuisine) == null) {
          // 🎉 FOUND A SAVIOR!
          return {
            'action': 'SWITCH_BOOK',
            'targetBookId': book['id'],
            'reason': violation 
          };
        }
      }
    }

    // ❌ SCENARIO C: DEAD END
    // We couldn't fix it. Return the error to the UI (triggers Upgrade Dialog).
    return {'action': violation.toUpperCase()};
  }

  // ===========================================================================
  // 💾 SAVING & INFRASTRUCTURE
  // ===========================================================================

  // 8. 💾 UNIVERSAL STAMP SAVE
  static Future<void> addStamp({
    required String? bookId, 
    required Map<String, dynamic> stampData,
  }) async {
    final userId = _client.auth.currentUser?.id;

    // A. GUEST MODE -> Save to Disk
    if (userId == null) {
      await saveGuestStamp(stampData);
      return;
    }

    // B. LOGGED IN -> Save to Cloud
    if (bookId == null) {
      debugPrint("🛑 Error: Cannot save cloud stamp without a Book ID.");
      return;
    }

    final dbPayload = {
      'book_id': bookId,
      'user_id': userId,
      'restaurant_id': stampData['id'],
      'restaurant_name': stampData['name'] ?? stampData['restaurant_name'],
      'country_cuisine': stampData['cuisine'] ?? stampData['country_cuisine'],
      'stamped_at': DateTime.now().toIso8601String(),
    };
    
    try {
      await _client.from('collected_stamps').insert(dbPayload);
      
      // ✅ SUCCESS: Update local cache immediately
      addStampToCache(bookId, stampData);
      debugPrint("✅ Stamp saved to Cloud DB.");

      // 🆕 CHECK CAPACITY AFTER SAVING
      await checkCapacityAndRotate(bookId);
    } catch (e) {
      debugPrint("🛑 CLOUD SAVE FAILED: $e");
    }
  }

  // 6. 💾 GUEST: SAVE STAMP TO DISK
  static Future<void> saveGuestStamp(Map<String, dynamic> uiStamp) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Get existing
    String? existingJson = prefs.getString('guest_stamps');
    List<dynamic> currentList = existingJson != null ? jsonDecode(existingJson) : [];
    
    // 🛡️ PREVENT DUPLICATES
    final String newName = uiStamp['name'] ?? uiStamp['restaurant_name'];
    final bool alreadyExists = currentList.any((s) {
      final existingName = s['restaurant_name'] ?? s['name'];
      return existingName == newName;
    });

    if (alreadyExists) {
      debugPrint("⚠️ Stamp for $newName already exists. Skipping save.");
      return; 
    }

    // 2. 🔄 CONVERT TO CLOUD FORMAT
    final cloudFormatStamp = {
      'restaurant_name': newName,
      'country_cuisine': uiStamp['cuisine'],
      'stamped_at': DateTime.now().toIso8601String(),
    };
    
    currentList.add(cloudFormatStamp);
    
    // 3. Save to Disk
    await prefs.setString('guest_stamps', jsonEncode(currentList));
    
    // 4. Update RAM Cache
    addStampToCache('guest_book_local', uiStamp);
  }

  // 🚀 MIGRATION: SAFE MERGE WITH 4-STAMP HARD CAP
  static Future<void> migrateGuestData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    
    String? existingJson = prefs.getString('guest_stamps');
    if (existingJson == null) return;
    
    List<dynamic> localStamps = jsonDecode(existingJson);
    if (localStamps.isEmpty) return;

    debugPrint("🚚 Migrating ${localStamps.length} guest stamps...");

    try {
      final bookResponse = await _client
          .from('user_passport_books')
          .select('id')
          .eq('user_id', userId)
          .inFilter('sku_type', ['free_tier', 'standard_book', 'nyceats_standard']) 
          .limit(1)
          .maybeSingle();

      String targetBookId;

      if (bookResponse != null) {
        targetBookId = bookResponse['id'];
      } else {
        final newBook = await _client.from('user_passport_books').insert({
          'user_id': userId,
          'sku_type': 'free_tier',
          'status': 'active',
          'max_pages': 1,
          'cover_color': 'legacy'
        }).select().single();
        targetBookId = newBook['id'];
      }

      final existingStampsResponse = await _client
          .from('collected_stamps')
          .select('restaurant_name')
          .eq('book_id', targetBookId);

      final Set<String> existingNames = existingStampsResponse
          .map((row) => row['restaurant_name'] as String)
          .toSet();

      int currentFillLevel = existingNames.length;
      const int MAX_CAPACITY = 4;

      if (currentFillLevel >= MAX_CAPACITY) {
        debugPrint("🛑 Cloud book is full ($currentFillLevel/4). Discarding guest stamps.");
        await prefs.remove('guest_stamps');
        return;
      }

      List<Map<String, dynamic>> rowsToInsert = [];

      for (var stamp in localStamps) {
        if (currentFillLevel >= MAX_CAPACITY) break;

        final String rName = stamp['restaurant_name'] ?? stamp['name'];

        if (existingNames.contains(rName)) continue; 

        rowsToInsert.add({
          'user_id': userId,
          'book_id': targetBookId,
          'restaurant_name': rName,
          'country_cuisine': stamp['country_cuisine'] ?? stamp['cuisine'],
          'stamped_at': stamp['stamped_at'] ?? DateTime.now().toIso8601String(),
        });

        currentFillLevel++;
      }

      if (rowsToInsert.isNotEmpty) {
        await _client.from('collected_stamps').insert(rowsToInsert);
        debugPrint("✅ Successfully migrated ${rowsToInsert.length} stamps.");
      }

      await prefs.remove('guest_stamps');

    } catch (e) {
      debugPrint("⚠️ Migration Error: $e");
    }
  }

  // 🔥 UPDATED: Create a specific book with SKU Translation
  static Future<void> createBook({required String userId, required String sku}) async {
    int maxPages = 1;
    String coverColor = 'legacy';
    
    String dbSku = 'free_tier'; 
    
    if (sku.contains('diplomat')) {
      dbSku = 'diplomat_book';
      maxPages = 21; // 🛠 Updated from 20
      coverColor = 'navy_gold';
    } else if (sku.contains('standard')) {
      dbSku = 'standard_book'; 
      maxPages = 6;
      coverColor = 'standard_blue';
    } else if (sku.contains('single')) {
      dbSku = 'single_page'; 
      maxPages = 1;
    }

    debugPrint("📖 Creating Book: Store SKU='$sku' -> DB SKU='$dbSku'");

    await _client.from('user_passport_books').insert({
      'user_id': userId,
      'sku_type': dbSku,
      'status': 'active',
      'max_pages': maxPages,
      'cover_color': coverColor,
      'created_at': DateTime.now().toIso8601String(),
    });

    _libraryCache = null; 
  }

  // 7. 🔄 ACTIVATE BOOK
  static Future<void> activateBook(String bookId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('user_passport_books')
        .update({'status': 'archived'})
        .eq('user_id', userId);

    await _client
        .from('user_passport_books')
        .update({'status': 'active'})
        .eq('id', bookId);

    _libraryCache = null;
  }

  // 9. 🔄 AUTO-ROTATE
  static Future<void> checkCapacityAndRotate(String bookId) async {
    final book = getCachedBook(bookId);
    if (book == null) return;

    final stamps = book['stamps'] as List? ?? [];
    final maxPages = book['max_pages'] ?? 1;
    final int capacity = maxPages * 4; 

    if (stamps.length >= capacity) {
      debugPrint("📚 Book $bookId is FULL. Archiving and rotating...");

      await _client.from('user_passport_books')
          .update({'status': 'archived'})
          .eq('id', bookId);

      await validateLibraryIntegrity();
    }
  }

  // 10. 👑 THE FIFO ENFORCER
  static Future<bool> validateLibraryIntegrity() async {
    final library = await fetchUserLibrary(forceRefresh: false);
    
    final successionLine = library.where((b) => (b['sku_type'] ?? 'free_tier') != 'free_tier').toList();

    // SORT BY AGE (Oldest First = The King)
    successionLine.sort((a, b) {
      final tA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
      final tB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
      return tA.compareTo(tB); 
    });

    bool madeChanges = false;
    bool kingFound = false;

    for (var book in successionLine) {
      final String bookId = book['id'];
      final String currentStatus = book['status'] ?? 'inactive';
      
      final stamps = book['stamps'] as List? ?? [];
      final maxPages = book['max_pages'] ?? 1;
      final bool isFull = stamps.length >= (maxPages * 4);

      String targetStatus;

      if (isFull) {
        targetStatus = 'archived';
      } else if (!kingFound) {
        targetStatus = 'active';
        kingFound = true;
      } else {
        targetStatus = 'inactive'; 
      }

      if (currentStatus != targetStatus) {
        debugPrint("👑 FIFO Enforcer: Changing $bookId from '$currentStatus' to '$targetStatus'");
        await _client.from('user_passport_books')
            .update({'status': targetStatus})
            .eq('id', bookId);
        madeChanges = true;
      }
    }

    if (madeChanges) {
      _libraryCache = null;
    }
    
    return madeChanges;
  }
}