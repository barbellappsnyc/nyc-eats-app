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
    'italian': ['🍕', '🍝', '🍷', '🍅', '🧀', '🌿', '🥖', '🛵', '🇮🇹'],
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

  // ===========================================================================
  // ✈️ 4. AIRPORT CODES (For Vintage Baggage Tag Backgrounds)
  // ===========================================================================

  // --- 1. SOVEREIGN COUNTRIES & NATIONALITIES ---
  static const List<String> _usAirports = ['JFK', 'LGA', 'EWR', 'LAX', 'ORD', 'ATL', 'MIA', 'SFO', 'DFW', 'SEA'];
  static const List<String> _auAirports = ['SYD', 'MEL', 'BNE', 'PER', 'ADL', 'CBR', 'HBA', 'DRW'];
  static const List<String> _brAirports = ['GRU', 'GIG', 'BSB', 'CNF', 'SSA', 'FOR', 'REC', 'POA'];
  static const List<String> _khAirports = ['PNH', 'REP', 'KOS'];
  static const List<String> _cnAirports = ['PEK', 'PVG', 'CAN', 'CTU', 'SZX', 'KMG', 'XIY', 'HGH'];
  static const List<String> _coAirports = ['BOG', 'MDE', 'CLO', 'CTG', 'BAQ'];
  static const List<String> _cuAirports = ['HAV', 'VRA', 'SCU', 'HOG', 'SNU'];
  static const List<String> _doAirports = ['SDQ', 'PUJ', 'STI', 'POP', 'LRM'];
  static const List<String> _phAirports = ['MNL', 'CEB', 'DVO', 'CRK', 'ILO'];
  static const List<String> _frAirports = ['CDG', 'ORY', 'NCE', 'LYS', 'MRS', 'TLS', 'BOD'];
  static const List<String> _grAirports = ['ATH', 'SKG', 'HER', 'RHO', 'CFU', 'JMK', 'JTR'];
  static const List<String> _gyAirports = ['GEO', 'OGL'];
  static const List<String> _inAirports = ['DEL', 'BOM', 'BLR', 'HYD', 'MAA', 'CCU', 'COK', 'AMD'];
  static const List<String> _ieAirports = ['DUB', 'ORK', 'SNN', 'NOC'];
  static const List<String> _ilAirports = ['TLV', 'ETM', 'HFA'];
  static const List<String> _itAirports = ['FCO', 'MXP', 'VCE', 'NAP', 'BLQ', 'PMO', 'CTA', 'LIN'];
  static const List<String> _jmAirports = ['KIN', 'MBJ', 'OCJ'];
  static const List<String> _jpAirports = ['NRT', 'HND', 'KIX', 'ITM', 'CTS', 'FUK', 'OKA', 'NGO'];
  static const List<String> _kzAirports = ['ALA', 'NQZ', 'CIT', 'KGF', 'GUW'];
  static const List<String> _krAirports = ['ICN', 'GMP', 'CJU', 'PUS', 'TAQ'];
  static const List<String> _lbAirports = ['BEY'];
  static const List<String> _myAirports = ['KUL', 'PEN', 'BKI', 'KCH', 'JHB'];
  static const List<String> _mxAirports = ['MEX', 'CUN', 'GDL', 'MTY', 'SJD', 'PVR', 'TIJ'];
  static const List<String> _plAirports = ['WAW', 'KRK', 'GDN', 'KTW', 'WRO'];
  static const List<String> _ptAirports = ['LIS', 'OPO', 'FAO', 'FNC', 'PDL'];
  static const List<String> _esAirports = ['MAD', 'BCN', 'PMI', 'AGP', 'ALC', 'TFS', 'VLC'];
  static const List<String> _syAirports = ['DAM', 'ALP', 'LTK'];
  static const List<String> _twAirports = ['TPE', 'KHH', 'TSA', 'RMQ', 'TNN'];
  static const List<String> _thAirports = ['BKK', 'DMK', 'HKT', 'CNX', 'USM', 'KBV'];
  static const List<String> _uzAirports = ['TAS', 'SKD', 'NMA', 'BHK', 'FEG'];
  static const List<String> _vnAirports = ['SGN', 'HAN', 'DAD', 'CXR', 'PQC', 'HPH'];

  // --- 2. BROAD REGIONS & CONTINENTS ---
  static const List<String> _africanAirports = ['JNB', 'CPT', 'NBO', 'ADD', 'LOS', 'ACC', 'DKR', 'KGL'];
  static const List<String> _arabAirports = ['DXB', 'AUH', 'DOH', 'RUH', 'JED', 'KWI', 'MCT', 'BAH'];
  static const List<String> _asianAirports = ['SIN', 'BKK', 'NRT', 'ICN', 'PEK', 'HKG', 'TPE', 'KUL'];
  static const List<String> _caribbeanAirports = ['NAS', 'SJU', 'BGI', 'POS', 'SXM', 'ANU', 'GCM'];
  static const List<String> _latamAirports = ['PTY', 'LIM', 'SCL', 'EZE', 'UIO', 'MVD', 'BOG'];
  static const List<String> _medAirports = ['MLA', 'LCA', 'PFO', 'PMO', 'CAG', 'IBZ'];
  static const List<String> _meAirports = ['DOH', 'DXB', 'AMM', 'BEY', 'MCT', 'RUH', 'KWI'];
  static const List<String> _nordicAirports = ['CPH', 'OSL', 'ARN', 'HEL', 'KEF', 'BGO', 'GOT'];
  static const List<String> _westAfricanAirports = ['LOS', 'ACC', 'DKR', 'ABJ', 'FNA', 'BKO', 'OXB'];

  // --- 3. HIGHLY SPECIFIC TERRITORIES & CULTURES ---
  static const List<String> _cantoneseAirports = ['CAN', 'SZX', 'MFM', 'HKG', 'ZUH'];
  static const List<String> _druzeAirports = ['BEY', 'AMM', 'DAM', 'TLV'];
  static const List<String> _hawaiianAirports = ['HNL', 'OGG', 'KOA', 'LIH', 'ITO'];
  static const List<String> _himalayanAirports = ['KTM', 'PBH', 'LXA', 'IXB', 'SXR'];
  static const List<String> _hkAirports = ['HKG'];
  static const List<String> _jewishAirports = ['TLV', 'ETM', 'JFK', 'EWR'];
  static const List<String> _southernAirports = ['ATL', 'MSY', 'BNA', 'CHS', 'MEM', 'SAV', 'AUS'];
  static const List<String> _uyghurAirports = ['URC', 'KHG', 'KCA', 'HTN'];

  // --- 4. GLOBAL FALLBACKS (For generic foods/cuisines outside the 48 regions) ---
  static const List<String> _defaultAirports = ['JFK', 'LGA', 'EWR', 'LHR', 'CDG', 'DXB', 'SIN', 'HKG'];

  // ===========================================================================
  // 🗺️ MASTER MAPPING: Connecting Cuisines to Airport Codes
  // ===========================================================================
  static const Map<String, List<String>> airportCodes = {
    // --- Americana ---
    'american': _usAirports, 
    'diner': _usAirports, 
    'hot_dog': _usAirports, 
    'corn_dog': _usAirports, 
    'burger': _usAirports, 
    'steak': _usAirports, 
    'grill': _usAirports,
    'southern': _southernAirports, 
    'soul_food': _southernAirports, 
    'soul': _southernAirports, 
    'cajun': _southernAirports,

    // --- Europe ---
    'italian': _itAirports, 
    'pizza': _itAirports,
    'french': _frAirports,
    'irish': _ieAirports,
    'spanish': _esAirports, 
    'tapas': _esAirports, 
    'basque': _esAirports,
    'portuguese': _ptAirports,
    'greek': _grAirports, 
    'gyros': _grAirports,
    'scandinavian': _nordicAirports,
    'polish': _plAirports,
    
    // European Fallbacks mapped to default Global Hubs
    'german': _defaultAirports, 
    'austrian': _defaultAirports, 
    'swiss': _defaultAirports, 
    'fondue': _defaultAirports, 
    'belgian': _defaultAirports,
    'british': _defaultAirports, 
    'fish_and_chips': _defaultAirports,
    'russian': _defaultAirports, 
    'ukrainian': _defaultAirports, 
    'georgian': _defaultAirports, 
    'eastern_european': _defaultAirports, 
    'romanian': _defaultAirports, 
    'balkan': _defaultAirports,

    // --- Asia ---
    'japanese': _jpAirports, 
    'sushi': _jpAirports, 
    'ramen': _jpAirports,
    'korean': _krAirports,
    'chinese': _cnAirports, 
    'sichuan': _cnAirports, 
    'dim_sum': _cantoneseAirports, 
    'dumpling': _cnAirports, 
    'dumplings': _cnAirports, 
    'hotpot': _cnAirports,
    'filipino': _phAirports,
    'thai': _thAirports,
    'vietnamese': _vnAirports,
    'indian': _inAirports, 
    'pakistani': _inAirports,
    'sri_lankan': _asianAirports,
    'nepalese': _himalayanAirports, 
    'himalayan': _himalayanAirports, 
    'tibetan': _himalayanAirports,
    'burmese': _asianAirports,
    'cambodian': _khAirports,
    'indonesian': _asianAirports,
    'malaysian': _myAirports,
    'taiwanese': _twAirports,
    'uyghur': _uyghurAirports,

    // --- Central Asia & Middle East ---
    'afghan': _asianAirports, 
    'persian': _meAirports,
    'middle_eastern': _meAirports, 
    'turkish': _meAirports, 
    'kebab': _meAirports, 
    'doner': _meAirports, 
    'falafel': _meAirports,
    'lebanese': _lbAirports,
    'israeli': _ilAirports,
    'yemeni': _arabAirports, 
    'egyptian': _arabAirports,

    // --- Latin America & Caribbean ---
    'brazilian': _brAirports,
    'mexican': _mxAirports, 
    'tex-mex': _mxAirports, 
    'taco': _mxAirports,
    'colombian': _coAirports,
    'argentinian': _latamAirports, 
    'uruguayan': _latamAirports,
    'peruvian': _latamAirports, 
    'ecuadorian': _latamAirports,
    'venezuelan': _latamAirports,
    'salvadoran': _latamAirports, 
    'salvadorian': _latamAirports, 
    'guatemalan': _latamAirports, 
    'honduran': _latamAirports,
    'hispanic': _latamAirports, 
    'latin': _latamAirports,
    'jamaican': _jmAirports,
    'dominican': _doAirports,
    'cuban': _cuAirports,
    'guyanese': _gyAirports,
    'caribbean': _caribbeanAirports, 
    'puerto_rican': _caribbeanAirports, 
    'trinidadian': _caribbeanAirports, 
    'haitian': _caribbeanAirports,

    // --- Africa ---
    'ethiopian': _africanAirports,
    'senegalese': _westAfricanAirports,
    'nigerian': _westAfricanAirports,
    'west_african': _westAfricanAirports,
    'african': _africanAirports,
    'moroccan': _africanAirports,

    // --- Specialized NYC & Global Fallbacks ---
    'hawaiian': _hawaiianAirports, 
    'poke': _hawaiianAirports,
    
    // We map Jewish Delis and Bagels heavily to NYC/TLV airports because of strong NYC appetizing culture
    'deli': _jewishAirports, 
    'bagel': _jewishAirports, 

    // General Food / Vibes (Fallbacks)
    'default': _defaultAirports,
    'cafe': _defaultAirports, 
    'bakery': _defaultAirports, 
    'pastry': _defaultAirports, 
    'crepe': _defaultAirports, 
    'crepes': _defaultAirports,
    'coffee': _defaultAirports, 
    'bar': _defaultAirports, 
    'pub': _defaultAirports, 
    'gastropub': _defaultAirports, 
    'wine': _defaultAirports, 
    'cocktail': _defaultAirports,
    'healthy': _defaultAirports, 
    'salad': _defaultAirports, 
    'health_food': _defaultAirports, 
    'vegan': _defaultAirports,
    'sandwich': _defaultAirports, 
    'seafood': _defaultAirports, 
    'fish': _defaultAirports, 
    'soup': _defaultAirports, 
    'buffet': _defaultAirports, 
    'fine_dining': _defaultAirports, 
    'regional': _defaultAirports,
    'breakfast': _defaultAirports, 
    'brunch': _defaultAirports, 
    'international': _defaultAirports, 
    'eclectic': _defaultAirports, 
    'continental': _defaultAirports,
    'bubble_tea': _defaultAirports, 
    'bubble tea': _defaultAirports, 
    'juice': _defaultAirports, 
    'smoothie': _defaultAirports, 
    'açaí': _defaultAirports, 
    'snack': _defaultAirports, 
    'donut': _defaultAirports, 
    'ice cream': _defaultAirports, 
    'frozen_yogurt': _defaultAirports, 
    'dessert': _defaultAirports, 
    'cookie': _defaultAirports, 
    'pretzel': _defaultAirports,

    // --- Add under Americana / Global ---
    'australian': _auAirports,

    // --- Add under Europe ---
    'mediterranean': _medAirports,

    // --- Add under Asia ---
    'hong_kong': _hkAirports,

    // --- Add under Central Asia & Middle East ---
    'kazakh': _kzAirports,
    'uzbek': _uzAirports,
    'syrian': _syAirports,
    'druze': _druzeAirports,
  };

  // ===========================================================================
  // 🏙️ 5. BILINGUAL CITY NAMES (For Baggage Tags)
  // Native Language / English Name
  // ===========================================================================
  static const Map<String, String> airportCityNames = {
    // --- USA ---
    'JFK': 'New York', 'LGA': 'New York', 'EWR': 'Newark', 'LAX': 'Los Angeles',
    'ORD': 'Chicago', 'ATL': 'Atlanta', 'MIA': 'Miami', 'SFO': 'San Francisco',
    'DFW': 'Dallas', 'SEA': 'Seattle', 'MSY': 'New Orleans', 'BNA': 'Nashville',
    'CHS': 'Charleston', 'MEM': 'Memphis', 'SAV': 'Savannah', 'AUS': 'Austin',
    'HNL': 'Honolulu', 'OGG': 'Kahului', 'KOA': 'Kailua-Kona', 'LIH': 'Līhuʻe', 'ITO': 'Hilo',
    // --- Europe ---
    'CDG': 'Paris', 'ORY': 'Paris', 'NCE': 'Nice', 'LYS': 'Lyon', 'MRS': 'Marseille', 'TLS': 'Toulouse', 'BOD': 'Bordeaux',
    'FCO': 'Roma / Rome', 'MXP': 'Milano / Milan', 'VCE': 'Venezia / Venice', 'NAP': 'Napoli / Naples', 'BLQ': 'Bologna', 'PMO': 'Palermo', 'CTA': 'Catania', 'LIN': 'Milano / Milan',
    'MAD': 'Madrid', 'BCN': 'Barcelona', 'PMI': 'Palma de Mallorca', 'AGP': 'Málaga', 'ALC': 'Alicante', 'TFS': 'Tenerife', 'VLC': 'Valencia',
    'LHR': 'London', 'DUB': 'Baile Átha Cliath / Dublin', 'ORK': 'Corcaigh / Cork', 'SNN': 'Sionna / Shannon', 'NOC': 'Cnoc Mhuire / Knock',
    'ATH': 'Αθήνα / Athens', 'SKG': 'Θεσσαλονίκη / Thessaloniki', 'HER': 'Ηράκλειο / Heraklion', 'RHO': 'Ρόδος / Rhodes', 'CFU': 'Κέρκυρα / Corfu', 'JMK': 'Μύκονος / Mykonos', 'JTR': 'Σαντορίνη / Santorini',
    'LIS': 'Lisboa / Lisbon', 'OPO': 'Porto', 'FAO': 'Faro', 'FNC': 'Funchal', 'PDL': 'Ponta Delgada',
    'WAW': 'Warszawa / Warsaw', 'KRK': 'Kraków / Cracow', 'GDN': 'Gdańsk', 'KTW': 'Katowice', 'WRO': 'Wrocław',
    'CPH': 'København / Copenhagen', 'OSL': 'Oslo', 'ARN': 'Stockholm', 'HEL': 'Helsinki', 'KEF': 'Reykjavík', 'BGO': 'Bergen', 'GOT': 'Göteborg / Gothenburg',
    'MLA': 'Malta', 'LCA': 'Larnaca', 'PFO': 'Paphos', 'CAG': 'Cagliari', 'IBZ': 'Ibiza',
    // --- Asia ---
    'NRT': '東京 / Tokyo', 'HND': '東京 / Tokyo', 'KIX': '大阪 / Osaka', 'ITM': '大阪 / Osaka', 'CTS': '札幌 / Sapporo', 'FUK': '福岡 / Fukuoka', 'OKA': '那覇 / Naha', 'NGO': '名古屋 / Nagoya',
    'PEK': '北京 / Beijing', 'PVG': '上海 / Shanghai', 'CAN': '广州 / Guangzhou', 'CTU': '成都 / Chengdu', 'SZX': '深圳 / Shenzhen', 'KMG': '昆明 / Kunming', 'XIY': '西安 / Xi\'an', 'HGH': '杭州 / Hangzhou',
    'HKG': '香港 / Hong Kong', 'MFM': '澳門 / Macau', 'ZUH': '珠海 / Zhuhai',
    'TPE': '台北 / Taipei', 'KHH': '高雄 / Kaohsiung', 'TSA': '台北 / Taipei', 'RMQ': '台中 / Taichung', 'TNN': '台南 / Tainan',
    'ICN': '서울 / Seoul', 'GMP': '서울 / Seoul', 'CJU': '제주 / Jeju', 'PUS': '부산 / Busan', 'TAQ': '대구 / Daegu',
    'BKK': 'กรุงเทพมหานคร / Bangkok', 'DMK': 'กรุงเทพมหานคร / Bangkok', 'HKT': 'ภูเก็ต / Phuket', 'CNX': 'เชียงใหม่ / Chiang Mai', 'USM': 'เกาะสมุย / Koh Samui', 'KBV': 'กระบี่ / Krabi',
    'SGN': 'Hồ Chí Minh / Ho Chi Minh City', 'HAN': 'Hà Nội / Hanoi', 'DAD': 'Đà Nẵng / Da Nang', 'CXR': 'Nha Trang', 'PQC': 'Phú Quốc', 'HPH': 'Hải Phòng / Hai Phong',
    'MNL': 'Maynila / Manila', 'CEB': 'Cebu', 'DVO': 'Davao', 'CRK': 'Angeles / Clark', 'ILO': 'Iloilo',
    'KUL': 'Kuala Lumpur', 'PEN': 'Pulau Pinang / Penang', 'BKI': 'Kota Kinabalu', 'KCH': 'Kuching', 'JHB': 'Johor Bahru',
    'SIN': 'Singapore', 'PNH': 'ភ្នំពេញ / Phnom Penh', 'REP': 'ក្រុងសៀមរាប / Siem Reap', 'KOS': 'ក្រុងព្រះសីហនុ / Sihanoukville',
    'DEL': 'नई दिल्ली / New Delhi', 'BOM': 'मुंबई / Mumbai', 'BLR': 'ಬೆಂಗಳೂರು / Bangalore', 'HYD': 'హైదరాబాద్ / Hyderabad', 'MAA': 'சென்னை / Chennai', 'CCU': 'কলকাতা / Kolkata', 'COK': 'കൊച്ചി / Kochi', 'AMD': 'અમદાવાદ / Ahmedabad',
    'KTM': 'काठमाडौं / Kathmandu', 'PBH': 'སྤ་རོ་ / Paro', 'LXA': 'ལྷ་ས་ / Lhasa', 'IXB': 'Siliguri / Bagdogra', 'SXR': 'سِری نَگَر / Srinagar',
    'ALA': 'Алматы / Almaty', 'NQZ': 'Астана / Astana', 'CIT': 'Шымкент / Shymkent', 'KGF': 'Қарағанды / Karaganda', 'GUW': 'Атырау / Atyrau',
    'TAS': 'Toshkent / Tashkent', 'SKD': 'Samarqand / Samarkand', 'NMA': 'Namangan', 'BHK': 'Buxoro / Bukhara', 'FEG': 'Fargʻona / Fergana',
    'URC': 'ئۈرۈمچى / Ürümqi', 'KHG': 'قەشقەر / Kashgar', 'KCA': 'كۇچار / Kuqa', 'HTN': 'خوتەن / Hotan',
    // --- Middle East & Africa ---
    'DXB': 'دبي / Dubai', 'AUH': 'أبو ظبي / Abu Dhabi', 'DOH': 'الدوحة / Doha', 'RUH': 'الرياض / Riyadh', 'JED': 'جدة / Jeddah', 'KWI': 'الكويت / Kuwait', 'MCT': 'مسقط / Muscat', 'BAH': 'البحرين / Bahrain',
    'TLV': 'תל אביב / Tel Aviv', 'ETM': 'אילת / Eilat', 'HFA': 'חיפה / Haifa',
    'BEY': 'بيروت / Beirut', 'AMM': 'عمان / Amman', 'DAM': 'دمشق / Damascus', 'ALP': 'حلب / Aleppo', 'LTK': 'اللاذقية / Latakia',
    'JNB': 'Johannesburg', 'CPT': 'Cape Town', 'NBO': 'Nairobi', 'ADD': 'Addis Ababa', 'LOS': 'Lagos', 'ACC': 'Accra', 'DKR': 'Dakar', 'KGL': 'Kigali',
    'ABJ': 'Abidjan', 'FNA': 'Freetown', 'BKO': 'Bamako', 'OXB': 'Bissau',
    // --- Latin America & Caribbean ---
    'MEX': 'Ciudad de México / Mexico City', 'CUN': 'Cancún', 'GDL': 'Guadalajara', 'MTY': 'Monterrey', 'SJD': 'San José del Cabo', 'PVR': 'Puerto Vallarta', 'TIJ': 'Tijuana',
    'GRU': 'São Paulo', 'GIG': 'Rio de Janeiro', 'BSB': 'Brasília', 'CNF': 'Belo Horizonte', 'SSA': 'Salvador', 'FOR': 'Fortaleza', 'REC': 'Recife', 'POA': 'Porto Alegre',
    'BOG': 'Bogotá', 'MDE': 'Medellín', 'CLO': 'Cali', 'CTG': 'Cartagena', 'BAQ': 'Barranquilla',
    'HAV': 'La Habana / Havana', 'VRA': 'Varadero', 'SCU': 'Santiago de Cuba', 'HOG': 'Holguín', 'SNU': 'Santa Clara',
    'SDQ': 'Santo Domingo', 'PUJ': 'Punta Cana', 'STI': 'Santiago', 'POP': 'Puerto Plata', 'LRM': 'La Romana',
    'PTY': 'Panamá / Panama City', 'LIM': 'Lima', 'SCL': 'Santiago', 'EZE': 'Buenos Aires', 'UIO': 'Quito', 'MVD': 'Montevideo',
    'NAS': 'Nassau', 'SJU': 'San Juan', 'BGI': 'Bridgetown', 'POS': 'Port of Spain', 'SXM': 'Sint Maarten', 'ANU': 'Antigua', 'GCM': 'Grand Cayman',
    'KIN': 'Kingston', 'MBJ': 'Montego Bay', 'OCJ': 'Ocho Rios',
    'GEO': 'Georgetown', 'OGL': 'Ogle',
    // --- Oceania ---
    'SYD': 'Sydney', 'MEL': 'Melbourne', 'BNE': 'Brisbane', 'PER': 'Perth', 'ADL': 'Adelaide', 'CBR': 'Canberra', 'HBA': 'Hobart', 'DRW': 'Darwin',
  };

}