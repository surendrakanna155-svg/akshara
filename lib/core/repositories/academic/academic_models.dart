import 'package:flutter/foundation.dart';

@immutable
class AcademicYear {
  const AcademicYear({
    required this.yearId,
    required this.yearLabel,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.status,
  });

  final String yearId;
  final String yearLabel;
  final String startDate;
  final String endDate;
  final bool isCurrent;
  final String status;
}

@immutable
class AcademicClass {
  const AcademicClass({
    required this.classId,
    required this.academicYearId,
    required this.className,
    required this.displayOrder,
    required this.status,
  });

  final String classId;
  final String academicYearId;
  final String className;
  final int displayOrder;
  final String status;
}

@immutable
class AcademicSection {
  const AcademicSection({
    required this.sectionId,
    required this.classId,
    required this.className,
    required this.sectionName,
    required this.capacity,
    required this.strength,
    required this.status,
  });

  final String sectionId;
  final String classId;
  final String className;
  final String sectionName;
  final int capacity;
  final int strength;
  final String status;
}

@immutable
class AcademicTeacherAssignment {
  const AcademicTeacherAssignment({
    required this.assignmentId,
    required this.teacherId,
    required this.teacherName,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.role,
    required this.isPrimary,
  });

  final String assignmentId;
  final String teacherId;
  final String? teacherName;
  final String classId;
  final String className;
  final String sectionId;
  final String sectionName;
  final String role;
  final bool isPrimary;
}

@immutable
class AcademicCatalogData {
  const AcademicCatalogData({
    required this.years,
    required this.classes,
    required this.sections,
    required this.teacherAssignments,
  });

  final List<AcademicYear> years;
  final List<AcademicClass> classes;
  final List<AcademicSection> sections;
  final List<AcademicTeacherAssignment> teacherAssignments;
}
