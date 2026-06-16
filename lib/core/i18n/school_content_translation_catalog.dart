import 'supported_languages.dart';

/// Dictionary entries for notices, homework, announcements, and PTM content.
abstract final class SchoolContentTranslationCatalog {
  static Map<String, Map<AksharaLanguage, String>> get entries => _entries;

  static final Map<String, Map<AksharaLanguage, String>> _entries = {
  // Notices
  'PTM scheduled for 15 June — please confirm your slot': {
    AksharaLanguage.telugu:
        '15 జూన్‌న PTM షెడ్యూల్ చేయబడింది — దయచేసి మీ స్లాట్‌ను నిర్ధారించండి',
    AksharaLanguage.hindi:
        '15 जून के लिए PTM निर्धारित — कृपया अपना स्लॉट पुष्टि करें',
    AksharaLanguage.tamil:
        '15 ஜூன் PTM திட்டமிடப்பட்டுள்ளது — உங்கள் நேரத்தை உறுதிப்படுத்துங்கள்',
    AksharaLanguage.kannada:
        '15 ಜೂನ್‌ಗೆ PTM ನಿಗದಿ — ದಯವಿಟ್ಟು ನಿಮ್ಮ ಸ್ಲಾಟ್ ದೃಢೀಕರಿಸಿ',
    AksharaLanguage.malayalam:
        '15 ജൂണിന് PTM ഷെഡ്യൂൾ ചെയ്തു — ദയവായി നിങ്ങളുടെ സ്ലോട്ട് സ്ഥിരീകരിക്കുക',
    AksharaLanguage.urdu:
        '15 جون کے لیے PTM طے — براہ کرم اپنا سلاٹ تصدیق کریں',
  },
  'Parent-teacher meetings will run in 15-minute slots between 2:00 PM and 6:00 PM.':
      {
    AksharaLanguage.telugu:
        'పేరెంట్-టీచర్ సమావేశాలు మధ్యాహ్నం 2:00 నుండి 6:00 వరకు 15 నిమిషాల స్లాట్‌లలో జరుగుతాయి.',
    AksharaLanguage.hindi:
        'अभिभावक-शिक्षक बैठकें दोपहर 2:00 से 6:00 बजे तक 15 मिनट के स्लॉट में होंगी।',
    AksharaLanguage.tamil:
        'பெற்றோர்-ஆசிரியர் கூட்டங்கள் மதியம் 2:00 முதல் 6:00 வரை 15 நிமிட இடைவெளியில் நடைபெறும்.',
    AksharaLanguage.kannada:
        'ಪೋಷಕ-ಶಿಕ್ಷಕ ಸಭೆಗಳು ಮಧ್ಯಾಹ್ನ 2:00 ರಿಂದ 6:00 ವರೆಗೆ 15 ನಿಮಿಷದ ಸ್ಲಾಟ್‌ಗಳಲ್ಲಿ ನಡೆಯುತ್ತವೆ.',
    AksharaLanguage.malayalam:
        'രക്ഷിതാവ്-അധ്യാപക സമ്മേളനങ്ങൾ ഉച്ചയ്ക്ക് 2:00 മുതൽ 6:00 വരെ 15 മിനിറ്റ് സ്ലോട്ടുകളിൽ നടക്കും.',
    AksharaLanguage.urdu:
        'والدین-استاد میٹنگز دوپہر 2:00 سے 6:00 تک 15 منٹ کے سلاٹ میں ہوں گی۔',
  },
  'Summer vacation dates announced': {
    AksharaLanguage.telugu: 'వేసవి సెలవుల తేదీలు ప్రకటించబడ్డాయి',
    AksharaLanguage.hindi: 'ग्रीष्मकालीन अवकाश की तिथियां घोषित',
    AksharaLanguage.tamil: 'கோடை விடுமுறை தேதிகள் அறிவிக்கப்பட்டன',
    AksharaLanguage.kannada: 'ಬೇಸಿಗೆ ರಜೆ ದಿನಾಂಕಗಳು ಪ್ರಕಟಿಸಲಾಗಿದೆ',
    AksharaLanguage.malayalam: 'വേനൽ അവധി തീയതികൾ പ്രഖ്യാപിച്ചു',
    AksharaLanguage.urdu: 'گرمیوں کی چھٹیوں کی تاریخیں اعلان',
  },
  'School closes from 1 Jul to 15 Jul. First day back is 16 Jul.': {
    AksharaLanguage.telugu:
        'పాఠశాల 1 జులై నుండి 15 జులై వరకు మూసివేయబడుతుంది. మొదటి రోజు 16 జులై.',
    AksharaLanguage.hindi:
        'स्कूल 1 जुलाई से 15 जुलाई तक बंद। पहला दिन 16 जुलाई।',
    AksharaLanguage.tamil:
        'பள்ளி ஜூலை 1 முதல் 15 வரை மூடப்படும். முதல் நாள் ஜூலை 16.',
    AksharaLanguage.kannada:
        'ಶಾಲೆ ಜುಲೈ 1 ರಿಂದ 15 ವರೆಗೆ ಮುಚ್ಚಲಾಗುತ್ತದೆ. ಮೊದಲ ದಿನ ಜುಲೈ 16.',
    AksharaLanguage.malayalam:
        'സ്കൂൾ ജൂലൈ 1 മുതൽ 15 വരെ അടയ്ക്കും. ആദ്യ ദിവസം ജൂലൈ 16.',
    AksharaLanguage.urdu:
        'اسکول 1 جولائی سے 15 جولائی تک بند۔ پہلا دن 16 جولائی۔',
  },
  'New transport route effective Monday': {
    AksharaLanguage.telugu: 'కొత్త ట్రాన్స్‌పోర్ట్ మార్గం సోమవారం నుండి అమలులోకి',
    AksharaLanguage.hindi: 'नया परिवहन मार्ग सोमवार से प्रभावी',
    AksharaLanguage.tamil: 'புதிய போக்குவரத்து பாதை திங்கள் முதல் நடைமுறை',
    AksharaLanguage.kannada: 'ಹೊಸ ಸಾರಿಗೆ ಮಾರ್ಗ ಸೋಮವಾರದಿಂದ ಜಾರಿಗೆ',
    AksharaLanguage.malayalam: 'പുതിയ ട്രാൻസ്പോർട്ട് റൂട്ട് തിങ്കളാഴ്ച മുതൽ',
    AksharaLanguage.urdu: 'نیا ٹرانسپورٹ روٹ پیر سے نافذ',
  },
  'Route 12 pickup time moves to 7:35 AM at Green Park stop.': {
    AksharaLanguage.telugu:
        'రూట్ 12 పికప్ సమయం గ్రీన్ పార్క్ స్టాప్ వద్ద 7:35 AMకి మారింది.',
    AksharaLanguage.hindi:
        'रूट 12 पिकअप समय ग्रीन पार्क स्टॉप पर 7:35 AM हो गया।',
    AksharaLanguage.tamil:
        'ரூட் 12 பிக்-அப் நேரம் கிரீன் பார்க் நிறுத்தத்தில் காலை 7:35 ஆக மாற்றப்பட்டது.',
    AksharaLanguage.kannada:
        'ರೂಟ್ 12 ಪಿಕಪ್ ಸಮಯ ಗ್ರೀನ್ ಪಾರ್ಕ್ ನಿಲ್ದಾಣದಲ್ಲಿ 7:35 AM ಗೆ ಬದಲಾಯಿತು.',
    AksharaLanguage.malayalam:
        'റൂട്ട് 12 പിക്കപ്പ് സമയം ഗ്രീൻ പാർക്ക് സ്റ്റോപ്പിൽ 7:35 AM ആയി.',
    AksharaLanguage.urdu:
        'روٹ 12 پک اپ وقت گرین پارک اسٹاپ پر 7:35 AM ہو گیا۔',
  },
  'Unit test schedule published for Term 2': {
    AksharaLanguage.telugu: 'టర్మ్ 2 కోసం యూనిట్ టెస్ట్ షెడ్యూల్ ప్రచురించబడింది',
    AksharaLanguage.hindi: 'टर्म 2 के लिए इकाई परीक्षा कार्यक्रम प्रकाशित',
    AksharaLanguage.tamil: 'காலம் 2 க்கான அலகு தேர்வு அட்டவணை வெளியிடப்பட்டது',
    AksharaLanguage.kannada: 'ಟರ್ಮ್ 2 ಗಾಗಿ ಯೂನಿಟ್ ಪರೀಕ್ಷೆ ವೇಳಾಪಟ್ಟಿ ಪ್ರಕಟಿಸಲಾಗಿದೆ',
    AksharaLanguage.malayalam: 'ടേം 2 ന് യൂണിറ്റ് ടെസ്റ്റ് ഷെഡ്യൂൾ പ്രസിദ്ധീകരിച്ചു',
    AksharaLanguage.urdu: 'ٹرم 2 کے لیے یونٹ ٹیسٹ شیڈول شائع',
  },
  'Mathematics and Science tests begin 12 June.': {
    AksharaLanguage.telugu: 'గణితం మరియు సైన్స్ పరీక్షలు 12 జూన్ నుండి ప్రారంభం',
    AksharaLanguage.hindi: 'गणित और विज्ञान परीक्षाएं 12 जून से शुरू',
    AksharaLanguage.tamil: 'கணிதம் மற்றும் அறிவியல் தேர்வுகள் ஜூன் 12 முதல்',
    AksharaLanguage.kannada: 'ಗಣಿತ ಮತ್ತು ವಿಜ್ಞಾನ ಪರೀಕ್ಷೆಗಳು ಜೂನ್ 12 ರಿಂದ',
    AksharaLanguage.malayalam: 'ഗണിതവും സയൻസും പരീക്ഷകൾ ജൂൺ 12 മുതൽ',
    AksharaLanguage.urdu: 'ریاضی اور سائنس کے ٹیسٹ 12 جون سے',
  },
  // Homework
  'Exercise 5.2 - Solve Q1 to Q8': {
    AksharaLanguage.telugu: 'అభ్యాసం 5.2 - Q1 నుండి Q8 వరకు పరిష్కరించండి',
    AksharaLanguage.hindi: 'अभ्यास 5.2 - प्रश्न 1 से 8 हल करें',
    AksharaLanguage.tamil: 'பயிற்சி 5.2 - கேள்வி 1 முதல் 8 வரை தீர்க்கவும்',
    AksharaLanguage.kannada: 'ಅಭ್ಯಾಸ 5.2 - ಪ್ರಶ್ನೆ 1 ರಿಂದ 8 ವರೆಗೆ ಪರಿಹರಿಸಿ',
    AksharaLanguage.malayalam: 'അഭ്യാസം 5.2 - Q1 മുതൽ Q8 വരെ പരിഹരിക്കുക',
    AksharaLanguage.urdu: 'مشق 5.2 - سوال 1 سے 8 حل کریں',
  },
  'Write notes on photosynthesis': {
    AksharaLanguage.telugu: 'కిరణజన్య సంయోగక్రియపై నోట్స్ రాయండి',
    AksharaLanguage.hindi: 'प्रकाश संश्लेषण पर नोट्स लिखें',
    AksharaLanguage.tamil: 'ஒளிச்சேர்க்கை பற்றி குறிப்புகள் எழுதுங்கள்',
    AksharaLanguage.kannada: 'ದ್ಯುತಿಸಂಶ್ಲೇಷಣೆಯ ಬಗ್ಗೆ ಟಿಪ್ಪಣಿಗಳು ಬರೆಯಿರಿ',
    AksharaLanguage.malayalam: 'പ്രകാശസംശ്ലേഷണത്തെക്കുറിച്ച് കുറിപ്പുകൾ എഴുതുക',
    AksharaLanguage.urdu: 'فوٹو سنتھیسس پر نوٹس لکھیں',
  },
  'Poem recitation preparation': {
    AksharaLanguage.telugu: 'కవితా పఠనం సిద్ధత',
    AksharaLanguage.hindi: 'कविता पाठ की तैयारी',
    AksharaLanguage.tamil: 'கவிதை ஓதுதல் தயாரிப்பு',
    AksharaLanguage.kannada: 'ಕವಿತೆ ಪಠಣ ತಯಾರಿ',
    AksharaLanguage.malayalam: 'കവിതാ പാരായണം തയ്യാറാക്കൽ',
    AksharaLanguage.urdu: 'شاعری کی تیاری',
  },
  'Map labeling: India rivers': {
    AksharaLanguage.telugu: 'మ్యాప్ లేబులింగ్: భారత నదులు',
    AksharaLanguage.hindi: 'मानचित्र लेबलिंग: भारत की नदियां',
    AksharaLanguage.tamil: 'வரைபட குறிப்பிடல்: இந்தியா ஆறுகள்',
    AksharaLanguage.kannada: 'ನಕ್ಷೆ ಲೇಬಲಿಂಗ್: ಭಾರತದ ನದಿಗಳು',
    AksharaLanguage.malayalam: 'മാപ്പ് ലേബലിംഗ്: ഇന്ത്യയിലെ നദികൾ',
    AksharaLanguage.urdu: 'نقشہ لیبلنگ: ہندوستان کی ندیاں',
  },
  'Grammar worksheet - Sangya': {
    AksharaLanguage.telugu: 'వ్యాకరణ వర్క్‌షీట్ - సంజ్ఞ',
    AksharaLanguage.hindi: 'व्याकरण वर्कशीट - संज्ञा',
    AksharaLanguage.tamil: 'இலக்கண பணித்தாள் - பெயர்',
    AksharaLanguage.kannada: 'ವ್ಯಾಕರಣ ವರ್ಕ್‌ಶೀಟ್ - ನಾಮಪದ',
    AksharaLanguage.malayalam: 'വ്യാകരണ വർക്ക്ഷീറ്റ് - നാമം',
    AksharaLanguage.urdu: 'گرامر ورک شیٹ - اسم',
  },
  'Scratch animation mini-project': {
    AksharaLanguage.telugu: 'స్క్రాచ్ యానిమేషన్ మిని-ప్రాజెక్ట్',
    AksharaLanguage.hindi: 'स्क्रैच एनिमेशन मिनी-प्रोजेक्ट',
    AksharaLanguage.tamil: 'ஸ்கிராட்ச் அனிமேஷன் சிறு திட்டம்',
    AksharaLanguage.kannada: 'ಸ್ಕ್ರ್ಯಾಚ್ ಅನಿಮೇಷನ್ ಮಿನಿ-ಪ್ರಾಜೆಕ್ಟ್',
    AksharaLanguage.malayalam: 'സ്ക്രാച്ച് ആനിമേഷൻ മിനി-പ്രോജക്റ്റ്',
    AksharaLanguage.urdu: 'اسکریچ اینیمیشن منی پروجیکٹ',
  },
  'Math and Science tasks are due this week - schedule 30 minutes daily.': {
    AksharaLanguage.telugu:
        'గణితం మరియు సైన్స్ పనులు ఈ వారం గడువు — రోజుకు 30 నిమిషాలు కేటాయించండి.',
    AksharaLanguage.hindi:
        'गणित और विज्ञान के कार्य इस सप्ताह देय — प्रतिदिन 30 मिनट निर्धारित करें।',
    AksharaLanguage.tamil:
        'கணிதம் மற்றும் அறிவியல் பணிகள் இந்த வாரம் — தினமும் 30 நிமிடம் ஒதுக்குங்கள்.',
    AksharaLanguage.kannada:
        'ಗಣಿತ ಮತ್ತು ವಿಜ್ಞಾನ ಕಾರ್ಯಗಳು ಈ ವಾರ ಬಾಕಿ — ದಿನಕ್ಕೆ 30 ನಿಮಿಷ ನಿಗದಿಪಡಿಸಿ.',
    AksharaLanguage.malayalam:
        'ഗണിതവും സയൻസും ടാസ്ക്കുകൾ ഈ ആഴ്ച — ദിവസവും 30 മിനിറ്റ് നിശ്ചയിക്കുക.',
    AksharaLanguage.urdu:
        'ریاضی اور سائنس کے کام اس ہفتے — روزانہ 30 منٹ مقرر کریں۔',
  },
  'School holiday — Eid': {
    AksharaLanguage.telugu: 'పాఠశాల సెలవు — ఈద్',
    AksharaLanguage.hindi: 'स्कूल अवकाश — ईद',
    AksharaLanguage.tamil: 'பள்ளி விடுமுறை — ஈத்',
    AksharaLanguage.kannada: 'ಶಾಲಾ ರಜೆ — ಈದ್',
    AksharaLanguage.malayalam: 'സ്കൂൾ അവധി — ഈദ്',
    AksharaLanguage.urdu: 'اسکول کی چھٹی — عید',
  },
  'School closed on 7 Jun. Regular classes resume 8 Jun.': {
    AksharaLanguage.telugu:
        '7 జూన్‌న పాఠశాల మూసివేయబడింది. 8 జూన్ నుండి తరగతులు పునరారంభం.',
    AksharaLanguage.hindi:
        '7 जून को स्कूल बंद। 8 जून से नियमित कक्षाएं।',
    AksharaLanguage.tamil:
        'ஜூன் 7 அன்று பள்ளி மூடப்பட்டது. ஜூன் 8 முதல் வகுப்புகள்.',
    AksharaLanguage.kannada:
        'ಜೂನ್ 7 ರಂದು ಶಾಲೆ ಮುಚ್ಚಲಾಗಿದೆ. ಜೂನ್ 8 ರಿಂದ ತರಗತಿಗಳು.',
    AksharaLanguage.malayalam:
        'ജൂൺ 7 ന് സ്കൂൾ അടച്ചു. ജൂൺ 8 മുതൽ ക്ലാസുകൾ.',
    AksharaLanguage.urdu:
        '7 جون کو اسکول بند۔ 8 جون سے کلاسیں۔',
  },
  // Teacher assignments
  'Exercise 5.2 — Linear equations': {
    AksharaLanguage.telugu: 'అభ్యాసం 5.2 — లీనియర్ ఈక్వేషన్స్',
    AksharaLanguage.hindi: 'अभ्यास 5.2 — रैखिक समीकरण',
    AksharaLanguage.tamil: 'பயிற்சி 5.2 — நேரியல் சமன்பாடுகள்',
    AksharaLanguage.kannada: 'ಅಭ್ಯಾಸ 5.2 — ರೇಖೀಯ ಸಮೀಕರಣಗಳು',
    AksharaLanguage.malayalam: 'അഭ്യാസം 5.2 — ലീനിയർ സമവാക്യങ്ങൾ',
    AksharaLanguage.urdu: 'مشق 5.2 — خطی مساوات',
  },
  'Chapter 4 problem set': {
    AksharaLanguage.telugu: 'అధ్యాయం 4 ప్రాబ్లమ్ సెట్',
    AksharaLanguage.hindi: 'अध्याय 4 समस्या सेट',
    AksharaLanguage.tamil: 'அத்தியாயம் 4 பிரச்சனை தொகுப்பு',
    AksharaLanguage.kannada: 'ಅಧ್ಯಾಯ 4 ಸಮಸ್ಯೆ ಸೆಟ್',
    AksharaLanguage.malayalam: 'അധ്യായം 4 പ്രശ്ന സെറ്റ്',
    AksharaLanguage.urdu: 'باب 4 مسئلہ سیٹ',
  },
  'Mathematics Practice': {
    AksharaLanguage.telugu: 'గణితం అభ్యాసం',
    AksharaLanguage.hindi: 'गणित अभ्यास',
    AksharaLanguage.tamil: 'கணித பயிற்சி',
    AksharaLanguage.kannada: 'ಗಣಿತ ಅಭ್ಯಾಸ',
    AksharaLanguage.malayalam: 'ഗണിത പരിശീലനം',
    AksharaLanguage.urdu: 'ریاضی کی مشق',
  },
  'Algebra worksheet — Exercise 5.2': {
    AksharaLanguage.telugu: 'బీజగణిత వర్క్‌షీట్ — అభ్యాసం 5.2',
    AksharaLanguage.hindi: 'बीजगणित वर्कशीट — अभ्यास 5.2',
    AksharaLanguage.tamil: 'இயற்கணித பணித்தாள் — பயிற்சி 5.2',
    AksharaLanguage.kannada: 'ಬೀಜಗಣಿತ ವರ್ಕ್‌ಶೀಟ್ — ಅಭ್ಯಾಸ 5.2',
    AksharaLanguage.malayalam: 'അല്ജീബ്രാ വർക്ക്ഷീറ്റ് — അഭ്യാസം 5.2',
    AksharaLanguage.urdu: 'الجبرا ورک شیٹ — مشق 5.2',
  },
  'Photosynthesis lab report': {
    AksharaLanguage.telugu: 'కిరణజన్య సంయోగక్రియ ల్యాబ్ రిపోర్ట్',
    AksharaLanguage.hindi: 'प्रकाश संश्लेषण प्रयोगशाला रिपोर्ट',
    AksharaLanguage.tamil: 'ஒளிச்சேர்க்கை ஆய்வக அறிக்கை',
    AksharaLanguage.kannada: 'ದ್ಯುತಿಸಂಶ್ಲೇಷಣೆ ಪ್ರಯೋಗಾಲಯ ವರದಿ',
    AksharaLanguage.malayalam: 'പ്രകാശസംശ്ലേഷണം ലാബ് റിപ്പോർട്ട്',
    AksharaLanguage.urdu: 'فوٹو سنتھیسس لیب رپورٹ',
  },
  // PTM
  'Discuss mid-term performance and transport timing.': {
    AksharaLanguage.telugu:
        'మధ్య-టర్మ్ పనితీరు మరియు ట్రాన్స్‌పోర్ట్ సమయాలను చర్చించండి.',
    AksharaLanguage.hindi:
        'मध्यावधि प्रदर्शन और परिवहन समय पर चर्चा करें।',
    AksharaLanguage.tamil:
        'இடைக்கால செயல்திறன் மற்றும் போக்குவரத்து நேரத்தை விவாதிக்கவும்.',
    AksharaLanguage.kannada:
        'ಮಧ್ಯಾವಧಿ ಪ್ರದರ್ಶನ ಮತ್ತು ಸಾರಿಗೆ ಸಮಯವನ್ನು ಚರ್ಚಿಸಿ.',
    AksharaLanguage.malayalam:
        'മിഡ്-ടേം പ്രകടനവും ട്രാൻസ്പോർട്ട് സമയവും ചർച്ച ചെയ്യുക.',
    AksharaLanguage.urdu:
        'مڈ ٹرم کارکردگی اور ٹرانسپورٹ کے اوقات پر بات کریں۔',
  },
  'PTM scheduled for 15 June. Focus on mathematics revision plan.': {
    AksharaLanguage.telugu:
        '15 జూన్‌న PTM షెడ్యూల్. గణితం రివిజన్ ప్లాన్‌పై దృష్టి పెట్టండి.',
    AksharaLanguage.hindi:
        '15 जून को PTM निर्धारित। गणित संशोधन योजना पर ध्यान दें।',
    AksharaLanguage.tamil:
        '15 ஜூன் PTM திட்டமிடப்பட்டது. கணித திருத்த திட்டத்தில் கவனம்.',
    AksharaLanguage.kannada:
        '15 ಜೂನ್ PTM ನಿಗದಿ. ಗಣಿತ ಪುನರಾವರ್ತನೆ ಯೋಜನೆಯ ಮೇಲೆ ಕೇಂದ್ರೀಕರಿಸಿ.',
    AksharaLanguage.malayalam:
        '15 ജൂണ് PTM ഷെഡ്യൂൾ. ഗണിത റിവിഷൻ പ്ലാനിൽ ശ്രദ്ധിക്കുക.',
    AksharaLanguage.urdu:
        '15 جون PTM طے۔ ریاضی کی نظرثانی پر توجہ دیں۔',
  },
  'Confirm PTM slot for 15 June': {
    AksharaLanguage.telugu: '15 జూన్ కోసం PTM స్లాట్‌ను నిర్ధారించండి',
    AksharaLanguage.hindi: '15 जून के लिए PTM स्लॉट की पुष्टि करें',
    AksharaLanguage.tamil: '15 ஜூன் PTM நேரத்தை உறுதிப்படுத்துங்கள்',
    AksharaLanguage.kannada: '15 ಜೂನ್ PTM ಸ್ಲಾಟ್ ದೃಢೀಕರಿಸಿ',
    AksharaLanguage.malayalam: '15 ജൂണിനുള്ള PTM സ്ലോട്ട് സ്ഥിരീകരിക്കുക',
    AksharaLanguage.urdu: '15 جون کے لیے PTM سلاٹ کی تصدیق کریں',
  },
  // Discipline
  'A discipline concern was noted today. Please discuss appropriate classroom behaviour at home.':
      {
    AksharaLanguage.telugu:
        'ఈరోజు శిష్టాచార సమస్య గమనించబడింది. ఇంట్లో తగిన తరగతి ప్రవర్తన గురించి చర్చించండి.',
    AksharaLanguage.hindi:
        'आज एक अनुशासन संबंधी चिंता दर्ज की गई। कृपया घर पर उचित कक्षा व्यवहार पर चर्चा करें।',
    AksharaLanguage.tamil:
        'இன்று ஒழுங்கு கவலை குறிப்பிடப்பட்டது. வீட்டில் பொருத்தமான வகுப்பு நடத்தையை விவாதிக்கவும்.',
    AksharaLanguage.kannada:
        'ಇಂದು ಶಿಸ್ತಿನ ಕಾಳಜಿ ಗಮನಿಸಲಾಗಿದೆ. ಮನೆಯಲ್ಲಿ ಸೂಕ್ತ ತರಗತಿ ನಡವಳಿಕೆಯನ್ನು ಚರ್ಚಿಸಿ.',
    AksharaLanguage.malayalam:
        'ഇന്ന് അച്ചടക്ക ആശങ്ക രേഖപ്പെടുത്തി. വീട്ടിൽ ഉചിതമായ ക്ലാസ് പെരുമാറ്റം ചർച്ച ചെയ്യുക.',
    AksharaLanguage.urdu:
        'آج نظم و ضبط کا مسئلہ نوٹ کیا گیا۔ گھر پر مناسب کلاس کے برتاؤ پر بات کریں۔',
  },
  'Repeated homework gaps noted. Parent intervention is requested to support timely submission.':
      {
    AksharaLanguage.telugu:
        'హోమ్‌వర్క్ అంతరాలు పదే పదే గమనించబడ్డాయి. సమయానికి సమర్పించడానికి తల్లిదండ్రుల యొక్క సహకారం అవసరం.',
    AksharaLanguage.hindi:
        'बार-बार होमवर्क में कमी देखी गई। समय पर जमा करने के लिए अभिभावक हस्तक्षेप अनुरोधित है।',
    AksharaLanguage.tamil:
        'மீண்டும் மீண்டும் வீட்டுப்பாட இடைவெளிகள் குறிப்பிடப்பட்டன. சரியான நேரத்தில் சமர்ப்பிக்க பெற்றோர் உதவி தேவை.',
    AksharaLanguage.kannada:
        'ಪುನರಾವರ್ತಿತ ಗೃಹಪಾಠ ಅಂತರಗಳು ಗಮನಿಸಲಾಗಿದೆ. ಸಮಯಕ್ಕೆ ಸಲ್ಲಿಸಲು ಪೋಷಕರ ಹಸ್ತಕ್ಷೇಪ ಅಗತ್ಯ.',
    AksharaLanguage.malayalam:
        'ഹോംവർക്ക് വിടവുകൾ ആവർത്തിച്ച് ശ്രദ്ധിച്ചു. സമയബന്ധിതമായി സമർപ്പിക്കാൻ രക്ഷിതാക്കളുടെ സഹകരണം ആവശ്യമാണ്.',
    AksharaLanguage.urdu:
        'بار بار ہوم ورک میں کمی نوٹ ہوئی۔ بروقت جمع کرانے کے لیے والدین سے مدد درکار ہے۔',
  },
  };
}
