import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admissions_models.dart';

final admissionsDocumentsLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsDocumentsErrorProvider = StateProvider<bool>((ref) => false);
final admissionsDocumentsEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsDocumentsFilterProvider = StateProvider<int>((ref) => 0);

final admissionsSelectedDocumentIdProvider = StateProvider<String?>(
  (ref) => null,
);

final admissionsDocumentsProvider = Provider<List<StudentDocumentRecord>>((ref) {
  if (ref.watch(admissionsDocumentsLoadingProvider)) return const [];
  if (ref.watch(admissionsDocumentsErrorProvider)) return const [];
  if (ref.watch(admissionsDocumentsEmptyProvider)) return const [];
  return _mockDocuments();
});

final admissionsDocumentSummaryProvider =
    Provider<DocumentVerificationSummary>((ref) {
  final docs = ref.watch(admissionsDocumentsProvider);
  var pending = 0;
  var verified = 0;
  var rejected = 0;
  var missing = 0;

  for (final doc in docs) {
    switch (doc.status) {
      case DocumentVerificationStatus.uploaded:
        pending++;
      case DocumentVerificationStatus.verified:
        verified++;
      case DocumentVerificationStatus.rejected:
        rejected++;
      case DocumentVerificationStatus.missing:
        missing++;
    }
  }

  return DocumentVerificationSummary(
    pending: pending,
    verified: verified,
    rejected: rejected,
    missing: missing,
  );
});

final admissionsDocumentChecklistProvider =
    Provider.family<List<DocumentChecklistItem>, String?>((ref, leadId) {
  final docs = ref.watch(admissionsDocumentsProvider);
  final filtered = leadId == null
      ? docs
      : docs.where((doc) => doc.leadId == leadId).toList();

  if (filtered.isEmpty) return const [];

  final byType = <DocumentType, StudentDocumentRecord>{};
  for (final doc in filtered) {
    byType[doc.documentType] = doc;
  }

  return DocumentType.values
      .map((type) {
        final record = byType[type];
        return DocumentChecklistItem(
          documentType: type,
          status: record?.status ?? DocumentVerificationStatus.missing,
          isRequired: record?.isRequired ?? type != DocumentType.photos,
          note: record?.uploadedLabel ?? 'Not uploaded',
        );
      })
      .toList(growable: false);
});

List<StudentDocumentRecord> _mockDocuments() {
  return const [
    StudentDocumentRecord(
      id: 'doc_1',
      studentName: 'Ananya Reddy',
      classLabel: '5',
      documentType: DocumentType.birthCertificate,
      isRequired: true,
      status: DocumentVerificationStatus.verified,
      uploadedLabel: '2 Jun 2026',
      verifiedBy: 'Meera N.',
      leadId: 'LD-1042',
    ),
    StudentDocumentRecord(
      id: 'doc_2',
      studentName: 'Ananya Reddy',
      classLabel: '5',
      documentType: DocumentType.aadhaar,
      isRequired: true,
      status: DocumentVerificationStatus.uploaded,
      uploadedLabel: '3 Jun 2026',
      verifiedBy: null,
      leadId: 'LD-1042',
    ),
    StudentDocumentRecord(
      id: 'doc_3',
      studentName: 'Ananya Reddy',
      classLabel: '5',
      documentType: DocumentType.marksMemo,
      isRequired: true,
      status: DocumentVerificationStatus.missing,
      uploadedLabel: '—',
      verifiedBy: null,
      leadId: 'LD-1042',
    ),
    StudentDocumentRecord(
      id: 'doc_4',
      studentName: 'Karthik Sharma',
      classLabel: '8',
      documentType: DocumentType.transferCertificate,
      isRequired: true,
      status: DocumentVerificationStatus.rejected,
      uploadedLabel: '1 Jun 2026',
      verifiedBy: 'Rahul V.',
      leadId: 'LD-1038',
    ),
    StudentDocumentRecord(
      id: 'doc_5',
      studentName: 'Karthik Sharma',
      classLabel: '8',
      documentType: DocumentType.photos,
      isRequired: false,
      status: DocumentVerificationStatus.verified,
      uploadedLabel: '1 Jun 2026',
      verifiedBy: 'Rahul V.',
      leadId: 'LD-1038',
    ),
    StudentDocumentRecord(
      id: 'doc_6',
      studentName: 'Arjun Patel',
      classLabel: '10',
      documentType: DocumentType.medical,
      isRequired: true,
      status: DocumentVerificationStatus.uploaded,
      uploadedLabel: '4 Jun 2026',
      verifiedBy: null,
      leadId: 'LD-1024',
    ),
  ];
}
