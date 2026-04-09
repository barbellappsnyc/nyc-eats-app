import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelerNoteDialog {
  /// Checks SharedPreferences and shows the manifesto if necessary.
  /// The [onDismiss] callback triggers when the user closes the dialog, 
  /// or immediately if they have already opted out of seeing it.
  static Future<void> showIfNeeded(BuildContext context, {required VoidCallback onDismiss}) async {
    final prefs = await SharedPreferences.getInstance();
    final bool showNote = prefs.getBool('show_traveler_note') ?? true;

    if (!showNote) {
      onDismiss();
      return;
    }

    bool doNotShowAgain = true; // Default state is ON

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false, // Forces use of the 'X' button
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
                      // ❌ TOP LEFT CROSS BUTTON
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFFF5F5F5),
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),

                      // 📜 THE CONTENT
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(), // 👈 Prevents the iPad 'forehead' bug
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "A Note to the Travelers",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'AppleGaramond',
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF5F5F5),
                                ),
                              ),
                              const SizedBox(height: 24),

                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontFamily: 'AppleGaramond',
                                    fontStyle: FontStyle.italic,
                                    fontSize: 18, 
                                    color: Color(0xFFE0E0E0),
                                    height: 1.5,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: "    No subscriptions in this app. And no ads. I, too, am tired of apps charging \$4.99 a month until eternity to make the ads go away, or locking basic functionalities behind the infamous paywall. The core functionality of this app: exploring the 36,000+ restaurants across New York City will be free. I, personally, love New York City, and this is a service that I would like to do for the lovely people inhabiting it.\n\n"
                                      "    Collecting the visas and the immigration stamps for the restaurants will also be free, but will be limited to a maximum of 4 in the Wild Card Visa page. If the Travelers wish, they can purchase a new Passport, and they will own it forever. No hidden charges, no other BS. Just how a real passport would work (excluding, of course, the boring formalities). The visas and the stamps, too, are yours forever; a memoir of your explorations.\n\n"
                                      "    So, share your passport cards with the world and with us (tag us ",
                                    ),
                                    TextSpan(
                                      text: "@gourmetpassports",
                                      style: const TextStyle(
                                        decoration: TextDecoration.underline,
                                        color: Colors.amber,
                                      ),
                                      recognizer: TapGestureRecognizer()..onTap = () {
                                        launchUrl(
                                          Uri.parse('https://www.instagram.com/gourmetpassports/'),
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                    ),
                                    const TextSpan(
                                      text: " if you’d like!). Bon Appétit, and Happy Journey!\n\n"
                                      "    – With love,\n"
                                      "    Barbell Apps",
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // ✅ "DO NOT SHOW AGAIN" CHECKBOX
                              GestureDetector(
                                onTap: () {
                                  setDialogState(() => doNotShowAgain = !doNotShowAgain);
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
                                          setDialogState(() => doNotShowAgain = val ?? true);
                                        },
                                        activeColor: Colors.white,
                                        checkColor: Colors.black,
                                        side: const BorderSide(color: Colors.white54),
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

    // 💾 Save the preference once the dialog is closed
    await prefs.setBool('show_traveler_note', !doNotShowAgain);
    
    // 🚪 Trigger the action
    onDismiss();
  }
}