import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 ADDED DIRECT DISK ACCESS
import 'visa_painters.dart';
import '../services/passport_service.dart';

class VisaDocument extends StatelessWidget {
  final String cuisine;
  final String userName;
  final String dateIssued;
  final Color mainColor;

  final String? photoUrl;
  final String? gender;
  final int? age;

  const VisaDocument({
    super.key,
    required this.cuisine,
    required this.userName,
    required this.dateIssued,
    required this.mainColor,
    this.photoUrl,
    this.gender,
    this.age,
  });

  // 🕵️‍♀️ BULLETPROOF DATA FETCHER
  Future<Map<String, dynamic>> _resolveProfile() async {
    // 1. Try Service Cache first
    var profile = await PassportService.fetchUserProfile();

    // 2. If Service failed or returned generic data, CHECK DISK DIRECTLY
    if (profile == null || (profile['display_name'] ?? '') == 'TRAVELER') {
      final prefs = await SharedPreferences.getInstance();
      final String? diskName = prefs.getString('guest_name');

      if (diskName != null && diskName.isNotEmpty) {
        // Found it on disk!
        return {
          'display_name': diskName,
          'age': prefs.getInt('guest_age') ?? 18,
          'gender': prefs.getString('guest_gender') ?? 'X',
          'photo_url': prefs.getString('guest_photo_local_path'),
        };
      }
    }

    return profile ?? {};
  }

  @override
  Widget build(BuildContext context) {
    // 1. Check if the parent gave us valid data
    bool hasValidParentData = (userName.isNotEmpty && userName != "TRAVELER");

    // 2. IF PARENT DATA IS GOOD: Render immediately
    if (hasValidParentData) {
      return _buildVisaContent(
        context,
        userName,
        photoUrl,
        gender ?? 'X',
        age ?? 0,
      );
    }

    // 3. IF PARENT DATA IS BAD: Hunt for it (Cache -> Disk)
    return FutureBuilder<Map<String, dynamic>>(
      future: _resolveProfile(), // 👈 Uses the new smart fetcher
      builder: (context, snapshot) {
        String finalName = "TRAVELER";
        String? finalPhoto = photoUrl;
        String finalGender = gender ?? 'X';
        int finalAge = age ?? 0;

        if (snapshot.hasData) {
          final data = snapshot.data!;
          final fetchedName = data['display_name'];

          // Only overwrite if we actually found something better
          if (fetchedName != null && fetchedName != "TRAVELER") {
            finalName = fetchedName;
            finalPhoto = data['photo_url'];
            finalGender = data['gender'] ?? 'X';
            finalAge = data['age'] ?? 0;
          }
        }

        return _buildVisaContent(
          context,
          finalName,
          finalPhoto,
          finalGender,
          finalAge,
        );
      },
    );
  }

  // 🎨 THE ACTUAL UI PAINTER
  Widget _buildVisaContent(
    BuildContext context,
    String name,
    String? photo,
    String sex,
    int ageVal,
  ) {
    final VisaTheme theme = VisaTheme.getTheme(cuisine, mainColor);

    // Safety Logic
    final String safeName = name.isEmpty ? "TRAVELER" : name;
    final String cleanName = safeName.replaceAll(' ', '<').toUpperCase();

    final String birthYear = (ageVal > 0)
        ? (DateTime.now().year - ageVal).toString().substring(2)
        : "99";

    // 🔠 Format Custom Genders for the visual document
    String displaySex = sex;
    if (displaySex == 'M' || displaySex == 'F') {
      displaySex = displaySex;
    } else if (displaySex.length >= 2) {
      displaySex =
          "${displaySex[0].toUpperCase()}${displaySex[1].toLowerCase()}"; // "Bisexual" -> "Bi"
    } else if (displaySex.length == 1) {
      displaySex = displaySex.toUpperCase();
    } else {
      displaySex = 'X'; // Failsafe
    }

    // Passports use standard single-character codes for the MRZ tracking line below the photo
    final String mrzSex = (displaySex == 'M' || displaySex == 'F')
        ? displaySex
        : "<";

    final String safeFirstChar = safeName.isNotEmpty
        ? safeName.substring(0, 1)
        : "X";
    final String mrzLine1 =
        "V<${theme.countryCode}$cleanName<<${'<' * (20 - cleanName.length)}";
    final String mrzLine2 =
        "${safeFirstChar}12345678${theme.countryCode}${birthYear}01014$mrzSex${'<' * 14}00";

    final bool hasPhoto = photo != null && photo.isNotEmpty;

    return RepaintBoundary(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          width: 380,
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFFFDFBF7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(2, 2),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                offset: const Offset(0, 8),
                blurRadius: 16,
              ),
              BoxShadow(
                color: theme.primaryColor.withOpacity(0.05),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // PAINTERS LAYER
              Positioned.fill(
                child: CustomPaint(
                  painter: UniversalGuillochePainter(
                    color: theme.primaryColor.withOpacity(0.08),
                    secondaryColor: theme.secondaryColor.withOpacity(0.06),
                    batch: theme.batch,
                  ),
                ),
              ),
              Positioned(
                right: -30,
                top: 10,
                child: Opacity(
                  opacity: 0.08,
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: CustomPaint(
                      painter: BatchSymbolPainter(
                        batch: theme.batch,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: Container(color: Colors.white.withOpacity(0.10)),
                  ),
                ),
              ),

              // CONTENT LAYER
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18.0,
                  vertical: 16.0,
                ),
                child: Column(
                  children: [
                    // HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 🛠 FIX: Wrap the left side in Expanded so it yields to the badge
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.stars,
                                size: 14,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "VISA / ${theme.countryName.toUpperCase()}",
                                  maxLines: 1,
                                  overflow: TextOverflow
                                      .ellipsis, // 👈 Gracefully adds "..." if it hits the badge
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: theme.primaryColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 12,
                        ), // Adds a tiny buffer between the text and the badge
                        // The Right Badge (Remains perfectly intact and sized)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.primaryColor,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cuisine.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // BODY
                    Expanded(
                      child: Row(
                        children: [
                          // 📷 PHOTO BOX
                          Container(
                            width: 75,
                            height: 100,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: theme.primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: hasPhoto
                                ? (photo.startsWith('/')
                                      ? Image.file(
                                          File(photo),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Center(
                                                  child: Icon(
                                                    Icons.person,
                                                    color: theme.primaryColor
                                                        .withOpacity(0.2),
                                                  ),
                                                );
                                              },
                                        )
                                      : Image.network(
                                          photo,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Center(
                                                  child: Icon(
                                                    Icons.person,
                                                    color: theme.primaryColor
                                                        .withOpacity(0.2),
                                                  ),
                                                );
                                              },
                                        ))
                                : Center(
                                    child: Icon(
                                      Icons.person,
                                      color: theme.primaryColor.withOpacity(
                                        0.2,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 18),

                          // 📝 INFO COLUMNS
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(
                                  "Surname / Nom",
                                  theme.primaryColor,
                                ),
                                Text(
                                  safeName.split(' ').last.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier',
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _buildLabel(
                                  "Given Names / Prénoms",
                                  theme.primaryColor,
                                ),
                                Text(
                                  safeName.split(' ').first.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier',
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel("Sex", theme.primaryColor),
                                        Text(
                                          displaySex,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            fontFamily: 'Courier',
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 20),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel("Age", theme.primaryColor),
                                        Text(
                                          ageVal > 0 ? ageVal.toString() : '--',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            fontFamily: 'Courier',
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 20),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel(
                                          "Issued",
                                          theme.primaryColor,
                                        ),
                                        Text(
                                          dateIssued,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                            fontFamily: 'Courier',
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // FOOTER MRZ
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(
                          height: 1,
                          thickness: 0.5,
                          color: Colors.black26,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mrzLine1,
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            height: 1.1,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          mrzLine2,
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            height: 1.1,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 7,
        color: color.withOpacity(0.8),
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
