import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/mesh_background.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../admin/admin_content_scaffold.dart';
import '../admin/admin_layout.dart';
import '../admin/admin_shell.dart';
import '../admin/models/admin_nav_models.dart';
import '../copilot/copilot_context_provider.dart';
import 'director_models.dart';
import 'director_providers.dart';
import 'widgets/director_shared_widgets.dart';

/// DIR-D1 — the audited, READ-ONLY per-school drill-down opened by tapping a row
/// on the Director schools league table. It shows school-level aggregates only
/// (no student/parent PII) and performs NO writes and NO persona/token switch —
/// the director stays in their own session. The backend audits this read
/// (`director.school.drilldown`) and answers 404 for a foreign school, which
/// surfaces here as the standard error state.
class DirectorSchoolSnapshotScreen extends ConsumerWidget {
  const DirectorSchoolSnapshotScreen({super.key, required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directorSchoolSnapshotProvider(schoolId));
    return CopilotContextScope(
      module: 'director',
      screen: 'Director School Snapshot',
      child: AdminContentScaffold(
        breadcrumbs: const [
          AdminBreadcrumb(label: 'Admin Hub', route: RouteNames.admin),
          AdminBreadcrumb(label: 'Director Portal', route: RouteNames.director),
          AdminBreadcrumb(label: 'Schools', route: RouteNames.directorSchools),
          AdminBreadcrumb(label: 'School Snapshot'),
        ],
        onMenuTap: adminShellMenuTap(context),
        body: AksharaDashboardCanvas(
          palette: AksharaMeshPalette.director,
          watermark: AksharaWatermarkMotif.shield,
          child: KeyedSubtree(
            key: QaTestKeys.directorSchoolSnapshotScreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AksharaSpacing.s4),
                const _ReadOnlyAuditedBanner(),
                const SizedBox(height: AksharaSpacing.s4),
                const AksharaWarningBanner(
                  message: kDirectorPrivacyBannerMessage,
                  height: 40,
                  compactMessage: true,
                  semanticLabel: 'Director privacy notice',
                ),
                const SizedBox(height: AksharaSpacing.s4),
                ErpAsyncBody<DirectorSchoolSnapshot>(
                  state: resolveErpAsync(state, isDataEmpty: (_) => false),
                  loadingLabel: 'Loading',
                  emptyMessage: 'No school snapshot available.',
                  onRetry: () => ref.invalidate(
                    directorSchoolSnapshotProvider(schoolId),
                  ),
                  builder: (snapshot) => _SnapshotBody(snapshot: snapshot),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Read-only · audited" banner — makes the non-impersonation contract
/// explicit to the director on screen.
class _ReadOnlyAuditedBanner extends StatelessWidget {
  const _ReadOnlyAuditedBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    return Container(
      key: QaTestKeys.directorSchoolSnapshotReadOnlyBanner,
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s4,
        vertical: AksharaSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 18, color: colors.primary),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: Text(
              'Read-only · audited — this drill-down views aggregates only. '
              'No changes can be made here.',
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotBody extends StatelessWidget {
  const _SnapshotBody({required this.snapshot});

  final DirectorSchoolSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(snapshot.schoolName, style: text.headlineSmall),
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(snapshot.location, style: text.bodySmall),
                ],
              ),
            ),
            DirectorSchoolStatusChip(status: snapshot.status),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s4),
        _tiles(context),
        const SizedBox(height: AksharaSpacing.s5),
        const AksharaSectionHeader(title: 'Admissions funnel'),
        const SizedBox(height: AksharaSpacing.s3),
        _AdmissionsCard(snapshot: snapshot),
        const SizedBox(height: AksharaSpacing.s5),
        const AksharaSectionHeader(title: 'Academic health'),
        const SizedBox(height: AksharaSpacing.s3),
        _AcademicCard(snapshot: snapshot),
      ],
    );
  }

  Widget _tiles(BuildContext context) {
    final tiles = <Widget>[
      DirectorMetricTile(label: 'Students', value: '${snapshot.students}'),
      DirectorMetricTile(
        label: 'Attendance',
        value: '${snapshot.attendancePercent}%',
      ),
      DirectorMetricTile(
        label: 'Fee Collection',
        value: '${snapshot.feeCollectionPercent}%',
      ),
      DirectorMetricTile(label: 'Billed', value: '₹${snapshot.billedInr}'),
      DirectorMetricTile(label: 'Collected', value: '₹${snapshot.collectedInr}'),
      DirectorMetricTile(
        label: 'Outstanding',
        value: '₹${snapshot.outstandingInr}',
      ),
      DirectorMetricTile(label: 'Health', value: '${snapshot.healthScore}'),
    ];
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final tile in tiles) ...[
            tile,
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }
    return Wrap(
      spacing: AksharaSpacing.s3,
      runSpacing: AksharaSpacing.s3,
      children: [
        for (final tile in tiles) SizedBox(width: 200, child: tile),
      ],
    );
  }
}

class _AdmissionsCard extends StatelessWidget {
  const _AdmissionsCard({required this.snapshot});

  final DirectorSchoolSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inquiries ${snapshot.admissionsInquiries} · '
              'Applications ${snapshot.admissionsApplications}',
              style: text.bodyMedium,
            ),
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              'Enrolled ${snapshot.admissionsEnrolled} · '
              'Conversion ${snapshot.admissionsConversionPercent}%',
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AcademicCard extends StatelessWidget {
  const _AcademicCard({required this.snapshot});

  final DirectorSchoolSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Text(
          'Pass rate ${snapshot.academicPassPercent}% across '
          '${snapshot.academicGradedEntries} graded entries.',
          style: text.bodyMedium,
        ),
      ),
    );
  }
}
