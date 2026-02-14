import 'passport_rules.dart';

class SingleVisaRules implements PassportRules {
  @override
  String? validateStampAttempt(Map<String, dynamic> book, String targetCuisine) {
    final List visas = book['visas'] ?? [];

    // Rule 1: If empty, we welcome everyone.
    if (visas.isEmpty) return null;

    // Rule 2: If occupied, we ONLY welcome the same country.
    // (Strict Monogamy)
    final String existingCuisine = visas.first['cuisine'];
    if (existingCuisine.toLowerCase() != targetCuisine.toLowerCase()) {
      return 'violation_monogamy'; // 🛑 BLOCK: "You are married to India, you cannot date Japan."
    }

    return null; // ✅ ALLOW: "Welcome back."
  }

  @override
  int findTargetPageIndex(Map<String, dynamic> book, String targetCuisine) {
    // 🛠 FIX: For a single page book, the target is ALWAYS index 0.
    // This prevents the "Flip away" behavior.
    return 0; 
  }

  @override
  bool requiresNewVisaRow(Map<String, dynamic> book, String targetCuisine) {
    // Only write a row if the book is currently empty.
    final List visas = book['visas'] ?? [];
    return visas.isEmpty;
  }
}