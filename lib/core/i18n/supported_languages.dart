/// Supported parent-facing languages in NIKSHA.
enum AksharaLanguage {
  english('en', 'English'),
  telugu('te', 'Telugu'),
  hindi('hi', 'Hindi'),
  tamil('ta', 'Tamil'),
  kannada('kn', 'Kannada'),
  malayalam('ml', 'Malayalam'),
  urdu('ur', 'Urdu');

  const AksharaLanguage(this.code, this.displayName);

  final String code;
  final String displayName;

  static AksharaLanguage fromCode(String? code) {
    if (code == null || code.isEmpty) return AksharaLanguage.english;
    for (final lang in AksharaLanguage.values) {
      if (lang.code == code) return lang;
    }
    return AksharaLanguage.english;
  }
}
