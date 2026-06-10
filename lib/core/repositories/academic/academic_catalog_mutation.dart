import '../../../features/admissions/admissions_requests.dart';
import '../../../features/finance/finance_requests.dart';
import '../../../features/sis/sis_requests.dart';
import 'academic_catalog_placement.dart';
import 'academic_models.dart';

EnrollmentSubmitRequest enrichEnrollmentSubmitRequest(
  EnrollmentSubmitRequest request,
  AcademicCatalogData catalog,
) {
  final placement = resolveAcademicCatalogPlacement(
    catalog,
    academicYear: request.academic.academicYear,
    className: request.academic.seekingClass,
    sectionName: request.academic.section,
  );
  if (!placement.hasAnyId) return request;
  return EnrollmentSubmitRequest(
    student: request.student,
    parent: request.parent,
    applicationId: request.applicationId,
    academic: request.academic.copyWith(
      academicYearId: placement.academicYearId,
      classId: placement.classId,
      sectionId: placement.sectionId,
    ),
  );
}

AcademicAssignmentRequest enrichAcademicAssignmentRequest(
  AcademicAssignmentRequest request,
  AcademicCatalogData catalog,
) {
  final placement = resolveAcademicCatalogPlacement(
    catalog,
    academicYear: request.academicYear,
    className: request.classLabel,
    sectionName: request.section,
  );
  if (!placement.hasAnyId) return request;
  return AcademicAssignmentRequest(
    studentId: request.studentId,
    classLabel: request.classLabel,
    section: request.section,
    academicYear: request.academicYear,
    academicYearId: placement.academicYearId,
    classId: placement.classId,
    sectionId: placement.sectionId,
  );
}

AdmissionsConversionRequest enrichAdmissionsConversionRequest(
  AdmissionsConversionRequest request,
  AcademicCatalogData catalog,
) {
  final placement = resolveAcademicCatalogPlacement(
    catalog,
    academicYear: request.academicYear,
    className: request.classLabel,
    sectionName: request.section,
  );
  if (!placement.hasAnyId) return request;
  return AdmissionsConversionRequest(
    enrollmentId: request.enrollmentId,
    classLabel: request.classLabel,
    section: request.section,
    academicYear: request.academicYear,
    academicYearId: placement.academicYearId,
    classId: placement.classId,
    sectionId: placement.sectionId,
  );
}

CreateFeeStructureRequest enrichCreateFeeStructureRequest(
  CreateFeeStructureRequest request,
  AcademicCatalogData catalog,
) {
  final placement = resolveAcademicCatalogPlacement(
    catalog,
    academicYear: request.academicYear,
    className: '',
  );
  if (placement.academicYearId == null) return request;
  return CreateFeeStructureRequest(
    name: request.name,
    academicYear: request.academicYear,
    totalAnnual: request.totalAnnual,
    classRange: request.classRange,
    categories: request.categories,
    installmentOptions: request.installmentOptions,
    status: request.status,
    academicYearId: placement.academicYearId,
  );
}

UpdateFeeStructureRequest enrichUpdateFeeStructureRequest(
  UpdateFeeStructureRequest request,
  AcademicCatalogData catalog,
) {
  final year = request.academicYear;
  if (year == null || year.isEmpty) return request;
  final placement = resolveAcademicCatalogPlacement(
    catalog,
    academicYear: year,
    className: '',
  );
  if (placement.academicYearId == null) return request;
  return UpdateFeeStructureRequest(
    name: request.name,
    academicYear: request.academicYear,
    totalAnnual: request.totalAnnual,
    classRange: request.classRange,
    categories: request.categories,
    installmentOptions: request.installmentOptions,
    status: request.status,
    academicYearId: placement.academicYearId,
  );
}
