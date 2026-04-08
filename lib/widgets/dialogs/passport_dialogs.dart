import 'package:flutter/material.dart';
import 'dart:ui';

class PassportDialogs {
  // ---------------------------------------------------------------------------
  // 1. 🚦 SWITCH CONFIRMATION (The New Logic)
  // ---------------------------------------------------------------------------
  static Future<bool> showSwitchConfirmation({
    required BuildContext context,
    required String targetBookName, // e.g., "Standard Passport"
    required String reason, // e.g., "Found existing Japanese Visa"
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildBaseDialog(
            icon: Icons.swap_horiz_rounded,
            iconColor: const Color(0xFF1A237E), // Navy
            title: "SWITCH REQUIRED",
            body: "$reason\n\nSwitch to your $targetBookName to continue?",
            confirmText: "SWITCH & STAMP",
            cancelText: "CANCEL",
            onConfirm: () => Navigator.pop(context, true),
            onCancel: () => Navigator.pop(context, false),
          ),
        ) ??
        false;
  }

  // ---------------------------------------------------------------------------
  // 2. 🛂 VISA APPLICATION (From Single/Standard Rules)
  // ---------------------------------------------------------------------------
  static Future<bool> showVisaApplication({
    required BuildContext context,
    required String cuisine,
    required String restaurantName,
  }) async {
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
                child: _buildBaseDialog(
                  icon: Icons.policy,
                  iconColor: const Color(0xFF1A237E),
                  title: "VISA REQUIRED",
                  body:
                      "Entry to '$restaurantName' requires an official $cuisine Visa.\n\nDo you wish to issue this travel document?",
                  confirmText: "ISSUE VISA",
                  cancelText: "DECLINE",
                  onConfirm: () => Navigator.pop(context, true),
                  onCancel: () => Navigator.pop(context, false),
                ),
              ),
            );
          },
        ) ??
        false;
  }

  // ---------------------------------------------------------------------------
  // 3. 👯 DUPLICATE CHECK (The "Double Dip")
  // ---------------------------------------------------------------------------
  static Future<bool> showDuplicateWarning({
    required BuildContext context,
    required String restaurantName,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildBaseDialog(
            icon: Icons.history,
            iconColor: const Color(0xFFD32F2F), // Red
            iconBgColor: const Color(0xFFFFF0F0),
            title: "ALREADY STAMPED!",
            body:
                "You've already got a stamp for\n'$restaurantName'.\n\nWant to double dip?",
            confirmText: "YEP, STAMP IT!",
            cancelText: "NAH, CANCEL",
            confirmColor: const Color(0xFFD32F2F),
            onConfirm: () => Navigator.pop(context, true),
            onCancel: () => Navigator.pop(context, false),
          ),
        ) ??
        false;
  }

  // ---------------------------------------------------------------------------
  // 4. ➕ EXTENSION (Page Full)
  // ---------------------------------------------------------------------------
  static Future<bool> showExtensionDialog({
    required BuildContext context,
    required String cuisine,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildBaseDialog(
            icon: Icons.add_to_photos_rounded,
            iconColor: const Color(0xFF1A237E),
            title: "PAGE FULL!",
            body:
                "Your $cuisine Visa is completely filled.\n\nAdd a fresh page to keep collecting?",
            confirmText: "ADD PAGE",
            cancelText: "NO THANKS",
            onConfirm: () => Navigator.pop(context, true),
            onCancel: () => Navigator.pop(context, false),
          ),
        ) ??
        false;
  }

  // ---------------------------------------------------------------------------
  // 5. 🔒 VIOLATION / UPGRADE (Single Visa Limit / Full Book)
  // ---------------------------------------------------------------------------
  static Future<bool> showUpgradeDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildBaseDialog(
            icon: Icons.lock_clock,
            iconColor: Colors.orange[900]!,
            iconBgColor: Colors.orange[50],
            title: title,
            body: message,
            confirmText: "UPGRADE PASSPORT",
            cancelText: "CANCEL",
            onConfirm: () => Navigator.pop(context, true),
            onCancel: () => Navigator.pop(context, false),
          ),
        ) ??
        false;
  }

  // ===========================================================================
  // 🎨 INTERNAL UI BUILDER (Keeps styling consistent)
  // ===========================================================================
  static Widget _buildBaseDialog({
    required IconData icon,
    required Color iconColor,
    Color? iconBgColor,
    required String title,
    required String body,
    required String confirmText,
    required String cancelText,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
    Color? confirmColor,
  }) {
    return Dialog(
      backgroundColor: const Color(0xFFFFFDF7), // Cream Paper
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconBgColor ?? iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: iconColor),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Body
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      cancelText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor ?? const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
