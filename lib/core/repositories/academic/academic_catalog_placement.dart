import 'academic_models.dart';
import 'academic_year_label.dart';

/// Resolved catalog UUIDs for a label-based placement selection.
class AcademicCatalogPlacement {
  const AcademicCatalogPlacement({
    this.academicYearId,
    this.classId,
    this.sectionId,
  });

  final String? academicYearId;
  final String? classId;
  final String? sectionId;

  bool get hasAnyId =>
      (academicYearId?.isNotEmpty ?? false) ||
      (classId?.isNotEmpty ?? false) ||
      (sectionId?.isNotEmpty ?? false);
}

bool _isActiveCatalogStatus(String status) {
  return status.isEmpty || status == 'active';
}

/// Maps label selections to catalog UUIDs using loaded [catalog] data.
///
/// Returns partial placement when only some labels resolve (e.g. admissions
/// empty-year mode). Resolver on the server remains authoritative.
AcademicCatalogPlacement resolveAcademicCatalogPlacement(
  AcademicCatalogData catalog, {
  required String academicYear,
  required String className,
  String? sectionName,
}) {
  final normalizedYear = normalizeAcademicYearLabel(academicYear);
  final trimmedClass = className.trim();
  final trimmedSection = sectionName?.trim() ?? '';

  String? yearId;
  if (normalizedYear.isNotEmpty) {
    for (final year in catalog.years) {
      if (!_isActiveCatalogStatus(year.status)) continue;
      if (academicYearLabelsEqual(year.yearLabel, normalizedYear)) {
        yearId = year.yearId;
        break;
      }
    }
  }

  String? classId;
  if (trimmedClass.isNotEmpty) {
    for (final cls in catalog.classes) {
      if (!_isActiveCatalogStatus(cls.status)) continue;
      if (cls.className != trimmedClass) continue;
      if (yearId != null && cls.academicYearId != yearId) continue;
      classId = cls.classId;
      yearId ??= cls.academicYearId;
      break;
    }
  }

  String? sectionId;
  if (trimmedSection.isNotEmpty && classId != null) {
    for (final section in catalog.sections) {
      if (!_isActiveCatalogStatus(section.status)) continue;
      if (section.classId != classId) continue;
      if (section.sectionName != trimmedSection) continue;
      sectionId = section.sectionId;
      break;
    }
  }

  return AcademicCatalogPlacement(
    academicYearId: yearId,
    classId: classId,
    sectionId: sectionId,
  );
}

/// Dual-write FK keys for API payloads (snake + camel aliases).
Map<String, dynamic> catalogPlacementJson(AcademicCatalogPlacement placement) {
  final map = <String, dynamic>{};
  if (placement.academicYearId?.isNotEmpty ?? false) {
    map['academic_year_id'] = placement.academicYearId;
    map['academicYearId'] = placement.academicYearId;
  }
  if (placement.classId?.isNotEmpty ?? false) {
    map['class_id'] = placement.classId;
    map['classId'] = placement.classId;
  }
  if (placement.sectionId?.isNotEmpty ?? false) {
    map['section_id'] = placement.sectionId;
    map['sectionId'] = placement.sectionId;
  }
  return map;
}
