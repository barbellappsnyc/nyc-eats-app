import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math';
import 'dart:ui' as ui;

// --- 1. THEME DATA ---
class CuisineTheme {
  final List<Color> colors;
  final List<String> emojis;
  final Color textColor;

  const CuisineTheme({
    required this.colors,
    required this.emojis,
    this.textColor = Colors.white,
  });
}

  final Map<String, CuisineTheme> _cuisineThemes = {
    // --- 🇺🇸 AMERICANA & COMFORT ---
    'american': CuisineTheme(
      colors: [Color(0xFFB22234), Color(0xFFFFFFFF), Color(0xFF3C3B6E)],
      emojis: ['🍔', '🍟', '🍕', '🍩', '🥤', '🌭', '🥓', '🦅', '🇺🇸'],
    ),
    'diner': CuisineTheme(
      colors: [Color(0xFFE0E0E0), Color(0xFFEF3B36), Color(0xFF4776E6)], 
      emojis: ['🥞', '🍳', '🥓', '☕', '🍔', '🍦', '🍒', '🇺🇸'],
    ),
    'soul_food': CuisineTheme(
      colors: [Color(0xFFD35400), Color(0xFFF39C12)], 
      emojis: ['🍗', '🌽', '🍞', '🥬', '🍠', '🧀', '🇺🇸'],
    ),
    'soul': CuisineTheme( 
      colors: [Color(0xFFD35400), Color(0xFFF39C12)],
      emojis: ['🍗', '🌽', '🍞', '🥬', '🍠', '🧀', '🇺🇸'],
    ),
    'southern': CuisineTheme(
      colors: [Color(0xFFE67E22), Color(0xFFF1C40F)], 
      emojis: ['🍗', '🥧', '🌽', '🍞', '🍑', '🇺🇸'],
    ),
    'cajun': CuisineTheme(
      colors: [Color(0xFF800000), Color(0xFFFFCC00), Color(0xFF008000)], 
      emojis: ['🦐', '🍚', '🌽', '🦀', '🌶️', '🇺🇸'],
    ),
    'hot_dog': CuisineTheme(
      colors: [Color(0xFFF1C40F), Color(0xFFC0392B)], 
      emojis: ['🌭', '🥨', '🥤', '⚾', '🍟', '🇺🇸'],
    ),
    'corn_dog': CuisineTheme(
      colors: [Color(0xFFF39C12), Color(0xFFE67E22)], 
      emojis: ['🌭', '🌽', '🎪', '🍟', '🇺🇸'],
    ),
    'burger': CuisineTheme(
      colors: [Color(0xFFD4145A), Color(0xFFFBB03B)], 
      emojis: ['🍔', '🍟', '🥤', '🥓', '🧀', '🥩'],
    ),
    'steak': CuisineTheme(
      colors: [Color(0xFF434343), Color(0xFF000000)], 
      emojis: ['🥩', '🍖', '🍷', '🔥', '🥔', '🔪', '🧂'],
    ),
    'grill': CuisineTheme(
      colors: [Color(0xFF2C3E50), Color(0xFFE74C3C)], 
      emojis: ['🔥', '🥩', '🌽', '🍔', '🌭'],
    ),

    // --- 🌍 EUROPE ---
    'italian': CuisineTheme(
      colors: [Color(0xFF008C45), Color(0xFFF4F5F0), Color(0xFFCD212A)], 
      emojis: ['🍝', '🍕', '🍷', '🍅', '🧀', '🌿', '🥖', '🛵', '🇮🇹'],
    ),
    'pizza': CuisineTheme(
      colors: [Color(0xFFff9966), Color(0xFFff5e62)], 
      emojis: ['🍕', '🧀', '🍅', '🌿', '🔥', '🥤', '🇮🇹'],
    ),
    'french': CuisineTheme(
      colors: [Color(0xFF0055A4), Color(0xFFFFFFFF), Color(0xFFEF4135)],
      emojis: ['🥐', '🥖', '🍷', '🧀', '🥩', '🍇', '☕', '🗼', '🇫🇷'],
    ),
    'german': CuisineTheme(
      colors: [Color(0xFF000000), Color(0xFFDD0000), Color(0xFFFFCE00)], 
      emojis: ['🥨', '🍺', '🌭', '🥩', '🥔', '🥖', '🇩🇪'],
    ),
    'austrian': CuisineTheme(
      colors: [Color(0xFFED2939), Color(0xFFFFFFFF), Color(0xFFED2939)],
      emojis: ['🥩', '🍰', '🍺', '🥨', '☕', '🇦🇹'],
    ),
    'irish': CuisineTheme(
      colors: [Color(0xFF169B62), Color(0xFFFFFFFF), Color(0xFFFF883E)], 
      emojis: ['🍺', '🥔', '🍀', '🍲', '🍞', '🇮🇪'],
    ),
    'british': CuisineTheme(
      colors: [Color(0xFF00247D), Color(0xFFFFFFFF), Color(0xFFCF142B)], 
      emojis: ['🐟', '🍟', '🫖', '🥧', '🍺', '🇬🇧'],
    ),
    'fish_and_chips': CuisineTheme(
      colors: [Color(0xFF00247D), Color(0xFFF0F0F0)], 
      emojis: ['🐟', '🍟', '🍋', '🍺', '🧂', '🇬🇧'],
    ),
    'spanish': CuisineTheme(
      colors: [Color(0xFFAA151B), Color(0xFFF1BF00)], 
      emojis: ['🥘', '🍷', '🍇', '🧀', '💃', '🦐', '🇪🇸'],
    ),
    'tapas': CuisineTheme(
      colors: [Color(0xFFAA151B), Color(0xFFF1BF00)], 
      emojis: ['🍤', '🫒', '🧀', '🍷', '🍖', '🇪🇸'],
    ),
    'basque': CuisineTheme(
      colors: [Color(0xFFCF1920), Color(0xFF009246), Color(0xFFFFFFFF)], 
      emojis: ['🍖', '🍷', '🧀', '🐟', '🇪🇸'],
    ),
    'portuguese': CuisineTheme(
      colors: [Color(0xFF006600), Color(0xFFFF0000)], 
      emojis: ['🐟', '🍷', '🥖', '🥘', '🧁', '🇵🇹'],
    ),
    'greek': CuisineTheme(
      colors: [Color(0xFF0D5EAF), Color(0xFFFFFFFF)], 
      emojis: ['🥙', '🫒', '🍋', '🍇', '🧀', '🏺', '🐟', '🇬🇷'],
    ),
    'scandinavian': CuisineTheme(
      colors: [Color(0xFF005293), Color(0xFFFECB00)], 
      emojis: ['🐟', '🥖', '🥩', '🫐', '🥔', '🇸🇪', '🇳🇴'],
    ),
    'swiss': CuisineTheme(
      colors: [Color(0xFFFF0000), Color(0xFFFFFFFF)], 
      emojis: ['🧀', '🍫', '🫕', '⛰️', '🇨🇭'],
    ),
    'fondue': CuisineTheme(
      colors: [Color(0xFFFFD700), Color(0xFFFFA500)], 
      emojis: ['🫕', '🧀', '🥖', '🔥', '🇨🇭'],
    ),
    'belgian': CuisineTheme(
      colors: [Color(0xFF000000), Color(0xFFFFCD00), Color(0xFFC8102E)],
      emojis: ['🧇', '🍟', '🍫', '🍺', '🍪', '🇧🇪'],
    ),

    // --- 🇷🇺 EASTERN EUROPE ---
    'russian': CuisineTheme(
      colors: [Color(0xFFFFFFFF), Color(0xFF0039A6), Color(0xFFD52B1E)], 
      emojis: ['🥟', '🍲', '🥔', '🥞', '🍵', '🇷🇺'],
    ),
    'ukrainian': CuisineTheme(
      colors: [Color(0xFF0057B8), Color(0xFFFFD700)], 
      emojis: ['🥟', '🍲', '🍖', '🥖', '🌻', '🇺🇦'],
    ),
    'polish': CuisineTheme(
      colors: [Color(0xFFFFFFFF), Color(0xFFDC143C)], 
      emojis: ['🥟', '🌭', '🍲', '🥔', '🍩', '🇵🇱'],
    ),
    'georgian': CuisineTheme(
      colors: [Color(0xFFDA291C), Color(0xFFFFFFFF)], 
      emojis: ['🧀', '🥟', '🍷', '🥖', '🥩', '🇬🇪'],
    ),
    'eastern_european': CuisineTheme(
      colors: [Color(0xFF2C3E50), Color(0xFFBDC3C7)], 
      emojis: ['🥟', '🍲', '🥔', '🥩', '🍺'],
    ),
    'romanian': CuisineTheme(
      colors: [Color(0xFF002B7F), Color(0xFFFCD116), Color(0xFFCE1126)],
      emojis: ['🥩', '🍲', '🍷', '🥖', '🇷🇴'],
    ),
    'balkan': CuisineTheme(
      colors: [Color(0xFF003893), Color(0xFFFCD116)], 
      emojis: ['🥩', '🥙', '🥗', '🥖'],
    ),

    // --- 🌏 ASIA ---
    'japanese': CuisineTheme(
      colors: [Color(0xFFF0F0F0), Color(0xFFBC002D)], 
      emojis: ['🍣', '🍜', '🍱', '🍙', '🥢', '🍵', '🍤', '🎋', '🇯🇵'],
      textColor: Colors.black87, 
    ),
    'sushi': CuisineTheme(
      colors: [Color(0xFF243949), Color(0xFF517fa4)], 
      emojis: ['🍣', '🍱', '🍤', '🥢', '🐟', '🍚', '🇯🇵'],
    ),
    'ramen': CuisineTheme(
      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], 
      emojis: ['🍜', '🥚', '🥩', '🥢', '🍥', '🔥', '🇯🇵'],
    ),
    'korean': CuisineTheme(
      colors: [Color(0xFFFFFFFF), Color(0xFFCD2E3A), Color(0xFF0047A0)], 
      emojis: ['🥩', '🍚', '🥢', '🥬', '🍲', '🔥', '🌶️', '🇰🇷'],
    ),
    'chinese': CuisineTheme(
      colors: [Color(0xFFDE2910), Color(0xFFFFDE00)], 
      emojis: ['🥟', '🍜', '🥢', '🥠', '🍚', '🦆', '🍵', '🏮', '🇨🇳'],
    ),
    'sichuan': CuisineTheme(
      colors: [Color(0xFFE42C2C), Color(0xFFF2994A)], 
      emojis: ['🌶️', '🍜', '🥘', '🥢', '🔥', '🇨🇳'],
    ),
    'dim_sum': CuisineTheme(
      colors: [Color(0xFFFFA07A), Color(0xFFFFFFFF)], 
      emojis: ['🥟', '🍵', '🥢', '🥠', '🍤', '🇨🇳'],
    ),
    'dumpling': CuisineTheme(
      colors: [Color(0xFFF5DEB3), Color(0xFFFFFFFF)], 
      emojis: ['🥟', '🥢', '🍲', '🍚'],
    ),
    'dumplings': CuisineTheme(
      colors: [Color(0xFFF5DEB3), Color(0xFFFFFFFF)], 
      emojis: ['🥟', '🥢', '🍲', '🍚'],
    ),
    'filipino': CuisineTheme(
      colors: [Color(0xFF0038A8), Color(0xFFCE1126), Color(0xFFFCD116)], 
      emojis: ['🍚', '🍗', '🍜', '🥭', '🍦', '🐷', '🇵🇭'],
    ),
    'thai': CuisineTheme(
      colors: [Color(0xFFED1C24), Color(0xFFFFFFFF), Color(0xFF241D4F), Color(0xFFED1C24)],
      emojis: ['🍜', '🌶️', '🥥', '🍤', '🍋', '🥜', '🐘', '🇹🇭'],
    ),
    'vietnamese': CuisineTheme(
      colors: [Color(0xFFDA251D), Color(0xFFFFFF00)], 
      emojis: ['🍜', '🥖', '🌿', '🍤', '☕', '🥢', '🇻🇳'],
    ),
    'indian': CuisineTheme(
      colors: [Color(0xFFFF9933), Color(0xFFFFFFFF), Color(0xFF138808)], 
      emojis: ['🍛', '🫓', '🍚', '🌶️', '🥘', '🍲', '🥔', '🛺', '🇮🇳'],
    ),
    'pakistani': CuisineTheme(
      colors: [Color(0xFF01411C), Color(0xFFFFFFFF)], 
      emojis: ['🍛', '🍚', '🍖', '🌶️', '🫓', '🇵🇰'],
    ),
    'sri_lankan': CuisineTheme(
      colors: [Color(0xFF8D153A), Color(0xFFF7B718), Color(0xFF005F56)], 
      emojis: ['🍚', '🥥', '🐟', '🌶️', '🍵', '🇱🇰'],
    ),
    'nepalese': CuisineTheme(
      colors: [Color(0xFFDC143C), Color(0xFF00008B)], 
      emojis: ['🥟', '🍜', '🍚', '🏔️', '🇳🇵'],
    ),
    'himalayan': CuisineTheme(
      colors: [Color(0xFF4CA1AF), Color(0xFFC4E0E5)], 
      emojis: ['🥟', '🍜', '🍵', '🏔️'],
    ),
    'tibetan': CuisineTheme(
      colors: [Color(0xFF8B0000), Color(0xFFFFD700)], 
      emojis: ['🥟', '🍜', '🍵', '🧘'],
    ),
    'burmese': CuisineTheme(
      colors: [Color(0xFFFECB00), Color(0xFF34B233), Color(0xFFEA2839)], 
      emojis: ['🍜', '🍚', '🍵', '🍋', '🇲🇲'],
    ),
    'cambodian': CuisineTheme(
      colors: [Color(0xFF032EA1), Color(0xFFE00025)], 
      emojis: ['🍲', '🍚', '🐟', '🥥', '🇰🇭'],
    ),
    'indonesian': CuisineTheme(
      colors: [Color(0xFFFF0000), Color(0xFFFFFFFF)], 
      emojis: ['🍚', '🍢', '🥜', '🌶️', '🇮🇩'],
    ),
    'malaysian': CuisineTheme(
      colors: [Color(0xFF010066), Color(0xFFF9D90F), Color(0xFFCC0000)], 
      emojis: ['🍜', '🍚', '🥥', '🌶️', '🍢', '🇲🇾'],
    ),
    'taiwanese': CuisineTheme(
      colors: [Color(0xFFFE0000), Color(0xFF000095), Color(0xFFFFFFFF)], 
      emojis: ['🧋', '🍜', '🥟', '🍚', '🇹🇼'],
    ),
    'uyghur': CuisineTheme(
      colors: [Color(0xFF65B5E5), Color(0xFFFFFFFF)], 
      emojis: ['🍜', '🥩', '🥙', '🍢'],
    ),
    'hotpot': CuisineTheme(
      colors: [Color(0xFFC33764), Color(0xFF1D2671)], 
      emojis: ['🍲', '🔥', '🥩', '🥬', '🥢', '🇨🇳'],
    ),

    // --- 🇦🇫 CENTRAL ASIA & MIDDLE EAST ---
    'afghan': CuisineTheme(
      colors: [Color(0xFF000000), Color(0xFFDA291C), Color(0xFF009900)],
      emojis: ['🍚', '🍖', '🍇', '🍞', '🥟', '🇦🇫'],
    ),
    'persian': CuisineTheme(
      colors: [Color(0xFF239F40), Color(0xFFFFFFFF), Color(0xFFDA0000)], 
      emojis: ['🍚', '🍖', '🍋', '🌿', '🥙', '🇮🇷'],
    ),
    'middle_eastern': CuisineTheme(
      colors: [Color(0xFFC2B280), Color(0xFF228B22)], 
      emojis: ['🥙', '🧆', '🍋', '🌿', '🍚', '🍖'],
    ),
    'lebanese': CuisineTheme(
      colors: [Color(0xFFED1C24), Color(0xFFFFFFFF), Color(0xFF00A651)],
      emojis: ['🥙', '🧆', '🍋', '🌿', '🍇', '🫒', '🇱🇧'],
    ),
    'israeli': CuisineTheme(
      colors: [Color(0xFF005EB8), Color(0xFFFFFFFF)], 
      emojis: ['🥙', '🧆', '🍋', '🥚', '🥯', '🇮🇱'],
    ),
    'yemeni': CuisineTheme(
      colors: [Color(0xFFCE1126), Color(0xFFFFFFFF), Color(0xFF000000)], 
      emojis: ['🍚', '🍖', '🥘', '☕', '🇾🇪'],
    ),
    'egyptian': CuisineTheme(
      colors: [Color(0xFFCE1126), Color(0xFFFFFFFF), Color(0xFF000000)], 
      emojis: ['🧆', '🍚', '🥙', '🥘', '🇪🇬'],
    ),
    'turkish': CuisineTheme(
      colors: [Color(0xFFE30A17), Color(0xFFFFFFFF)], 
      emojis: ['🥙', '🥩', '☕', '🫖', '🍇', '🥖', '🇹🇷'],
    ),
    'kebab': CuisineTheme(
      colors: [Color(0xFFC2B280), Color(0xFF228B22)], 
      emojis: ['🥙', '🥩', '🔥', '🍅', '🍚'],
    ),
    'doner': CuisineTheme(
      colors: [Color(0xFFC2B280), Color(0xFF228B22)], 
      emojis: ['🥙', '🥩', '🔥', '🥗'],
    ),
    'falafel': CuisineTheme(
      colors: [Color(0xFF56AB2F), Color(0xFFA8E063)], 
      emojis: ['🧆', '🥙', '🥗', '🍋'],
    ),
    'gyros': CuisineTheme(
      colors: [Color(0xFF0D5EAF), Color(0xFFFFFFFF)], 
      emojis: ['🥙', '🥩', '🍟', '🥗', '🇬🇷'],
    ),

    // --- 🌎 LATIN AMERICA & CARIBBEAN ---
    'brazilian': CuisineTheme(
      colors: [Color(0xFF009C3B), Color(0xFFFFDF00), Color(0xFF002776)], 
      emojis: ['🥩', '🍚', '🥥', '🍹', '🍖', '⚽', '🇧🇷'],
    ),
    'argentinian': CuisineTheme(
      colors: [Color(0xFF75AADB), Color(0xFFFFFFFF), Color(0xFF75AADB)],
      emojis: ['🥩', '🍷', '🥟', '🔥', '🌿', '🇦🇷'],
      textColor: Colors.black87, 
    ),
    'peruvian': CuisineTheme(
      colors: [Color(0xFFD91023), Color(0xFFFFFFFF), Color(0xFFD91023)],
      emojis: ['🥔', '🌽', '🐟', '🌶️', '🍗', '🍋', '🇵🇪'],
    ),
    'mexican': CuisineTheme(
      colors: [Color(0xFF006847), Color(0xFFFFFFFF), Color(0xFFCE1126)],
      emojis: ['🌮', '🌯', '🥑', '🌽', '🌶️', '🍹', '🥙', '🌵', '🇲🇽'],
    ),
    'tex-mex': CuisineTheme(
      colors: [Color(0xFFD35400), Color(0xFFF1C40F)], 
      emojis: ['🌮', '🧀', '🥩', '🌶️', '🌯', '🇺🇸', '🇲🇽'],
    ),
    'taco': CuisineTheme(
      colors: [Color(0xFFDce35b), Color(0xFF45b649)], 
      emojis: ['🌮', '🌶️', '🥑', '🍹', '🧀', '🌽', '🇲🇽'],
    ),
    'colombian': CuisineTheme(
      colors: [Color(0xFFFFCD00), Color(0xFF003087), Color(0xFFC8102E)], 
      emojis: ['☕', '🌽', '🥑', '🍖', '🥘', '🇨🇴'],
    ),
    'venezuelan': CuisineTheme(
      colors: [Color(0xFFFFCD00), Color(0xFF00247D), Color(0xFFCF142B)], 
      emojis: ['🫓', '🌽', '🥩', '🥑', '🧀', '🇻🇪'],
    ),
    'ecuadorian': CuisineTheme(
      colors: [Color(0xFFFFD100), Color(0xFF00338D), Color(0xFFEF3340)], 
      emojis: ['🍤', '🍌', '🍲', '🌽', '🥔', '🇪🇨'],
    ),
    'salvadoran': CuisineTheme(
      colors: [Color(0xFF0F47AF), Color(0xFFFFFFFF)], 
      emojis: ['🫓', '🧀', '🌽', '🥙', '🇸🇻'],
    ),
    'salvadorian': CuisineTheme(
      colors: [Color(0xFF0F47AF), Color(0xFFFFFFFF)], 
      emojis: ['🫓', '🧀', '🌽', '🥙', '🇸🇻'],
    ),
    'guatemalan': CuisineTheme(
      colors: [Color(0xFF4997D0), Color(0xFFFFFFFF)], 
      emojis: ['🌽', '🥑', '☕', '🍛', '🇬🇹'],
    ),
    'honduran': CuisineTheme(
      colors: [Color(0xFF0073CF), Color(0xFFFFFFFF)], 
      emojis: ['🍌', '🥥', '🌽', '🍛', '🇭🇳'],
    ),
    'uruguayan': CuisineTheme(
      colors: [Color(0xFF0038A8), Color(0xFFFFFFFF)], 
      emojis: ['🥩', '🍷', '🧉', '🥪', '🇺🇾'],
    ),
    'hispanic': CuisineTheme(
      colors: [Color(0xFFFF512F), Color(0xFFDD2476)], 
      emojis: ['🌮', '🌽', '🥑', '💃', '🍹'],
    ),
    'latin': CuisineTheme(
      colors: [Color(0xFFFF512F), Color(0xFFDD2476)], 
      emojis: ['🌮', '🌽', '🥑', '💃', '🍹'],
    ),

    // --- 🌴 CARIBBEAN ---
    'caribbean': CuisineTheme(
      colors: [Color(0xFF00778B), Color(0xFFFFC72C)], 
      emojis: ['🥥', '🍍', '🍹', '🌴', '🌶️', '🍗', '🍌'],
    ),
    'jamaican': CuisineTheme(
      colors: [Color(0xFF000000), Color(0xFF009B3A), Color(0xFFFED100)], 
      emojis: ['🍗', '🍚', '🍌', '🥥', '🌶️', '🍹', '🇯🇲'],
    ),
    'haitian': CuisineTheme(
      colors: [Color(0xFFD21034), Color(0xFF00209F)], 
      emojis: ['🍚', '🍗', '🥣', '🌶️', '🥭', '🇭🇹'],
    ),
    'dominican': CuisineTheme(
      colors: [Color(0xFF002D62), Color(0xFFCE1126), Color(0xFFFFFFFF)], 
      emojis: ['🍚', '🍗', '🍌', '🥑', '🥩', '⚾', '🇩🇴'],
    ),
    'cuban': CuisineTheme(
      colors: [Color(0xFF002A8F), Color(0xFFFFFFFF), Color(0xFFCF142B)], 
      emojis: ['🥪', '☕', '🍚', '🍌', '🥩', '🚙', '🇨🇺'],
    ),
    'puerto_rican': CuisineTheme(
      colors: [Color(0xFFED0000), Color(0xFFFFFFFF), Color(0xFF0050F0)], 
      emojis: ['🍚', '🍗', '🍌', '🥥', '💃', '🇵🇷'],
    ),
    'trinidadian': CuisineTheme(
      colors: [Color(0xFFCE1126), Color(0xFFFFFFFF), Color(0xFF000000)], 
      emojis: ['🍛', '🌯', '🌶️', '🥥', '🇹🇹'],
    ),
    'guyanese': CuisineTheme(
      colors: [Color(0xFF009E49), Color(0xFFFCD116), Color(0xFFCE1126)], 
      emojis: ['🍛', '🍞', '🍚', '🌶️', '🇬🇾'],
    ),

    // --- 🌍 AFRICA ---
    'ethiopian': CuisineTheme(
      colors: [Color(0xFF009A44), Color(0xFFFEDD00), Color(0xFFFF0000)], 
      emojis: ['🥘', '🫓', '☕', '🌶️', '🥩', '🇪🇹'],
    ),
    'senegalese': CuisineTheme(
      colors: [Color(0xFF00853F), Color(0xFFFDEF42), Color(0xFFE31B23)], 
      emojis: ['🍚', '🐟', '🥜', '🍋', '🇸🇳'],
    ),
    'nigerian': CuisineTheme(
      colors: [Color(0xFF008751), Color(0xFFFFFFFF)], 
      emojis: ['🍚', '🍗', '🥘', '🌶️', '🥬', '🇳🇬'],
    ),
    'west_african': CuisineTheme(
      colors: [Color(0xFF00853F), Color(0xFFFDEF42), Color(0xFFE31B23)], 
      emojis: ['🍚', '🥘', '🐟', '🌶️'],
    ),
    'african': CuisineTheme(
      colors: [Color(0xFF009A44), Color(0xFFFEDD00), Color(0xFFFF0000)], 
      emojis: ['🥘', '🍚', '🌽', '🌍', '🥁'],
    ),
    'moroccan': CuisineTheme(
      colors: [Color(0xFFC1272D), Color(0xFF006233)], 
      emojis: ['🥘', '🍋', '🫒', '🍵', '🍚', '🇲🇦'],
    ),

    // --- 🥤 DRINKS & CAFE ---
    'bubble_tea': CuisineTheme(
      colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)], 
      emojis: ['🧋', '🍵', '🧊', '🍓', '🥛', '🫐'],
      textColor: Colors.black54,
    ),
    'bubble tea': CuisineTheme(
      colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
      emojis: ['🧋', '🍵', '🧊', '🍓', '🥛', '🫐'],
      textColor: Colors.black54,
    ),
    'coffee': CuisineTheme(
      colors: [Color(0xFF603813), Color(0xFFb29f94)], 
      emojis: ['☕', '🥐', '🥯', '🥞', '🥛', '🍪'],
    ),
    'cafe': CuisineTheme(
      colors: [Color(0xFF603813), Color(0xFFb29f94)], 
      emojis: ['☕', '🥪', '🥗', '💻', '🍰'],
    ),
    'tea': CuisineTheme(
      colors: [Color(0xFFD4FC79), Color(0xFF96E6A1)], 
      emojis: ['🍵', '🫖', '🍃', '🍋', '🍯'],
    ),
    'juice': CuisineTheme(
      colors: [Color(0xFFff9966), Color(0xFFd4fc79), Color(0xFF96e6a1)], 
      emojis: ['🧃', '🍊', '🍏', '🍓', '🍌', '🥕', '🥤'],
    ),
    'smoothie': CuisineTheme(
      colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)], 
      emojis: ['🥤', '🍓', '🍌', '🫐', '🧊'],
    ),
    'açaí': CuisineTheme(
      colors: [Color(0xFF4B0082), Color(0xFFDA70D6)], 
      emojis: ['🥣', '🫐', '🍓', '🍌', '🥥', '🍯'],
    ),
    'snack': CuisineTheme(
      colors: [Color(0xFFFFD200), Color(0xFFF7971E)], 
      emojis: ['🍿', '🥨', '🍫', '🥜', '🥤'],
    ),
    
    // --- 🍰 BAKERY & DESSERTS ---
    'donut': CuisineTheme(
      colors: [Color(0xFFff9a9e), Color(0xFFfecfef)], 
      emojis: ['🍩', '☕', '🥛', '🍫', '🍬'],
    ),
    'ice cream': CuisineTheme(
      colors: [Color(0xFFA1FFCE), Color(0xFFFAFFD1)], 
      emojis: ['🍦', '🍨', '🍫', '🍒', '🧇'],
      textColor: Colors.black54,
    ),
    'frozen_yogurt': CuisineTheme(
      colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)], 
      emojis: ['🍦', '🍓', '🫐', '🥄', '🧁'],
    ),
    'dessert': CuisineTheme(
      colors: [Color(0xFFff758c), Color(0xFFff7eb3)], 
      emojis: ['🍦', '🍩', '🍪', '🍰', '🍫', '🍭'],
    ),
    'bakery': CuisineTheme(
      colors: [Color(0xFFDAE2F8), Color(0xFFD6A4A4)], 
      emojis: ['🥐', '🥖', '🥯', '🧁', '🍰', '🍪'],
    ),
    'pastry': CuisineTheme(
      colors: [Color(0xFFDAE2F8), Color(0xFFD6A4A4)], 
      emojis: ['🥐', '🧁', '🥧', '🍰', '🍪'],
    ),
    'crepe': CuisineTheme(
      colors: [Color(0xFFFDFBFB), Color(0xFFEBEDEE)], 
      emojis: ['🥞', '🍓', '🍫', '🍌', '🍯'],
      textColor: Colors.black87,
    ),
    'crepes': CuisineTheme(
      colors: [Color(0xFFFDFBFB), Color(0xFFEBEDEE)], 
      emojis: ['🥞', '🍓', '🍫', '🍌', '🍯'],
      textColor: Colors.black87,
    ),
    'cookie': CuisineTheme(
      colors: [Color(0xFFD2B48C), Color(0xFF8B4513)], 
      emojis: ['🍪', '🥛', '🍫', '🥜'],
    ),
    'pretzel': CuisineTheme(
      colors: [Color(0xFF8B4513), Color(0xFFD2B48C)], 
      emojis: ['🥨', '🍺', '🧀', '🧂'],
    ),

    // --- 🥗 HEALTHY ---
    'healthy': CuisineTheme(
      colors: [Color(0xFF56ab2f), Color(0xFFa8e063)], 
      emojis: ['🥗', '🥑', '🥦', '🥕', '🥒', '🥬', '🍎'],
    ),
    'salad': CuisineTheme(
      colors: [Color(0xFF56ab2f), Color(0xFFa8e063)], 
      emojis: ['🥗', '🍅', '🥒', '🧀', '🥬'],
    ),
    'health_food': CuisineTheme(
      colors: [Color(0xFF56ab2f), Color(0xFFa8e063)], 
      emojis: ['🥗', '🥑', '🍓', '🥕', '🥤'],
    ),
    'vegan': CuisineTheme(
      colors: [Color(0xFF134E5E), Color(0xFF71B280)], 
      emojis: ['🥦', '🥑', '🥕', '🌽', '🥬', '🍅'],
    ),
    'poke': CuisineTheme(
      colors: [Color(0xFFFF8C00), Color(0xFF40E0D0)], 
      emojis: ['🥗', '🐟', '🍚', '🥑', '🌺', '🍍'],
    ),

    // --- 🥯 NYC DELI ---
    'deli': CuisineTheme(
      colors: [Color(0xFFE6DADA), Color(0xFF274046)], 
      emojis: ['🥯', '🥪', '🥒', '☕', '🥩', '🧀'],
    ),
    'bagel': CuisineTheme(
      colors: [Color(0xFFfdfbfb), Color(0xFFebedee)], 
      emojis: ['🥯', '☕', '🧀', '🐟', '🥚'],
      textColor: Colors.black87,
    ),
    'sandwich': CuisineTheme(
      colors: [Color(0xFFD7D2CC), Color(0xFF304352)], 
      emojis: ['🥪', '🥬', '🍅', '🧀', '🥓'],
    ),

    // --- 🍸 NIGHTLIFE ---
    'bar': CuisineTheme(
      colors: [Color(0xFF2b5876), Color(0xFF4e4376)], 
      emojis: ['🍺', '🍷', '🍸', '🍹', '🥂', '🥃'],
    ),
    'pub': CuisineTheme(
      colors: [Color(0xFF232526), Color(0xFF414345)], 
      emojis: ['🍺', '🍟', '🍔', '🎯', '🥜'],
    ),
    'gastropub': CuisineTheme(
      colors: [Color(0xFF485563), Color(0xFF29323C)], 
      emojis: ['🍺', '🍔', '🍟', '🍷', '🥩'],
    ),
    'wine': CuisineTheme(
      colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)], 
      emojis: ['🍷', '🍇', '🧀', '🥖', '🥂'],
    ),
    'cocktail': CuisineTheme(
      colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)], 
      emojis: ['🍸', '🍹', '🍋', '🧊', '🍒', '🥂'],
    ),

    // --- 🍳 BREAKFAST ---
    'breakfast': CuisineTheme(
      colors: [Color(0xFFF2994A), Color(0xFFF2C94C)], 
      emojis: ['🍳', '🥞', '🥓', '☕', '🥯', '🍊'],
    ),
    'brunch': CuisineTheme(
      colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)], 
      emojis: ['🥂', '🍳', '🥑', '🧇', '🥞', '🍓'],
    ),

    // --- 🌎 OTHERS ---
    'seafood': CuisineTheme(
      colors: [Color(0xFF2980B9), Color(0xFF6DD5FA), Color(0xFFFFFFFF)], 
      emojis: ['🦞', '🐟', '🍤', '🦀', '🍋', '🦪'],
    ),
    'fish': CuisineTheme(
      colors: [Color(0xFF2980B9), Color(0xFF6DD5FA)], 
      emojis: ['🐟', '🍋', '🍟', '🧂'],
    ),
    'hawaiian': CuisineTheme(
      colors: [Color(0xFF1CB5E0), Color(0xFF000046)], 
      emojis: ['🌺', '🍍', '🥥', '🐟', '🍚'],
    ),
    'australian': CuisineTheme(
      colors: [Color(0xFFFFCD00), Color(0xFF00843D)], 
      emojis: ['🥩', '🦐', '🥑', '☕', '🍺', '🥧', '🇦🇺'],
    ),
    'international': CuisineTheme(
      colors: [Color(0xFF4facfe), Color(0xFF00f2fe)], 
      emojis: ['🌍', '✈️', '🍽️', '🥘'],
    ),
    'eclectic': CuisineTheme(
      colors: [Color(0xFF833ab4), Color(0xFFfd1d1d), Color(0xFFfcb045)], 
      emojis: ['🎨', '🍽️', '🍷', '🥗', '🥘'],
    ),
    'continental': CuisineTheme(
      colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)], 
      emojis: ['🍽️', '🍷', '🥖', '🥩', '🥗'],
    ),
    'soup': CuisineTheme(
      colors: [Color(0xFFFF9966), Color(0xFFFF5E62)], 
      emojis: ['🥣', '🍞', '🥄', '🍅', '🥕'],
    ),
    'buffet': CuisineTheme(
      colors: [Color(0xFFFF512F), Color(0xFFDD2476)], 
      emojis: ['🍽️', '🍗', '🥗', '🍰', '🍕'],
    ),
    'fine_dining': CuisineTheme(
      colors: [Color(0xFF141E30), Color(0xFF243B55)], 
      emojis: ['🥂', '🍽️', '🍷', '🕯️', '🤵'],
    ),
    'regional': CuisineTheme(
      colors: [Color(0xFFDAE2F8), Color(0xFFD6A4A4)], 
      emojis: ['🗺️', '🍽️', '🥘', '📍'],
    ),

    // DEFAULT
    'default': CuisineTheme(
      colors: [Color(0xFF4facfe), Color(0xFF00f2fe)], 
      emojis: ['🍽️', '🍴', '🧂', '🥣', '👨‍🍳', '😋'],
    ),
  };

// --- 2. THE WIDGET ---
class AnimatedCuisinePlaceholder extends StatefulWidget {
  final String cuisine;
  final bool compact; 

  const AnimatedCuisinePlaceholder({
    super.key,
    required this.cuisine,
    this.compact = false,
  });

  @override
  State<AnimatedCuisinePlaceholder> createState() => _AnimatedCuisinePlaceholderState();
}

class _AnimatedCuisinePlaceholderState extends State<AnimatedCuisinePlaceholder> {
  late CuisineTheme _theme;
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _parseCuisine();
  }

  @override
  void didUpdateWidget(AnimatedCuisinePlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cuisine != widget.cuisine) {
      _parseCuisine();
    }
  }

  void _parseCuisine() {
    final raw = widget.cuisine.toLowerCase();
    
    // Sort keys by length to match "bubble tea" before "tea"
    // (Note: Since _cuisineThemes is outside this class, ensure it's accessible)
    // If _cuisineThemes is defined globally in this file, this works.
    final sortedKeys = _cuisineThemes.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    String matchedKey = 'default';
    for (final key in sortedKeys) {
      if (raw.contains(key)) {
        matchedKey = key;
        break;
      }
    }
    
    _theme = _cuisineThemes[matchedKey] ?? _cuisineThemes['default']!;

    if (matchedKey != 'default') {
      // Handle "bubble_tea" -> "Bubble Tea"
      String displayKey = matchedKey.replaceAll('_', ' ');
      _displayName = displayKey.split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
    } else {
      // Fallback formatting
      final firstWord = raw.split(RegExp(r'[;,/]')).first.trim().replaceAll('_', ' ');
      _displayName = firstWord.isNotEmpty 
          ? firstWord.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')
          : "Restaurant";
    }
  }

  @override
  Widget build(BuildContext context) {
    // This uses your NEW optimized "Baked" structure + the Text Fix
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // LAYER 1: GRADIENT
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _theme.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // LAYER 2: ANIMATION (The High-Performance Engine)
          RepaintBoundary(
            child: _BakedEmojiOverlay(theme: _theme),
          ),

          // LAYER 3: TITLE (Now with FittedBox Fix!)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FittedBox(
                fit: BoxFit.scaleDown, // <--- 🌟 FIX: Prevents text splitting
                child: Text(
                  _displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: widget.compact ? 22 : 40,
                    fontWeight: FontWeight.w900,
                    color: _theme.textColor,
                    shadows: [
                      Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 3. THE BAKED ENGINE (Your optimized code) ---
class _EmojiParticle {
  double x, y, vx, vy, rotation, rotationSpeed;
  final ui.Image image;
  final double width, height;

  _EmojiParticle({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.rotation, required this.rotationSpeed, required this.image,
    required this.width, required this.height,
  });
}

class _BakedEmojiOverlay extends StatefulWidget {
  final CuisineTheme theme;
  const _BakedEmojiOverlay({required this.theme});

  @override
  State<_BakedEmojiOverlay> createState() => _BakedEmojiOverlayState();
}

class _BakedEmojiOverlayState extends State<_BakedEmojiOverlay> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final Random _random = Random();
  final List<_EmojiParticle> _particles = [];
  final ValueNotifier<int> _tickNotifier = ValueNotifier(0);
  
  bool _isLoading = true;
  Size _currentSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _bakeEmojis();
  }

  @override
  void didUpdateWidget(_BakedEmojiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme) {
      _isLoading = true;
      _particles.clear();
      _bakeEmojis();
    }
  }

  Future<void> _bakeEmojis() async {
    final int particleCount = 5 + _random.nextInt(2);
    List<String> deck = List.from(widget.theme.emojis);
    deck.shuffle(_random);

    for (int i = 0; i < particleCount; i++) {
      String emoji = deck[i % deck.length];
      double fontSize = 40 + _random.nextDouble() * 30; 
      
      final ui.Image snapshot = await _rasterizeEmoji(emoji, fontSize);

      _particles.add(_EmojiParticle(
        x: _random.nextDouble() * 300, 
        y: _random.nextDouble() * 200,
        vx: (_random.nextBool() ? 1 : -1) * (0.5 + _random.nextDouble() * 0.5), 
        vy: (_random.nextBool() ? 1 : -1) * (0.5 + _random.nextDouble() * 0.5),
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.03,
        image: snapshot,
        width: snapshot.width.toDouble(),
        height: snapshot.height.toDouble(),
      ));
    }

    if (mounted) {
      setState(() { _isLoading = false; });
      _ticker.start();
    }
  }

  Future<ui.Image> _rasterizeEmoji(String emoji, double fontSize) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: fontSize,
          shadows: [
             Shadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    painter.layout();
    final double padding = 10.0;
    canvas.translate(padding, padding);
    painter.paint(canvas, Offset.zero);
    
    final ui.Picture picture = recorder.endRecording();
    return picture.toImage(
      (painter.width + padding * 2).toInt(), 
      (painter.height + padding * 2).toInt()
    );
  }

  void _onTick(Duration elapsed) {
    if (_currentSize == Size.zero || _isLoading) return;

    for (var p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.rotation += p.rotationSpeed;

      if (p.x < -10) { p.x = -10; p.vx = p.vx.abs(); } 
      else if (p.x > _currentSize.width - p.width + 10) { p.x = _currentSize.width - p.width + 10; p.vx = -p.vx.abs(); }
      
      if (p.y < -10) { p.y = -10; p.vy = p.vy.abs(); } 
      else if (p.y > _currentSize.height - p.height + 10) { p.y = _currentSize.height - p.height + 10; p.vy = -p.vy.abs(); }
    }
    _tickNotifier.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tickNotifier.dispose();
    for (var p in _particles) {
      p.image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(); 

    return LayoutBuilder(
      builder: (context, constraints) {
        _currentSize = Size(
          constraints.maxWidth, 
          constraints.maxHeight != double.infinity ? constraints.maxHeight : 250.0
        );

        return CustomPaint(
          painter: _EmojiPainter(particles: _particles, repaint: _tickNotifier),
          size: Size.infinite,
        );
      },
    );
  }
}

class _EmojiPainter extends CustomPainter {
  final List<_EmojiParticle> particles;
  final Paint _paint = Paint(); 

  _EmojiPainter({required this.particles, required super.repaint});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      canvas.save();
      double cx = p.x + p.width / 2;
      double cy = p.y + p.height / 2;
      canvas.translate(cx, cy);
      canvas.rotate(p.rotation);
      canvas.translate(-cx, -cy);
      canvas.drawImage(p.image, Offset(p.x, p.y), _paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}