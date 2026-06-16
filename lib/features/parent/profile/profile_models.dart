import 'package:flutter/foundation.dart';

import '../../../core/i18n/supported_languages.dart';

/// Linked child account on a parent profile.
@immutable
class ParentChildProfile {
  const ParentChildProfile({
    required this.id,
    required this.name,
    required this.classLabel,
    this.isActive = false,
  });

  final String id;
  final String name;
  final String classLabel;
  final bool isActive;
}

/// PA-09 parent profile payload.
@immutable
class ParentProfileData {
  const ParentProfileData({
    required this.parentName,
    required this.phoneLabel,
    required this.email,
    required this.schoolName,
    required this.children,
    this.preferredLanguage = AksharaLanguage.english,
    this.unreadNotifications = 0,
  });

  final String parentName;
  final String phoneLabel;
  final String email;
  final String schoolName;
  final List<ParentChildProfile> children;
  final AksharaLanguage preferredLanguage;
  final int unreadNotifications;

  int get childrenCount => children.length;

  String get initials {
    final parts = parentName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
