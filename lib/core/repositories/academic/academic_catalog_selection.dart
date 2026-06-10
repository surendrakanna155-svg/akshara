import 'package:flutter/foundation.dart';

/// Dropdown filter key: academic year label + class name.
@immutable
class YearClassSelection {
  const YearClassSelection({this.yearLabel, this.className});

  final String? yearLabel;
  final String? className;

  @override
  bool operator ==(Object other) {
    return other is YearClassSelection &&
        other.yearLabel == yearLabel &&
        other.className == className;
  }

  @override
  int get hashCode => Object.hash(yearLabel, className);
}
