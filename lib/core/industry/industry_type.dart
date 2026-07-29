import 'package:flutter/foundation.dart';

/// Supported vertical industries for NIKSHA OS.
enum IndustryType {
  school('school', 'School'),
  salon('salon', 'Salon'),
  hospital('hospital', 'Healthcare'),
  restaurant('restaurant', 'Restaurant'),
  hostel('hostel', 'Accommodation');

  const IndustryType(this.value, this.label);
  final String value;
  final String label;

  static IndustryType fromValue(String raw) {
    for (final type in IndustryType.values) {
      if (type.value == raw) return type;
    }
    return IndustryType.school;
  }
}

@immutable
class IndustryModuleActivation {
  const IndustryModuleActivation({
    required this.moduleId,
    required this.label,
    required this.isActive,
    this.route,
  });

  final String moduleId;
  final String label;
  final bool isActive;
  final String? route;
}
