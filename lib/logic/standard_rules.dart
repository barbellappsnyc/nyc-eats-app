import 'passport_rules.dart';

class StandardRules implements PassportRules {
  @override
  String? validateStampAttempt(Map<String, dynamic> book, String targetCuisine) {
    final int maxCapacity = book['max_pages'] ?? 6; // Default to Standard size
    final List visas = book['visas'] ?? [];

    // Rule 1: Do we already have a page for this country?
    for (var visa in visas) {
      if (visa['cuisine'].toString().toLowerCase() == targetCuisine.toLowerCase()) {
        return null; // ✅ ALLOW: "Stamp Page 3 (Italian)."
      }
    }

    // Rule 2: Do we have a blank slot available?
    // 🛠 FIX: We subtract 1 to account for the physical Cover Page.
    if (visas.length < (maxCapacity - 1)) {
      return null; // ✅ ALLOW
    }
    
    // Rule 3: No room.
    return 'violation_full'; // 🛑 BLOCK: "Book is full."
  }

  @override
  int findTargetPageIndex(Map<String, dynamic> book, String targetCuisine) {
    final List visas = book['visas'] ?? [];

    // A. Look for existing page
    for (int i = 0; i < visas.length; i++) {
      if (visas[i]['cuisine'].toString().toLowerCase() == targetCuisine.toLowerCase()) {
        return i + 1; // Return existing index (1-based)
      }
    }

    // B. Claim the next blank slot
    // (e.g. If we have 2 visas, the next blank slot is #3)
    return visas.length + 1;
  }

  @override
  bool requiresNewVisaRow(Map<String, dynamic> book, String targetCuisine) {
    final List visas = book['visas'] ?? [];
    
    // Scan logic: If cuisine exists, we DON'T need a row. If it's new, we DO.
    for (var visa in visas) {
      if (visa['cuisine'].toString().toLowerCase() == targetCuisine.toLowerCase()) {
        return false;
      }
    }
    return true;
  }
}