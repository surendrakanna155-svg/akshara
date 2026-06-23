import 'package:flutter/foundation.dart';

@immutable
class ParentContact {
  const ParentContact({
    required this.name,
    required this.relation,
    required this.phoneLabel,
    required this.email,
  });

  final String name;
  final String relation;
  final String phoneLabel;
  final String email;
}

@immutable
class AcademicSummaryItem {
  const AcademicSummaryItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

@immutable
class StudentProfileData {
  const StudentProfileData({
    required this.studentName,
    required this.classLabel,
    required this.rollNo,
    required this.admissionNo,
    required this.dateOfBirth,
    required this.bloodGroup,
    required this.schoolName,
    required this.parentContacts,
    required this.academicSummary,
    this.unreadNotifications = 0,
  });

  final String studentName;
  final String classLabel;
  final String rollNo;
  final String admissionNo;
  final String dateOfBirth;
  final String bloodGroup;
  final String schoolName;
  final List<ParentContact> parentContacts;
  final List<AcademicSummaryItem> academicSummary;
  final int unreadNotifications;

  String get initials {
    final parts = studentName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
