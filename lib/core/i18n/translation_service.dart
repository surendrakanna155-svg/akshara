import 'school_content_translation_catalog.dart';
import 'supported_languages.dart';

/// Dictionary-backed translation pipeline — no LLM, no prefix stubs.
///
/// Templates are authored in English; this service resolves pre-translated
/// equivalents from the bundled phrase catalog.
class TranslationService {
  const TranslationService();

  static const TranslationService instance = TranslationService();

  String translate({
    required String englishText,
    required AksharaLanguage target,
  }) {
    if (target == AksharaLanguage.english) return englishText;
    final key = _normalizeKey(englishText);
    return _catalog[key]?[target] ?? englishText;
  }

  TranslatedMessagePair pair({
    required String englishText,
    required AksharaLanguage target,
  }) {
    return TranslatedMessagePair(
      original: englishText,
      translated: translate(englishText: englishText, target: target),
      targetLanguage: target,
    );
  }

  String _normalizeKey(String text) => text.trim();

  static final Map<String, Map<AksharaLanguage, String>> _catalog = {
    ...SchoolContentTranslationCatalog.entries,
    'Your child was absent from school today. Kindly ensure regular attendance and inform the school if there are any concerns.':
        {
      AksharaLanguage.telugu:
          'మీ పిల్లవాడు ఈరోజు పాఠశాలకు రాలేదు. దయచేసి క్రమం తప్పకుండా హాజరు కావాలని నిర్ధారించండి.',
      AksharaLanguage.hindi:
          'आपका बच्चा आज स्कूल में अनुपस्थित था। कृपया नियमित उपस्थिति सुनिश्चित करें।',
      AksharaLanguage.tamil:
          'உங்கள் குழந்தை இன்று பள்ளிக்கு வரவில்லை. தயவுசெய்து வழக்கமான வருகையை உறுதிசெய்யுங்கள்.',
      AksharaLanguage.kannada:
          'ನಿಮ್ಮ ಮಗು ಇಂದು ಶಾಲೆಗೆ ಬರಲಿಲ್ಲ. ದಯವಿಟ್ಟು ನಿಯಮಿತ ಹಾಜರಾತಿಯನ್ನು ಖಚಿತಪಡಿಸಿ.',
      AksharaLanguage.malayalam:
          'നിങ്ങളുടെ കുട്ടി ഇന്ന് സ്കൂളിൽ ഹാജരായില്ല. ദയവായി നിയമിത ഹാജരാകൽ ഉറപ്പാക്കുക.',
      AksharaLanguage.urdu:
          'آپ کا بچہ آج اسکول میں غیر حاضر تھا۔ براہ کرم باقاعدہ حاضری یقینی بنائیں۔',
    },
    'We noticed your child was absent today. Regular attendance is important for academic progress.':
        {
      AksharaLanguage.telugu:
          'మీ పిల్లవాడు ఈరోజు హాజరు కాలేదని మేము గమనించాము. క్రమం తప్పకుండా హాజరు అకాడమిక్ పురోగతికి ముఖ్యం.',
      AksharaLanguage.hindi:
          'हमने देखा कि आपका बच्चा आज अनुपस्थित था। नियमित उपस्थिति शैक्षणिक प्रगति के लिए महत्वपूर्ण है।',
      AksharaLanguage.tamil:
          'உங்கள் குழந்தை இன்று வரவில்லை என்பதைக் கவனித்தோம். வழக்கமான வருகை கல்வி முன்னேற்றத்திற்கு முக்கியம்.',
      AksharaLanguage.kannada:
          'ನಿಮ್ಮ ಮಗು ಇಂದು ಗೈರುಹಾಜರಾಗಿದೆ ಎಂದು ನಾವು ಗಮನಿಸಿದ್ದೇವೆ. ನಿಯಮಿತ ಹಾಜರಾತಿ ಶೈಕ್ಷಣಿಕ ಪ್ರಗತಿಗೆ ಮುಖ್ಯ.',
      AksharaLanguage.malayalam:
          'നിങ്ങളുടെ കുട്ടി ഇന്ന് ഹാജരായില്ലെന്ന് ഞങ്ങൾ ശ്രദ്ധിച്ചു. നിയമിത ഹാജരാകൽ അക്കാദമിക് പുരോഗതിക്ക് പ്രധാനമാണ്.',
      AksharaLanguage.urdu:
          'ہم نے دیکھا کہ آپ کا بچہ آج غیر حاضر تھا۔ باقاعدہ حاضری تعلیمی ترقی کے لیے اہم ہے۔',
    },
    'Your child\'s recent assessment score needs attention. We encourage additional practice at home.':
        {
      AksharaLanguage.telugu:
          'మీ పిల్లవాడి ఇటీవలి అంచనా స్కోర్‌కు శ్రద్ధ అవసరం. ఇంటిలో అదనపు అభ్యాసం చేయమని మేము ప్రోత్సహిస్తున్నాము.',
      AksharaLanguage.hindi:
          'आपके बच्चे के हालिया मूल्यांकन अंक पर ध्यान देने की आवश्यकता है। हम घर पर अतिरिक्त अभ्यास करने की सलाह देते हैं।',
      AksharaLanguage.tamil:
          'உங்கள் குழந்தையின் சமீபத்திய மதிப்பீட்டு மதிப்பெண்களுக்கு கவனம் தேவை. வீட்டில் கூடுதல் பயிற்சி செய்ய ஊக்குவிக்கிறோம்.',
      AksharaLanguage.kannada:
          'ನಿಮ್ಮ ಮಗುವಿನ ಇತ್ತೀಚಿನ ಮೌಲ್ಯಮಾಪನ ಅಂಕಕ್ಕೆ ಗಮನ ಅಗತ್ಯವಿದೆ. ಮನೆಯಲ್ಲಿ ಹೆಚ್ಚುವರಿ ಅಭ್ಯಾಸ ಮಾಡಲು ಪ್ರೋತ್ಸಾಹಿಸುತ್ತೇವೆ.',
      AksharaLanguage.malayalam:
          'നിങ്ങളുടെ കുട്ടിയുടെ സമീപകാല മൂല്യനിർണയ സ്കോറിന് ശ്രദ്ധ ആവശ്യമാണ്. വീട്ടിൽ അധിക പരിശീലനം ചെയ്യാൻ ഞങ്ങൾ പ്രോത്സാഹിപ്പിക്കുന്നു.',
      AksharaLanguage.urdu:
          'آپ کے بچے کے حالیہ جائزے کے نمبروں پر توجہ درکار ہے۔ ہم گھر پر اضافی مشق کی حوصلہ افزائی کرتے ہیں۔',
    },
    'Homework for today has not been submitted. Kindly ensure completion by tomorrow.':
        {
      AksharaLanguage.telugu:
          'ఈరోజు హోమ్‌వర్క్ సమర్పించబడలేదు. రేపటికి పూర్తి చేయడం నిర్ధారించండి.',
      AksharaLanguage.hindi:
          'आज का होमवर्क जमा नहीं किया गया। कृपया कल तक पूरा करना सुनिश्चित करें।',
      AksharaLanguage.tamil:
          'இன்றைய வீட்டுப்பாடம் சமர்ப்பிக்கப்படவில்லை. நாளைக்குள் முடிக்க உறுதிசெய்யுங்கள்.',
      AksharaLanguage.kannada:
          'ಇಂದಿನ ಗೃಹಪಾಠ ಸಲ್ಲಿಸಲಾಗಿಲ್ಲ. ನಾಳೆಗೆ ಪೂರ್ಣಗೊಳಿಸಲು ಖಚಿತಪಡಿಸಿ.',
      AksharaLanguage.malayalam:
          'ഇന്നത്തെ ഹോംവർക്ക് സമർപ്പിച്ചിട്ടില്ല. നാളെ പൂർത്തിയാക്കാൻ ഉറപ്പാക്കുക.',
      AksharaLanguage.urdu:
          'آج کا ہوم ورک جمع نہیں ہوا۔ براہ کرم کل تک مکمل کرنا یقینی بنائیں۔',
    },
    'We would like to appreciate your child\'s excellent performance in class today.':
        {
      AksharaLanguage.telugu:
          'మీ పిల్లవాడు ఈరోజు తరగతిలో అద్భుతంగా ప్రదర్శించాడని మేము అభినందిస్తున్నాము.',
      AksharaLanguage.hindi:
          'हम आपके बच्चे की आज की कक्षा में उत्कृष्ट प्रदर्शन की सराहना करना चाहते हैं।',
      AksharaLanguage.tamil:
          'உங்கள் குழந்தை இன்று வகுப்பில் சிறந்து விளங்கியதைப் பாராட்ட விரும்புகிறோம்.',
      AksharaLanguage.kannada:
          'ನಿಮ್ಮ ಮಗು ಇಂದು ತರಗತಿಯಲ್ಲಿ ಅತ್ಯುತ್ತಮ ಪ್ರದರ್ಶನ ನೀಡಿದ್ದಕ್ಕಾಗಿ ನಾವು ಅಭಿನಂದಿಸುತ್ತೇವೆ.',
      AksharaLanguage.malayalam:
          'നിങ്ങളുടെ കുട്ടി ഇന്ന് ക്ലാസിൽ മികച്ച പ്രകടനം കാഴ്ചവച്ചതിന് ഞങ്ങൾ അഭിനന്ദിക്കുന്നു.',
      AksharaLanguage.urdu:
          'ہم آپ کے بچے کی آج کلاس میں بہترین کارکردگی کی تعریف کرنا چاہتے ہیں۔',
    },
    'This is a friendly reminder that school fees are due soon. Kindly complete payment at your earliest convenience.':
        {
      AksharaLanguage.telugu:
          'పాఠశాల ఫీజులు త్వరలో చెల్లించాలని ఇది సౌజన్యపూర్వక రిమైండర్.',
      AksharaLanguage.hindi:
          'यह एक सौम्य अनुस्मारक है कि स्कूल की फीस जल्द देय है। कृपया शीघ्र भुगतान करें।',
      AksharaLanguage.tamil:
          'பள்ளி கட்டணம் விரைவில் செலுத்த வேண்டும் என்பதற்கான நட்பு நினைவூட்டல் இது.',
      AksharaLanguage.kannada:
          'ಶಾಲಾ ಶುಲ್ಕ ಶೀಘ್ರದಲ್ಲೇ ಬಾಕಿ ಇದೆ ಎಂಬ ಸೌಮ್ಯ ಜ್ಞಾಪನೆ ಇದು.',
      AksharaLanguage.malayalam:
          'സ്കൂൾ ഫീസ് ഉടൻ അടയ്ക്കേണ്ടതാണ് എന്ന ഈ സൗഹൃദ ഓർമ്മപ്പെടുത്തൽ.',
      AksharaLanguage.urdu:
          'یہ ایک دوستانہ یاد دہانی ہے کہ اسکول کی فیس جلد واجب الادا ہے۔',
    },
  };
}

class TranslatedMessagePair {
  const TranslatedMessagePair({
    required this.original,
    required this.translated,
    required this.targetLanguage,
  });

  final String original;
  final String translated;
  final AksharaLanguage targetLanguage;

  /// Body shown to parent in their preferred language.
  String get parentFacingBody => translated;

  /// Body stored for teacher audit with both languages.
  String get auditBody => '$original\n\n[${targetLanguage.displayName}] $translated';
}
