abstract class PassportRules {
  /// 1. CHECKER: Can this book accept the stamp?
  /// Returns NULL if allowed.
  /// Returns a String error code if blocked (e.g., 'violation_monogamy', 'violation_full').
  String? validateStampAttempt(Map<String, dynamic> book, String targetCuisine);

  /// 2. FINDER: Where should the stamp go?
  /// Returns the Page Index (1-based) where this stamp belongs.
  /// If it returns a number > current visas count, it implies claiming a new slot.
  int findTargetPageIndex(Map<String, dynamic> book, String targetCuisine);
  
  /// 3. CLAIMER: Do we need to write a NEW Visa row to the DB?
  /// (True = We are claiming a blank slot. False = We are stamping an existing page).
  bool requiresNewVisaRow(Map<String, dynamic> book, String targetCuisine);
}