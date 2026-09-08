/// Utility to convert English Quranic transliterations to Bengali pronunciation (বাংলা উচ্চারণ).
class BengaliPhoneticHelper {
  BengaliPhoneticHelper._();

  static final Map<String, String> _wordOverrides = {
    'bismillah': 'বিসমিল্লাহ',
    'bismillaahi': 'বিসমিল্লাহি',
    'bismillaahir': 'বিসমিল্লাহির',
    'rahmaanir': 'রাহমানির',
    'rahmaani': 'রাহমানি',
    'rahmaan': 'রাহমান',
    'rahman': 'রাহমান',
    'raheem': 'রাহীম',
    'ar-rahmaanir-raheem': 'আর-রাহমানির-রাহীম',
    'ar-rahmaan': 'আর-রাহমান',
    'ar-raheem': 'আর-রাহীম',
    'alhamdu': 'আলহামদু',
    'lillah': 'লিল্লাহ',
    'lillaahi': 'লিল্লাহি',
    'lillahi': 'লিল্লাহি',
    'rabbil': 'রাব্বিল',
    'rabbi': 'রব্বি',
    'aalameen': 'আলামীন',
    'alameen': 'আলামীন',
    'maaliki': 'মালিকি',
    'maliki': 'মালিকি',
    'yawmid-deen': 'ইয়াওমিদ-দ্বীন',
    'yawmideen': 'ইয়াওমিদ-দ্বীন',
    'iyyaaka': 'ইয়্যাকা',
    'iyyaka': 'ইয়্যাকা',
    'na\'budu': 'না\'বুদু',
    'nabudu': 'না\'বুদু',
    'wa': 'ওয়া',
    'nasta\'een': 'নাস্তা\'ঈন',
    'nastaeen': 'নাস্তা\'ঈন',
    'ihdinas-siraat': 'ইহদিনাস-সিরাত',
    'ihdinas-siraatal-mustaqeem': 'ইহদিনাস-সিরাতাল-মুস্তাক্বীম',
    'mustaqeem': 'মুস্তাক্বীম',
    'siraata': 'সিরাতা',
    'siraatal-lazeena': 'সিরাতাল-লাযীনা',
    'lazeena': 'লাযীনা',
    'an\'amta': 'আন\'আমতা',
    'anamta': 'আন\'আমতা',
    'alayhim': 'আলাইহিম',
    'ghayril-maghdoobi': 'গাইরিল-মাগদূবি',
    'maghdoobi': 'মাগদূবি',
    'ghayril': 'গাইরিল',
    'ghayri': 'গাইরি',
    'walad-daalleen': 'ওয়ালাদ-দ্বাল্লীন',
    'daalleen': 'দ্বাল্লীন',
    'qul': 'কুল',
    'huwal': 'হুয়াল',
    'laahu': 'লাহু',
    'laaha': 'লাহা',
    'laahi': 'লাহি',
    'ahad': 'আহাদ',
    'allaahus-samad': 'আল্লাহুস-সামাদ',
    'allahus-samad': 'আল্লাহুস-সামাদ',
    'samad': 'সামাদ',
    'lam': 'লাম',
    'yalid': 'য়ালিদ',
    'yoolad': 'য়ূলাদ',
    'yakul-lahoo': 'য়াকুল-লাহু',
    'kufuwan': 'কুফুওয়ান',
    'a\'oozu': 'আ\'ঊযু',
    'falaq': 'ফালাক্ব',
    'min': 'মিন',
    'sharri': 'শাররি',
    'ma': 'মা',
    'khalaq': 'খালাক্ব',
    'ghasiqin': 'গাসিক্বিন',
    'waqab': 'ওয়াক্বাব',
    'naffaasaati': 'নাফ্ফাসাতি',
    'uqad': 'উকাদ্',
    'haasidin': 'হাসিদিন',
    'hasad': 'হাসাদ',
    'an-naas': 'আন-নাস',
    'malikin-naas': 'মালিকিন-নাস',
    'ilaahin-naas': 'ইলাহিন-নাস',
    'waswaasil-khannaas': 'ওয়াসওয়াসিল-খান্নাস',
    'khannaas': 'খান্নাস',
    'sudoorin-naas': 'সুদূরিন-নাস',
    'jinnati': 'জিন্নাহ',
    'subhanallah': 'সুবহানাল্লাহ',
    'alhamdulillah': 'আলহামদুলিল্লাহ',
    'allahu': 'আল্লাহু',
    'akbar': 'আকবার',
    'astaghfirullah': 'আস্তাগফিরুল্লাহ',
    'la': 'লা',
    'ilaha': 'ইলাহা',
    'illallah': 'ইল্লাল্লাহ',
    'muhammadur': 'মুহাম্মাদুর',
    'rasoolullah': 'রাসূলুল্লাহ',
  };

  /// Converts English Quranic transliteration to Bengali pronunciation.
  static String toBengaliPronunciation(String englishTransliteration) {
    if (englishTransliteration.trim().isEmpty) return '';

    final words = englishTransliteration.split(' ');
    final convertedWords = words.map((word) {
      final cleanWord = word.replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '').toLowerCase();
      if (_wordOverrides.containsKey(cleanWord)) {
        // Keep punctuation if any
        final prefix = word.startsWith('(') ? '(' : '';
        final suffix = word.endsWith(')') ? ')' : (word.endsWith(',') ? ',' : (word.endsWith('.') ? '.' : ''));
        return '$prefix${_wordOverrides[cleanWord]}$suffix';
      }
      return _transliteratePhoneticWord(word);
    }).toList();

    return convertedWords.join(' ');
  }

  static String _transliteratePhoneticWord(String word) {
    var s = word;

    final replacements = <String, String>{
      'Bismillah': 'বিসমিল্লাহ',
      'bismillah': 'বিসমিল্লাহ',
      'Allah': 'আল্লাহ',
      'allah': 'আল্লাহ',
      'llaah': 'ল্লাহ',
      'llah': 'ল্লাহ',
      'sh': 'শ',
      'Sh': 'শ',
      'th': 'ছ',
      'Th': 'ছ',
      'kh': 'খ',
      'Kh': 'খ',
      'gh': 'গ',
      'Gh': 'গ',
      'dh': 'য',
      'Dh': 'য',
      'zh': 'য',
      'aa': 'া',
      'ee': 'ী',
      'oo': 'ূ',
      'ii': 'ী',
      'uu': 'ূ',
      'a': 'া',
      'i': 'ি',
      'u': 'ু',
      'e': 'ে',
      'o': 'ো',
      'b': 'ব',
      'B': 'ব',
      't': 'ত',
      'T': 'ত',
      'j': 'জ',
      'J': 'জ',
      'h': 'হ',
      'H': 'হ',
      'd': 'দ',
      'D': 'দ',
      'r': 'র',
      'R': 'র',
      'z': 'য',
      'Z': 'য',
      's': 'স',
      'S': 'স',
      'f': 'ফ',
      'F': 'ফ',
      'q': 'ক্ব',
      'Q': 'ক্ব',
      'k': 'ক',
      'K': 'ক',
      'l': 'ল',
      'L': 'ল',
      'm': 'ম',
      'M': 'ম',
      'n': 'ন',
      'N': 'ন',
      'w': 'ওয়',
      'W': 'ওয়',
      'y': 'য়',
      'Y': 'য়',
      '\'': '\'',
      '-': '-',
    };

    var result = '';
    var i = 0;
    final lower = s.toLowerCase();

    while (i < s.length) {
      if (i + 2 <= s.length) {
        final pair = lower.substring(i, i + 2);
        if (replacements.containsKey(pair)) {
          if (i == 0) {
            result += _toIndependentVowel(pair) ?? replacements[pair]!;
          } else {
            result += replacements[pair]!;
          }
          i += 2;
          continue;
        }
      }

      final ch = lower.substring(i, i + 1);
      if (replacements.containsKey(ch)) {
        if (i == 0) {
          result += _toIndependentVowel(ch) ?? replacements[ch]!;
        } else {
          result += replacements[ch]!;
        }
      } else {
        result += s[i];
      }
      i++;
    }

    return result;
  }

  static String? _toIndependentVowel(String v) {
    switch (v) {
      case 'a':
      case 'aa':
        return 'আ';
      case 'i':
      case 'ee':
      case 'ii':
        return 'ই';
      case 'u':
      case 'oo':
      case 'uu':
        return 'উ';
      case 'e':
        return 'এ';
      case 'o':
        return 'ও';
      default:
        return null;
    }
  }
}
