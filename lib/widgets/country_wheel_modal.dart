import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'animated_cuisine_placeholder.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/telemetry_service.dart'; // Add this near your other imports

class CountryWheelModal extends StatefulWidget {
  final bool isDarkMode;
  final List<String> availableCuisines;
  final Function(String) onCountrySelected;

  const CountryWheelModal({
    super.key,
    required this.isDarkMode,
    required this.availableCuisines,
    required this.onCountrySelected,
  });

  @override
  State<CountryWheelModal> createState() => _CountryWheelModalState();
}

class _CountryWheelModalState extends State<CountryWheelModal>
    with TickerProviderStateMixin {
  late FixedExtentScrollController _scrollController;
  bool _isSpinning = false;
  bool _showWinner = false;
  String? _winnerCountry;
  int _lastTickIndex = 0;

  // 1. Search Overrides (Keyword for Database Search)
  final Map<String, String> _cuisineOverrides = {
    'united_arab_emirates': 'Emirati',
    'saudi_arabia': 'Saudi',
    'qatar': 'Qatari',
    'oman': 'Omani',
    'kuwait': 'Kuwaiti',
    'bahrain': 'Bahraini',
    'jordan': 'Jordanian',
    'syria': 'Syrian',
    'iraq': 'Iraqi',
    'yemen': 'Yemeni',
    'palestine': 'Palestinian',
    'israel': 'Israeli',
    'iran': 'Persian',
    'cyprus': 'Cypriot',
    'somalia': 'Somali',
    'egypt': 'Egyptian',
    'morocco': 'Moroccan',
    'algeria': 'Algerian',
    'tunisia': 'Tunisian',
    'libya': 'Libyan',
    'sudan': 'Sudanese',
    'ethiopia': 'Ethiopian',
    'nigeria': 'Nigerian',
    'ghana': 'Ghanaian',
    'senegal': 'Senegalese',
    'kenya': 'Kenyan',
    'south_africa': 'South African',
    'usa': 'American',
    'america': 'American',
    'united_states': 'American',
    'mexico': 'Mexican',
    'brazil': 'Brazilian',
    'argentina': 'Argentinian',
    'peru': 'Peruvian',
    'colombia': 'Colombian',
    'venezuela': 'Venezuelan',
    'cuba': 'Cuban',
    'jamaica': 'Jamaican',
    'canada': 'Canadian',
    'chile': 'Chilean',
    'china': 'Chinese',
    'japan': 'Japanese',
    'korea': 'Korean',
    'south_korea': 'Korean',
    'india': 'Indian',
    'thailand': 'Thai',
    'vietnam': 'Vietnamese',
    'philippines': 'Filipino',
    'malaysia': 'Malaysian',
    'indonesia': 'Indonesian',
    'pakistan': 'Pakistani',
    'bangladesh': 'Bangladeshi',
    'nepal': 'Nepalese',
    'sri_lanka': 'Sri Lankan',
    'afghanistan': 'Afghan',
    'australia': 'Australian',
    'new_zealand': 'New Zealand',
    'uk': 'British',
    'great_britain': 'British',
    'england': 'British',
    'ireland': 'Irish',
    'france': 'French',
    'italy': 'Italian',
    'germany': 'German',
    'spain': 'Spanish',
    'greece': 'Greek',
    'turkey': 'Turkish',
    'portugal': 'Portuguese',
    'poland': 'Polish',
    'russia': 'Russian',
    'ukraine': 'Ukrainian',
    'sweden': 'Swedish',
    'norway': 'Norwegian',
    'denmark': 'Danish',
    'netherlands': 'Dutch',
    'belgium': 'Belgian',
    'switzerland': 'Swiss',
    'austria': 'Austrian',
    'hungary': 'Hungarian',
  };

  // 🌟 2. NEW: Display Name Overrides (Visual "We're going to...")
  // Maps adjectives back to Country Nouns
  final Map<String, String> _countryDisplayNames = {
    'afghan': 'Afghanistan',
    'albanian': 'Albania',
    'algerian': 'Algeria',
    'american': 'The USA',
    'argentinian': 'Argentina',
    'armenian': 'Armenia',
    'australian': 'Australia',
    'austrian': 'Austria',
    'bangladeshi': 'Bangladesh',
    'belgian': 'Belgium',
    'brazilian': 'Brazil',
    'british': 'The UK',
    'burmese': 'Myanmar',
    'cambodian': 'Cambodia',
    'canadian': 'Canada',
    'chilean': 'Chile',
    'chinese': 'China',
    'colombian': 'Colombia',
    'cuban': 'Cuba',
    'czech_republic': 'Czech Republic',
    'dominican': 'Dominican Republic',
    'ecuadorian': 'Ecuador',
    'egyptian': 'Egypt',
    'emirati': 'The UAE',
    'ethiopian': 'Ethiopia',
    'filipino': 'The Philippines',
    'french': 'France',
    'georgian': 'Georgia',
    'german': 'Germany',
    'ghanaian': 'Ghana',
    'greek': 'Greece',
    'guatemalan': 'Guatemala',
    'guyanese': 'Guyana',
    'haitian': 'Haiti',
    'honduran': 'Honduras',
    'indian': 'India',
    'indonesian': 'Indonesia',
    'iranian': 'Iran',
    'iraqi': 'Iraq',
    'irish': 'Ireland',
    'israeli': 'Israel',
    'italian': 'Italy',
    'jamaican': 'Jamaica',
    'japanese': 'Japan',
    'jordanian': 'Jordan',
    'kenyan': 'Kenya',
    'korean': 'Korea',
    'lebanese': 'Lebanon',
    'malaysian': 'Malaysia',
    'mexican': 'Mexico',
    'moroccan': 'Morocco',
    'nepalese': 'Nepal',
    'nigerian': 'Nigeria',
    'pakistani': 'Pakistan',
    'palestinian': 'Palestine',
    'peruvian': 'Peru',
    'polish': 'Poland',
    'portuguese': 'Portugal',
    'puerto_rican': 'Puerto Rico',
    'romanian': 'Romania',
    'russian': 'Russia',
    'saudi': 'Saudi Arabia',
    'senegalese': 'Senegal',
    'spanish': 'Spain',
    'sri_lankan': 'Sri Lanka',
    'sudanese': 'Sudan',
    'swedish': 'Sweden',
    'swiss': 'Switzerland',
    'syrian': 'Syria',
    'taiwanese': 'Taiwan',
    'thai': 'Thailand',
    'turkish': 'Turkey',
    'ukrainian': 'Ukraine',
    'uruguayan': 'Uruguay',
    'venezuelan': 'Venezuela',
    'vietnamese': 'Vietnam',
    'yemeni': 'Yemen',
  };

  // Full Asset List
  final List<String> _allCountries = [
    'READY?',
    'afghan',
    'albanian',
    'algerian',
    'andorra',
    'angola',
    'antigua_and_barbuda',
    'argentinian',
    'armenian',
    'australian',
    'austrian',
    'azerbaijan',
    'bahamas',
    'bahrain',
    'bangladeshi',
    'barbados',
    'belarus',
    'belgian',
    'belize',
    'benin',
    'bhutan',
    'bolivia',
    'bosnia_and_herzegovina',
    'botswana',
    'brazilian',
    'brunei',
    'bulgaria',
    'burkina_faso',
    'burmese',
    'burundi',
    'cabo_verde',
    'cambodian',
    'cameroon',
    'canadian',
    'central_african_republic',
    'chad',
    'chilean',
    'chinese',
    'colombian',
    'comoros',
    'congo',
    'costa_rica',
    'croatia',
    'cuban',
    'cyprus',
    'czech_republic',
    'denmark',
    'djibouti',
    'dominica',
    'dominican',
    'east_timor',
    'ecuadorian',
    'egyptian',
    'el_salvador',
    'equatorial_guinea',
    'eritrea',
    'estonia',
    'ethiopian',
    'fiji',
    'finland',
    'french',
    'gabon',
    'gambia',
    'georgian',
    'german',
    'ghana',
    'greek',
    'grenada',
    'guatemalan',
    'guinea',
    'guinea_bissau',
    'guyanese',
    'haitian',
    'honduran',
    'hungary',
    'iceland',
    'indian',
    'indonesian',
    'iran',
    'iraq',
    'irish',
    'israeli',
    'italian',
    'ivory_coast',
    'jamaican',
    'japanese',
    'jordan',
    'kazakhstan',
    'kenya',
    'kiribati',
    'korean',
    'kosovo',
    'kuwait',
    'kyrgyzstan',
    'laos',
    'latvia',
    'lebanese',
    'lesotho',
    'liberia',
    'libya',
    'liechtenstein',
    'lithuania',
    'luxembourg',
    'madagascar',
    'malawi',
    'malaysian',
    'maldives',
    'mali',
    'malta',
    'marshall_islands',
    'mauritania',
    'mauritius',
    'mexican',
    'micronesia',
    'moldova',
    'monaco',
    'mongolia',
    'montenegro',
    'moroccan',
    'mozambique',
    'myanmar',
    'namibia',
    'nauru',
    'nepalese',
    'netherlands',
    'new_zealand',
    'nicaragua',
    'niger',
    'nigerian',
    'north_macedonia',
    'norway',
    'oman',
    'pakistani',
    'palau',
    'palestine',
    'panama',
    'papua_new_guinea',
    'paraguay',
    'peruvian',
    'filipino',
    'polish',
    'portuguese',
    'puerto_rican',
    'qatar',
    'romanian',
    'russian',
    'rwanda',
    'saint_kitts_and_nevis',
    'saint_lucia',
    'saint_vincent',
    'samoa',
    'san_marino',
    'sao_tome_and_principe',
    'saudi_arabia',
    'senegalese',
    'serbia',
    'seychelles',
    'sierra_leone',
    'singapore',
    'slovakia',
    'slovenia',
    'solomon_islands',
    'somalia',
    'south_africa',
    'south_sudan',
    'spanish',
    'sri_lankan',
    'sudan',
    'suriname',
    'sweden',
    'swiss',
    'syria',
    'taiwanese',
    'tajik',
    'tanzania',
    'thai',
    'togo',
    'tonga',
    'trinidadian',
    'tunisia',
    'turkish',
    'turkmenistan',
    'tuvalu',
    'uganda',
    'ukrainian',
    'united_arab_emirates',
    'british',
    'american',
    'uruguayan',
    'uzbek',
    'vanuatu',
    'vatican_city',
    'venezuelan',
    'vietnamese',
    'yemeni',
    'zambia',
    'zimbabwe',
  ];

  late List<String> _activeCountries;

  // Search Name Helper
  String _getSearchName(String key) {
    if (_cuisineOverrides.containsKey(key)) {
      return _cuisineOverrides[key]!;
    }
    return _formatName(key);
  }

  // 🌟 3. NEW: Display Name Helper (for the Overlay)
  String _getDisplayName(String key) {
    // Check specific display override first (e.g. 'cuban' -> 'Cuba')
    if (_countryDisplayNames.containsKey(key.toLowerCase())) {
      return _countryDisplayNames[key.toLowerCase()]!;
    }
    // Check if it was in the Search overrides (e.g. 'usa' -> 'American'),
    // though usually we want the key formatted if it's already a noun.

    // Default: Just format the key (e.g. 'zimbabwe' -> 'Zimbabwe')
    return _formatName(key);
  }

  String _formatName(String raw) {
    if (raw == 'READY?') return raw;
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
        .join(' ');
  }

  @override
  void initState() {
    super.initState();

    final availableSet = widget.availableCuisines
        .map((c) => c.toLowerCase().trim())
        .toSet();

    _activeCountries = _allCountries.where((key) {
      if (key == 'READY?') return true;
      final searchName = _getSearchName(key).toLowerCase();
      return availableSet.any(
        (avail) => avail.contains(searchName) || searchName.contains(avail),
      );
    }).toList();

    if (_activeCountries.length <= 1) {
      _activeCountries = List.from(_allCountries);
    }

    int infiniteStart = _activeCountries.length * 50;
    _scrollController = FixedExtentScrollController(initialItem: infiniteStart);

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      int currentTick = _scrollController.selectedItem;
      if (currentTick != _lastTickIndex) {
        _lastTickIndex = currentTick;
        if (_isSpinning) {
          SystemSound.play(SystemSoundType.click);
          HapticFeedback.lightImpact();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _spinTheWheel() {
    if (_isSpinning) return;

    // 📡 TELEMETRY: The user has committed to a random spin
    TelemetryService.logInteraction(actionType: 'wheel_spin_started');

    setState(() {
      _isSpinning = true;
      _showWinner = false;
    });

    // ... rest of your existing code ...

    final random = Random();
    int randomTarget = random.nextInt(_activeCountries.length - 1) + 1;

    final currentItem = _scrollController.selectedItem;
    final targetIndex =
        currentItem +
        (_activeCountries.length * 5) +
        (randomTarget - (currentItem % _activeCountries.length));

    _scrollController
        .animateToItem(
          targetIndex,
          duration: const Duration(seconds: 5),
          curve: Curves.fastLinearToSlowEaseIn,
        )
        .then((_) {
          final actualIndex = targetIndex % _activeCountries.length;
          _announceWinner(_activeCountries[actualIndex]);
        });
  }

  void _announceWinner(String country) async {
    HapticFeedback.heavyImpact();

    try {
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/tada.mp3'));
    } catch (e) {
      debugPrint("Audio error: $e");
    }

    // 📡 TELEMETRY: Log what the wheel actually landed on
    TelemetryService.logInteraction(
      actionType: 'wheel_result_shown',
      metadata: {
        'country_key': country,
        'search_target': _getSearchName(country),
      },
    );

    setState(() {
      // ... rest of your existing code ...
      _isSpinning = false;
      _showWinner = true;
      _winnerCountry = country;
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pop(context);
        // Returns the SEARCHABLE cuisine name
        widget.onCountrySelected(_getSearchName(country));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // THE WHEEL
          Column(
            children: [
              const SizedBox(height: 20),
              Text(
                "Where to next?",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  controller: _scrollController,
                  itemExtent: 60,
                  perspective: 0.003,
                  physics: _isSpinning
                      ? const NeverScrollableScrollPhysics()
                      : const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    if (!_isSpinning) HapticFeedback.selectionClick();
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: _activeCountries.length * 1000,
                    builder: (context, index) {
                      final countryKey =
                          _activeCountries[index % _activeCountries.length];
                      return Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode
                                ? Colors.white.withOpacity(0.9)
                                : Colors.black.withOpacity(0.9),
                          ),
                          child: Text(_formatName(countryKey)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),

          // THE HIGHLIGHT BAR
          Positioned(
            top: 250,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: widget.isDarkMode ? Colors.white24 : Colors.black12,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  color: widget.isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
            ),
          ),

          // SPIN BUTTON
          if (!_isSpinning && !_showWinner)
            Positioned(
              bottom: 50,
              child: SizedBox(
                width: 220,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _spinTheWheel,
                  icon: const Icon(Icons.casino, size: 28),
                  label: const Text(
                    "SPIN",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isDarkMode
                        ? Colors.white
                        : Colors.black,
                    foregroundColor: widget.isDarkMode
                        ? Colors.black
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                ),
              ),
            ),

          // WINNER OVERLAY
          if (_showWinner && _winnerCountry != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: Container(
                  color: Colors.black87,
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: 320,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: widget.isDarkMode
                                  ? const Color(0xFF303030)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    height: 140,
                                    width: double.infinity,
                                    child: AnimatedCuisinePlaceholder(
                                      cuisine: _winnerCountry!,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "We're going to...",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontStyle: FontStyle.italic,
                                    color: widget.isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  // 🌟 4. USE DISPLAY NAME HERE
                                  _getDisplayName(_winnerCountry!),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: widget.isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          // CONFETTI
          if (_showWinner) const Positioned.fill(child: _SimpleConfetti()),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 🎊 CONFETTI WIDGETS (Add these to the bottom of the file)
// -----------------------------------------------------------------------------

class _SimpleConfetti extends StatefulWidget {
  const _SimpleConfetti();
  @override
  State<_SimpleConfetti> createState() => _SimpleConfettiState();
}

class _SimpleConfettiState extends State<_SimpleConfetti>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() {
        for (var p in _particles) {
          p.y += p.speed;
          p.x += sin(p.y / 50) * 2;
          p.rotation += 0.1;
        }
      });
    });

    for (int i = 0; i < 80; i++) {
      _particles.add(
        _ConfettiParticle(
          x: _random.nextDouble() * 400,
          y: -_random.nextDouble() * 600,
          color: Colors.primaries[_random.nextInt(Colors.primaries.length)],
          size: 5 + _random.nextDouble() * 10,
          speed: 3 + _random.nextDouble() * 8,
        ),
      );
    }
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ConfettiPainter(_particles),
      size: Size.infinite,
    );
  }
}

class _ConfettiParticle {
  double x, y, size, speed, rotation = 0;
  Color color;
  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.speed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()..color = p.color;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
