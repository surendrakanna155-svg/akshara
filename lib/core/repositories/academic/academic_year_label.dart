/// Canonical academic year label helpers.
///
/// API responses use ASCII hyphen (`2026-27`). Legacy mocks and form defaults
/// may use en-dash (`2026–27`). Normalize for comparisons and dropdown matching.
String normalizeAcademicYearLabel(String label) {
  return label
      .trim()
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll(RegExp(r'\s+'), '');
}

bool academicYearLabelsEqual(String a, String b) {
  return normalizeAcademicYearLabel(a) == normalizeAcademicYearLabel(b);
}

/// Picks [selected] when present in [options] (dash-insensitive); otherwise
/// the first option or normalized [selected] when [options] is empty.
String resolveAcademicYearSelection(String selected, List<String> options) {
  if (options.isEmpty) return normalizeAcademicYearLabel(selected);
  for (final option in options) {
    if (academicYearLabelsEqual(option, selected)) return option;
  }
  return options.first;
}
