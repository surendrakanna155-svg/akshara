import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../intelligence/intelligence_models.dart';

/// Parent communication language preference (school completion v1).
final parentPreferredLanguageProvider = StateProvider<IntelLanguage>(
  (ref) => IntelLanguage.telugu,
);
