import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../library_models.dart';
import '../library_providers.dart';
import '../widgets/library_module_scaffold.dart';

/// LB-05 — Library Members.
class LibraryMembersScreen extends ConsumerWidget {
  const LibraryMembersScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Students',
    'Teachers',
    'Blocked',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(libraryMembersLoadingProvider);
    final isError = ref.watch(libraryMembersErrorProvider);
    final isEmpty = ref.watch(libraryMembersEmptyProvider);
    final members = ref.watch(libraryFilteredMembersProvider);
    final filterIndex = ref.watch(libraryMembersFilterProvider);
    final pageResult = ref.watch(libraryMembersPageResultProvider);

    return LibraryModuleScaffold(
      screen: LibraryScreen.members,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(libraryMembersFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageLibrary,
        child: OutlinedButton.icon(
          onPressed: () => context.go(RouteNames.sisStudents),
          icon: const Icon(Icons.badge_outlined, size: 18),
          label: const Text('SIS registry'),
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        members: members,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<LibraryMember> members,
    required PaginatedResult<LibraryMember>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading library members'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load library members.',
      );
    }

    if (isEmpty || members.isEmpty) {
      return const AksharaEmptyState(
        message: 'No members match the selected filters.',
        icon: Icons.groups_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Library members'),
        const SizedBox(height: AksharaSpacing.s3),
        _MembersTable(members: members),
        AksharaPaginatedListFooter<LibraryMember>(
          result: pageResult,
          pageProvider: libraryMembersPageProvider,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              'Student members link to SIS-STU registry. Blocked members have fines exceeding the configured limit.',
          actionLabel: 'View SIS',
          icon: Icons.badge_outlined,
          semanticLabelPrefix: 'SIS integration',
          onAction: () => context.go(RouteNames.sisStudents),
        ),
      ],
    );
  }
}

class _MembersTable extends StatelessWidget {
  const _MembersTable({required this.members});

  final List<LibraryMember> members;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final member in members) ...[
            _MemberCard(member: member),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Library members table, ${members.length} members',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Class / Dept')),
              DataColumn(label: Text('Active loans')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final member in members)
                DataRow(
                  onSelectChanged: member.sisStudentId != null
                      ? (_) => context.go(
                            RouteNames.sisStudentDetail(member.sisStudentId!),
                          )
                      : null,
                  cells: [
                    DataCell(Text(member.name)),
                    DataCell(Text(_memberTypeLabel(member.memberType))),
                    DataCell(Text(member.identifier)),
                    DataCell(Text(member.classOrDepartment)),
                    DataCell(Text('${member.activeLoans}')),
                    DataCell(_MemberStatusChip(status: member.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _memberTypeLabel(LibraryMemberType type) => switch (type) {
        LibraryMemberType.student => 'Student',
        LibraryMemberType.teacher => 'Teacher',
        LibraryMemberType.staff => 'Staff',
      };
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});

  final LibraryMember member;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label:
          '${member.name}, ${member.activeLoans} active loans, ${member.classOrDepartment}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(member.name, style: text.titleSmall),
              Text(member.classOrDepartment, style: text.bodyMedium),
              Text(
                '${member.activeLoans} active loans',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              _MemberStatusChip(status: member.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberStatusChip extends StatelessWidget {
  const _MemberStatusChip({required this.status});

  final LibraryMemberStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      LibraryMemberStatus.active => ('Active', KpiAccent.success),
      LibraryMemberStatus.blocked => ('Blocked', KpiAccent.error),
      LibraryMemberStatus.expired => ('Expired', KpiAccent.warning),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Member status: $label',
    );
  }
}
