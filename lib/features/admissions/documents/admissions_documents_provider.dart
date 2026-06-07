import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';

import '../../../core/repositories/repository_providers.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';

final admissionsDocumentsLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsDocumentsErrorProvider = StateProvider<bool>((ref) => false);
final admissionsDocumentsEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsDocumentsFilterProvider = StateProvider<int>((ref) => 0);

final admissionsSelectedDocumentIdProvider = StateProvider<String?>(
  (ref) => null,
);

final admissionsDocumentsFutureProvider = FutureProvider<List<StudentDocumentRecord>>((ref) async {
return ref.read(admissionsRepositoryProvider).getDocuments(query: ref.watch(repositoryQueryProvider));
});

final admissionsDocumentsProvider = Provider<List<StudentDocumentRecord>>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(admissionsDocumentsFutureProvider),
    manualLoading: ref.watch(admissionsDocumentsLoadingProvider), manualError: ref.watch(admissionsDocumentsErrorProvider), manualEmpty: ref.watch(admissionsDocumentsEmptyProvider),
  ) ?? const [];
});

final admissionsDocumentsViewStateProvider =
    Provider<AdmissionsViewState<List<StudentDocumentRecord>>>((ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsDocumentsFutureProvider),
    forceLoading: ref.watch(admissionsDocumentsLoadingProvider),
    forceError: ref.watch(admissionsDocumentsErrorProvider),
    forceEmpty: ref.watch(admissionsDocumentsEmptyProvider),
    isDataEmpty: (docs) => docs.isEmpty,
  );
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
