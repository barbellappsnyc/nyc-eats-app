class CuisineConstants {
  // ===========================================================================
  // 🎨 1. THE EMOJI PALETTES (From Step 1)
  // ===========================================================================
  static const Map<String, List<String>> emojiPalettes = {
    // --- 🇺🇸 AMERICANA & COMFORT ---
    'american': ['🍔', '🍟', '🍕', '🍩', '🥤', '🌭', '🥓', '🦅', '🇺🇸'],
    'diner': ['🥞', '🍳', '🥓', '☕', '🍔', '🍦', '🍒', '🇺🇸'],
    'soul_food': ['🍗', '🌽', '🍞', '🥬', '🍠', '🧀', '🇺🇸'],
    'soul': ['🍗', '🌽', '🍞', '🥬', '🍠', '🧀', '🇺🇸'],
    'southern': ['🍗', '🥧', '🌽', '🍞', '🍑', '🇺🇸'],
    'cajun': ['🦐', '🍚', '🌽', '🦀', '🌶️', '🇺🇸'],
    'hot_dog': ['🌭', '🥨', '🥤', '⚾', '🍟', '🇺🇸'],
    'corn_dog': ['🌭', '🌽', '🎪', '🍟', '🇺🇸'],
    'burger': ['🍔', '🍟', '🥤', '🥓', '🧀', '🥩'],
    'steak': ['🥩', '🍖', '🍷', '🔥', '🥔', '🔪', '🧂'],
    'grill': ['🔥', '🥩', '🌽', '🍔', '🌭'],

    // --- 🌍 EUROPE ---
    'italian': ['🍝', '🍕', '🍷', '🍅', '🧀', '🌿', '🥖', '🛵', '🇮🇹'],
    'pizza': ['🍕', '🧀', '🍅', '🌿', '🔥', '🥤', '🇮🇹'],
    'french': ['🥐', '🥖', '🍷', '🧀', '🥩', '🍇', '☕', '🗼', '🇫🇷'],
    'german': ['🥨', '🍺', '🌭', '🥩', '🥔', '🥖', '🇩🇪'],
    'austrian': ['🥩', '🍰', '🍺', '🥨', '☕', '🇦🇹'],
    'irish': ['🍺', '🥔', '🍀', '🍲', '🍞', '🇮🇪'],
    'british': ['🐟', '🍟', '🫖', '🥧', '🍺', '🇬🇧'],
    'fish_and_chips': ['🐟', '🍟', '🍋', '🍺', '🧂', '🇬🇧'],
    'spanish': ['🥘', '🍷', '🍇', '🧀', '💃', '🦐', '🇪🇸'],
    'tapas': ['🍤', '🫒', '🧀', '🍷', '🍖', '🇪🇸'],
    'basque': ['🍖', '🍷', '🧀', '🐟', '🇪🇸'],
    'portuguese': ['🐟', '🍷', '🥖', '🥘', '🧁', '🇵🇹'],
    'greek': ['🥙', '🫒', '🍋', '🍇', '🧀', '🏺', '🐟', '🇬🇷'],
    'scandinavian': ['🐟', '🥖', '🥩', '🫐', '🥔', '🇸🇪', '🇳🇴'],
    'swiss': ['🧀', '🍫', '🫕', '⛰️', '🇨🇭'],
    'fondue': ['🫕', '🧀', '🥖', '🔥', '🇨🇭'],
    'belgian': ['🧇', '🍟', '🍫', '🍺', '🍪', '🇧🇪'],

    // --- 🇷🇺 EASTERN EUROPE ---
    'russian': ['🥟', '🍲', '🥔', '🥞', '🍵', '🇷🇺'],
    'ukrainian': ['🥟', '🍲', '🍖', '🥖', '🌻', '🇺🇦'],
    'polish': ['🥟', '🌭', '🍲', '🥔', '🍩', '🇵🇱'],
    'georgian': ['🧀', '🥟', '🍷', '🥖', '🥩', '🇬🇪'],
    'eastern_european': ['🥟', '🍲', '🥔', '🥩', '🍺'],
    'romanian': ['🥩', '🍲', '🍷', '🥖', '🇷🇴'],
    'balkan': ['🥩', '🥙', '🥗', '🥖'],

    // --- 🌏 ASIA ---
    'japanese': ['🍣', '🍜', '🍱', '🍙', '🥢', '🍵', '🍤', '🎋', '🇯🇵'],
    'sushi': ['🍣', '🍱', '🍤', '🥢', '🐟', '🍚', '🇯🇵'],
    'ramen': ['🍜', '🥚', '🥩', '🥢', '🍥', '🔥', '🇯🇵'],
    'korean': ['🥩', '🍚', '🥢', '🥬', '🍲', '🔥', '🌶️', '🇰🇷'],
    'chinese': ['🥟', '🍜', '🥢', '🥠', '🍚', '🦆', '🍵', '🏮', '🇨🇳'],
    'sichuan': ['🌶️', '🍜', '🥘', '🥢', '🔥', '🇨🇳'],
    'dim_sum': ['🥟', '🍵', '🥢', '🥠', '🍤', '🇨🇳'],
    'dumpling': ['🥟', '🥢', '🍲', '🍚'],
    'dumplings': ['🥟', '🥢', '🍲', '🍚'],
    'filipino': ['🍚', '🍗', '🍜', '🥭', '🍦', '🐷', '🇵🇭'],
    'thai': ['🍜', '🌶️', '🥥', '🍤', '🍋', '🥜', '🐘', '🇹🇭'],
    'vietnamese': ['🍜', '🥖', '🌿', '🍤', '☕', '🥢', '🇻🇳'],
    'indian': ['🍛', '🫓', '🍚', '🌶️', '🥘', '🍲', '🥔', '🛺', '🇮🇳'],
    'pakistani': ['🍛', '🍚', '🍖', '🌶️', '🫓', '🇵🇰'],
    'sri_lankan': ['🍚', '🥥', '🐟', '🌶️', '🍵', '🇱🇰'],
    'nepalese': ['🥟', '🍜', '🍚', '🏔️', '🇳🇵'],
    'himalayan': ['🥟', '🍜', '🍵', '🏔️'],
    'tibetan': ['🥟', '🍜', '🍵', '🧘'],
    'burmese': ['🍜', '🍚', '🍵', '🍋', '🇲🇲'],
    'cambodian': ['🍲', '🍚', '🐟', '🥥', '🇰🇭'],
    'indonesian': ['🍚', '🍢', '🥜', '🌶️', '🇮🇩'],
    'malaysian': ['🍜', '🍚', '🥥', '🌶️', '🍢', '🇲🇾'],
    'taiwanese': ['🧋', '🍜', '🥟', '🍚', '🇹🇼'],
    'uyghur': ['🍜', '🥩', '🥙', '🍢'],
    'hotpot': ['🍲', '🔥', '🥩', '🥬', '🥢', '🇨🇳'],

    // --- 🇦🇫 CENTRAL ASIA & MIDDLE EAST ---
    'afghan': ['🍚', '🍖', '🍇', '🍞', '🥟', '🇦🇫'],
    'persian': ['🍚', '🍖', '🍋', '🌿', '🥙', '🇮🇷'],
    'middle_eastern': ['🥙', '🧆', '🍋', '🌿', '🍚', '🍖'],
    'lebanese': ['🥙', '🧆', '🍋', '🌿', '🍇', '🫒', '🇱🇧'],
    'israeli': ['🥙', '🧆', '🍋', '🥚', '🥯', '🇮🇱'],
    'yemeni': ['🍚', '🍖', '🥘', '☕', '🇾🇪'],
    'egyptian': ['🧆', '🍚', '🥙', '🥘', '🇪🇬'],
    'turkish': ['🥙', '🥩', '☕', '🫖', '🍇', '🥖', '🇹🇷'],
    'kebab': ['🥙', '🥩', '🔥', '🍅', '🍚'],
    'doner': ['🥙', '🥩', '🔥', '🥗'],
    'falafel': ['🧆', '🥙', '🥗', '🍋'],
    'gyros': ['🥙', '🥩', '🍟', '🥗', '🇬🇷'],

    // --- 🌎 LATIN AMERICA & CARIBBEAN ---
    'brazilian': ['🥩', '🍚', '🥥', '🍹', '🍖', '⚽', '🇧🇷'],
    'argentinian': ['🥩', '🍷', '🥟', '🔥', '🌿', '🇦🇷'],
    'peruvian': ['🥔', '🌽', '🐟', '🌶️', '🍗', '🍋', '🇵🇪'],
    'mexican': ['🌮', '🌯', '🥑', '🌽', '🌶️', '🍹', '🥙', '🌵', '🇲🇽'],
    'tex-mex': ['🌮', '🧀', '🥩', '🌶️', '🌯', '🇺🇸', '🇲🇽'],
    'taco': ['🌮', '🌶️', '🥑', '🍹', '🧀', '🌽', '🇲🇽'],
    'colombian': ['☕', '🌽', '🥑', '🍖', '🥘', '🇨🇴'],
    'venezuelan': ['🫓', '🌽', '🥩', '🥑', '🧀', '🇻🇪'],
    'ecuadorian': ['🍤', '🍌', '🍲', '🌽', '🥔', '🇪🇨'],
    'salvadoran': ['🫓', '🧀', '🌽', '🥙', '🇸🇻'],
    'salvadorian': ['🫓', '🧀', '🌽', '🥙', '🇸🇻'],
    'guatemalan': ['🌽', '🥑', '☕', '🍛', '🇬🇹'],
    'honduran': ['🍌', '🥥', '🌽', '🍛', '🇭🇳'],
    'uruguayan': ['🥩', '🍷', '🧉', '🥪', '🇺🇾'],
    'hispanic': ['🌮', '🌽', '🥑', '💃', '🍹'],
    'latin': ['🌮', '🌽', '🥑', '💃', '🍹'],

    // --- 🌴 CARIBBEAN ---
    'caribbean': ['🥥', '🍍', '🍹', '🌴', '🌶️', '🍗', '🍌'],
    'jamaican': ['🍗', '🍚', '🍌', '🥥', '🌶️', '🍹', '🇯🇲'],
    'haitian': ['🍚', '🍗', '🥣', '🌶️', '🥭', '🇭🇹'],
    'dominican': ['🍚', '🍗', '🍌', '🥑', '🥩', '⚾', '🇩🇴'],
    'cuban': ['🥪', '☕', '🍚', '🍌', '🥩', '🚙', '🇨🇺'],
    'puerto_rican': ['🍚', '🍗', '🍌', '🥥', '💃', '🇵🇷'],
    'trinidadian': ['🍛', '🌯', '🌶️', '🥥', '🇹🇹'],
    'guyanese': ['🍛', '🍞', '🍚', '🌶️', '🇬🇾'],

    // --- 🌍 AFRICA ---
    'ethiopian': ['🥘', '🫓', '☕', '🌶️', '🥩', '🇪🇹'],
    'senegalese': ['🍚', '🐟', '🥜', '🍋', '🇸🇳'],
    'nigerian': ['🍚', '🍗', '🥘', '🌶️', '🥬', '🇳🇬'],
    'west_african': ['🍚', '🥘', '🐟', '🌶️'],
    'african': ['🥘', '🍚', '🌽', '🌍', '🥁'],
    'moroccan': ['🥘', '🍋', '🫒', '🍵', '🍚', '🇲🇦'],

    // --- 🥤 DRINKS, CAFE & OTHERS ---
    'bubble_tea': ['🧋', '🍵', '🧊', '🍓', '🥛', '🫐'],
    'bubble tea': ['🧋', '🍵', '🧊', '🍓', '🥛', '🫐'],
    'coffee': ['☕', '🥐', '🥯', '🥞', '🥛', '🍪'],
    'cafe': ['☕', '🥪', '🥗', '💻', '🍰'],
    'tea': ['🍵', '🫖', '🍃', '🍋', '🍯'],
    'juice': ['🧃', '🍊', '🍏', '🍓', '🍌', '🥕', '🥤'],
    'smoothie': ['🥤', '🍓', '🍌', '🫐', '🧊'],
    'açaí': ['🥣', '🫐', '🍓', '🍌', '🥥', '🍯'],
    'snack': ['🍿', '🥨', '🍫', '🥜', '🥤'],
    'donut': ['🍩', '☕', '🥛', '🍫', '🍬'],
    'ice cream': ['🍦', '🍨', '🍫', '🍒', '🧇'],
    'frozen_yogurt': ['🍦', '🍓', '🫐', '🥄', '🧁'],
    'dessert': ['🍦', '🍩', '🍪', '🍰', '🍫', '🍭'],
    'bakery': ['🥐', '🥖', '🥯', '🧁', '🍰', '🍪'],
    'pastry': ['🥐', '🧁', '🥧', '🍰', '🍪'],
    'crepe': ['🥞', '🍓', '🍫', '🍌', '🍯'],
    'crepes': ['🥞', '🍓', '🍫', '🍌', '🍯'],
    'cookie': ['🍪', '🥛', '🍫', '🥜'],
    'pretzel': ['🥨', '🍺', '🧀', '🧂'],
    'healthy': ['🥗', '🥑', '🥦', '🥕', '🥒', '🥬', '🍎'],
    'salad': ['🥗', '🍅', '🥒', '🧀', '🥬'],
    'health_food': ['🥗', '🥑', '🍓', '🥕', '🥤'],
    'vegan': ['🥦', '🥑', '🥕', '🌽', '🥬', '🍅'],
    'poke': ['🥗', '🐟', '🍚', '🥑', '🌺', '🍍'],
    'deli': ['🥯', '🥪', '🥒', '☕', '🥩', '🧀'],
    'bagel': ['🥯', '☕', '🧀', '🐟', '🥚'],
    'sandwich': ['🥪', '🥬', '🍅', '🧀', '🥓'],
    'bar': ['🍺', '🍷', '🍸', '🍹', '🥂', '🥃'],
    'pub': ['🍺', '🍟', '🍔', '🎯', '🥜'],
    'gastropub': ['🍺', '🍔', '🍟', '🍷', '🥩'],
    'wine': ['🍷', '🍇', '🧀', '🥖', '🥂'],
    'cocktail': ['🍸', '🍹', '🍋', '🧊', '🍒', '🥂'],
    'breakfast': ['🍳', '🥞', '🥓', '☕', '🥯', '🍊'],
    'brunch': ['🥂', '🍳', '🥑', '🧇', '🥞', '🍓'],
    'seafood': ['🦞', '🐟', '🍤', '🦀', '🍋', '🦪'],
    'fish': ['🐟', '🍋', '🍟', '🧂'],
    'hawaiian': ['🌺', '🍍', '🥥', '🐟', '🍚'],
    'australian': ['🥩', '🦐', '🥑', '☕', '🍺', '🥧', '🇦🇺'],
    'international': ['🌍', '✈️', '🍽️', '🥘'],
    'eclectic': ['🎨', '🍽️', '🍷', '🥗', '🥘'],
    'continental': ['🍽️', '🍷', '🥖', '🥩', '🥗'],
    'soup': ['🥣', '🍞', '🥄', '🍅', '🥕'],
    'buffet': ['🍽️', '🍗', '🥗', '🍰', '🍕'],
    'fine_dining': ['🥂', '🍽️', '🍷', '🕯️', '🤵'],
    'regional': ['🗺️', '🍽️', '🥘', '📍'],
    'default': ['🍽️', '🍴', '🧂', '🥣', '👨‍🍳', '😋'],
  };

  // ===========================================================================
  // 📝 2. NATIVE LANGUAGE DICTIONARIES 
  // ===========================================================================

  // English (US/UK)
  static const List<String> _en = ['Enjoy your meal', 'Good eats', 'Savor the moment', 'Delicious', 'Cheers', 'Taste the world'];
  // Spanish (Spain, Mexico, Latin America)
  static const List<String> _es = ['Buen provecho', 'Salud', 'Barriga llena, corazón contento', 'Sobremesa', 'Delicioso', 'Saludcita'];
  // Italian
  static const List<String> _it = ['Buon appetito', 'La dolce vita', 'Mangia bene, ridi spesso', 'Cin cin', 'Squisito'];
  // French
  static const List<String> _fr = ['Bon appétit', 'C\'est la vie', 'Joie de vivre', 'Santé', 'Délicieux'];
  // Japanese (Itadakimasu, Oishii, Gochisousama, Kanpai, Wabi-sabi)
  static const List<String> _jp = ['いただきます', '美味しい', 'ごちそうさまでした', '乾杯', 'わびさび'];
  // Chinese (Man man chi, Ganbei, Se xiang wei, Hao wei, Sik faan)
  static const List<String> _cn = ['慢慢吃', '干杯', '色香味俱全', '好味', '食饭'];
  // Korean (Jal meokgesseumnida, Masisseoyo, Geonbae, Jin-su seong-chan)
  static const List<String> _kr = ['잘 먹겠습니다', '맛있어요', '건배', '진수성찬'];
  // Thai (Taan hai a-roi na kha, A-roi mak, Chon gaew)
  static const List<String> _th = ['ทานให้อร่อยนะคะ', 'อร่อยมาก', 'ชนแก้ว', 'แซ่บ', 'หิว'];
  // Vietnamese (Chuc ngon mieng, Mot hai ba do!, Ngon qua)
  static const List<String> _vn = ['Chúc ngon miệng', 'Một, hai, ba, dô!', 'Ngon quá', 'Ăn thôi', 'Cạn ly'];
  // Hindi (Swadisht, Bhojan ka anand lein, Atithi devo bhava)
  static const List<String> _hi = ['स्वादिष्ट', 'भोजन का आनंद लें', 'अतिथि देवो भव', 'मसालेदार', 'चाय'];
  // Arabic (Sahtein, Bil-hana wa ash-shifa, Ladhidh, Yalla nakul)
  static const List<String> _ar = ['صحتين', 'بالهناء والشفاء', 'لذيذ', 'صحة', 'يلا نأكل'];
  // German
  static const List<String> _de = ['Guten Appetit', 'Prost', 'Lecker', 'Mahlzeit', 'Zum Wohl'];
  // Russian (Priatnogo appetita, Na zdorovie, Ochen vkusno, Zastolie)
  static const List<String> _ru = ['Приятного аппетита', 'На здоровье', 'Очень вкусно', 'Застолье', 'Чокаться'];
  // Greek (Kali orexi, Ygeia, Nostimo, Philoxenia)
  static const List<String> _gr = ['Καλή όρεξη', 'Υγεία', 'Νόστιμο', 'Γεια μας', 'Φιλοξενία'];
  // Portuguese (Brazil/Portugal)
  static const List<String> _pt = ['Bom apetite', 'Saúde', 'Muito gostoso', 'Comida boa', 'Um brinde'];
  // Hebrew (Bete'avon, L'chaim, Ta'im me'od)
  static const List<String> _he = ['בתיאבון', 'לחיים', 'טעים מאוד', 'אוכל טוב', 'שבע'];
  // Turkish
  static const List<String> _tr = ['Afiyet olsun', 'Şerefe', 'Çok lezzetli', 'Elinize sağlık', 'Harika'];
  // Amharic/Ethiopian (Melkam megib, Enibela, Tafach)
  static const List<String> _am = ['መልካም ምግብ', 'እንብላ', 'ጣፋጭ', 'ጤና ይስጥልኝ'];
  // Georgian (Gemrielad miirtvit, Gaumarjos)
  static const List<String> _ka = ['გემრიელად მიირთვით', 'გაუმარჯოს', 'უგემრიელესია'];
  // Tagalog/Filipino
  static const List<String> _tl = ['Kain tayo', 'Masarap', 'Tagay', 'Busog', 'Mabuhay'];
  // Indonesian/Malay
  static const List<String> _id = ['Selamat makan', 'Enak sekali', 'Mari makan', 'Nyam nyam', 'Lezat'];
  // Polish
  static const List<String> _pl = ['Smacznego', 'Na zdrowie', 'Pyszne', 'Palce lizać'];
  // Ukrainian
  static const List<String> _uk = ['Смачного', 'Будьмо', 'Дуже смачно', 'На здоров\'я'];
  // Dutch/Belgian
  static const List<String> _nl = ['Smakelijk eten', 'Proost', 'Lekker', 'Gezellig'];
  // Scandi (Swedish/Norwegian/Danish)
  static const List<String> _sv = ['Smaklig måltid', 'Skål', 'Jättegott', 'Fika'];
  // Persian / Farsi
  static const List<String> _fa = ['نوش جان', 'به سلامتی', 'خیلی خوشمزه است', 'بفرمایید'];
  // Basque
  static const List<String> _eu = ['On egin', 'Topa', 'Goxo-goxoa', 'Edan'];
  // Irish Gaelic
  static const List<String> _ga = ['Bain taitneamh as do bhéile', 'Sláinte', 'An-bhlasta', 'Ithe'];
  // Hawaiian
  static const List<String> _hw = ['E ʻai kākou', 'Mahalo', 'Ono', 'Hipa hipa'];
  // Uyghur (Arabic script)
  static const List<String> _ug = ['ئاش بولسۇن', 'تەملىك', 'خۇش كەپسىز'];
  // Tibetan
  static const List<String> _bo = ['མཉེས་པོ་ཞིག', 'ཞིམ་པོ་འདུག', 'བཀྲ་ཤིས་བདེ་ལེགས'];
  // Burmese
  static const List<String> _my = ['စားကောင်းပါစေ', 'အရမ်းစားကောင်းတယ်', 'အောင်မြင်ပါစေ'];
  // Khmer/Cambodian
  static const List<String> _km = ['សូមទទួលទានឲ្យបានឆ្ងាញ់', 'ឆ្ងាញ់ណាស់', 'ជល់មួយ'];
  // Sinhala (Sri Lankan)
  static const List<String> _si = ['සුබ භෝජනයක්', 'හරිම රසයි', 'ජය වේවා'];
  // Nepali
  static const List<String> _ne = ['खानाको आनन्द लिनुहोस्', 'धेरै मीठो छ', 'जय होस'];
  // Patois / Creole (Caribbean)
  static const List<String> _jm = ['Nyam it up', 'Lick yuh lips', 'Jah bless', 'Bon apeti'];

  // ===========================================================================
  // 🗺️ 3. THE MAPPING: Connecting Cuisines to their Native Language!
  // ===========================================================================
  static const Map<String, List<String>> nativePhrases = {
    // Americana / English
    'american': _en, 'diner': _en, 'soul_food': _en, 'soul': _en, 'southern': _en, 
    'cajun': _en, 'hot_dog': _en, 'corn_dog': _en, 'burger': _en, 'steak': _en, 
    'grill': _en, 'british': _en, 'fish_and_chips': _en, 'australian': _en,
    
    // Europe
    'italian': _it, 'pizza': _it, 
    'french': _fr, 
    'german': _de, 'austrian': _de, 'swiss': _de, 'fondue': _de,
    'irish': _ga, 
    'spanish': _es, 'tapas': _es, 'basque': _eu,
    'portuguese': _pt, 
    'greek': _gr, 'gyros': _gr,
    'scandinavian': _sv, 
    'belgian': _nl,
    
    // Eastern Europe
    'russian': _ru, 
    'ukrainian': _uk, 
    'polish': _pl, 
    'georgian': _ka, 
    'eastern_european': _ru, 'balkan': _ru, 
    'romanian': _en, // Fallback
    
    // Asia
    'japanese': _jp, 'sushi': _jp, 'ramen': _jp,
    'korean': _kr, 
    'chinese': _cn, 'sichuan': _cn, 'dim_sum': _cn, 'dumpling': _cn, 'dumplings': _cn, 'hotpot': _cn, 'taiwanese': _cn,
    'filipino': _tl, 
    'thai': _th, 
    'vietnamese': _vn, 
    'indian': _hi, 'pakistani': _hi, 
    'sri_lankan': _si, 
    'nepalese': _ne, 'himalayan': _ne, 
    'tibetan': _bo, 
    'burmese': _my, 
    'cambodian': _km, 
    'indonesian': _id, 'malaysian': _id, 
    'uyghur': _ug, 
    
    // Middle East & Central Asia
    'afghan': _fa, 'persian': _fa, 
    'middle_eastern': _ar, 'lebanese': _ar, 'yemeni': _ar, 'egyptian': _ar, 'falafel': _ar,
    'israeli': _he, 
    'turkish': _tr, 'kebab': _tr, 'doner': _tr, 

    // Latin America & Caribbean
    'brazilian': _pt, 
    'argentinian': _es, 'peruvian': _es, 'mexican': _es, 'tex-mex': _es, 'taco': _es, 
    'colombian': _es, 'venezuelan': _es, 'ecuadorian': _es, 'salvadoran': _es, 
    'salvadorian': _es, 'guatemalan': _es, 'honduran': _es, 'uruguayan': _es, 
    'hispanic': _es, 'latin': _es, 
    'caribbean': _jm, 'jamaican': _jm, 'haitian': _jm, 'dominican': _es, 
    'cuban': _es, 'puerto_rican': _es, 'trinidadian': _jm, 'guyanese': _jm, 

    // Africa
    'ethiopian': _am, 
    'senegalese': _fr, // Lots of French influence, fallback
    'nigerian': _en, 
    'west_african': _en, 
    'african': _en, 
    'moroccan': _ar,

    // Hawaiian
    'hawaiian': _hw,

    // General / Fallbacks
    'default': _en,
    'cafe': _fr, 'bakery': _fr, 'pastry': _fr, 'crepe': _fr, 'crepes': _fr,
    'coffee': _it, 'bar': _en, 'pub': _en, 'gastropub': _en, 'wine': _it, 'cocktail': _en,
    'healthy': _en, 'salad': _en, 'health_food': _en, 'vegan': _en, 'poke': _hw,
    'seafood': _en, 'fish': _en, 'soup': _en, 'buffet': _en, 'fine_dining': _fr,
    'breakfast': _en, 'brunch': _en, 'international': _en, 'eclectic': _en, 'continental': _fr,
    'bubble_tea': _cn, 'bubble tea': _cn, 'juice': _en, 'smoothie': _en, 'açaí': _pt, 'snack': _en,
    'donut': _en, 'ice cream': _it, 'frozen_yogurt': _en, 'dessert': _fr, 'cookie': _en, 'pretzel': _de,
    'deli': _en, 'bagel': _en, 'sandwich': _en,
  };
}