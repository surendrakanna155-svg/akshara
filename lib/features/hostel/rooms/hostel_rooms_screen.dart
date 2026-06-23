import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hostel_models.dart';
import '../hostel_providers.dart';
import '../hostel_workflow_actions.dart';
import '../widgets/hostel_kpi_row.dart';
import '../widgets/hostel_module_scaffold.dart';

/// HO-03 — Rooms.
class HostelRoomsScreen extends ConsumerWidget {
  const HostelRoomsScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Occupied',
    'Vacant',
    'Maintenance',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hostelRoomsLoadingProvider);
    final isError = ref.watch(hostelRoomsErrorProvider);
    final isEmpty = ref.watch(hostelRoomsEmptyProvider);
    final rooms = ref.watch(hostelFilteredRoomsProvider);
    final filterIndex = ref.watch(hostelRoomsFilterProvider);
    final pageResult = ref.watch(hostelRoomsPageResultProvider);

    return HostelModuleScaffold(
      screen: HostelScreen.rooms,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hostelRoomsFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageHostel,
        child: OutlinedButton.icon(
          key: QaTestKeys.hostelAddRoomButton,
          onPressed: () => showCreateHostelRoomDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add room'),
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        rooms: rooms,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<HostelRoom> rooms,
    required PaginatedResult<HostelRoom>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading hostel rooms'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load hostel rooms.',
      );
    }

    if (isEmpty || rooms.isEmpty) {
      return const AksharaEmptyState(
        message: 'No rooms match the selected filters.',
        icon: Icons.bed_outlined,
      );
    }

    final occupied = rooms.where((r) => r.status == HostelRoomStatus.occupied);
    final totalBeds = rooms.fold<int>(0, (sum, r) => sum + r.totalBeds);
    final occupiedBeds =
        rooms.fold<int>(0, (sum, r) => sum + r.occupiedBeds);
    final avgOccupancy = totalBeds == 0
        ? 0
        : ((occupiedBeds / totalBeds) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HostelKpiRow(
          kpis: [
            HostelKpi(
              id: 'rooms',
              value: '${rooms.length}',
              label: 'Rooms',
              icon: Icons.meeting_room_outlined,
              accentName: 'primary',
            ),
            HostelKpi(
              id: 'occupied',
              value: '${occupied.length}',
              label: 'Occupied',
              icon: Icons.bed_outlined,
              accentName: 'success',
            ),
            HostelKpi(
              id: 'avg_occ',
              value: '$avgOccupancy%',
              label: 'Avg occupancy',
              icon: Icons.pie_chart_outline,
              accentName: 'neutral',
            ),
          ],
          desktopColumns: 3,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Room catalog'),
        const SizedBox(height: AksharaSpacing.s3),
        _RoomsTable(rooms: rooms),
        AksharaPaginatedListFooter<HostelRoom>(
          result: pageResult,
          pageProvider: hostelRoomsPageProvider,
        ),
      ],
    );
  }
}

class _RoomsTable extends StatelessWidget {
  const _RoomsTable({required this.rooms});

  final List<HostelRoom> rooms;

  String _typeLabel(HostelRoomType type) => switch (type) {
        HostelRoomType.standard => 'Standard',
        HostelRoomType.ac => 'AC',
        HostelRoomType.dormitory => 'Dormitory',
        HostelRoomType.staff => 'Staff',
      };

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final room in rooms) ...[
            _RoomCard(room: room, typeLabel: _typeLabel(room.type)),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Hostel rooms table, ${rooms.length} rooms',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Block')),
              DataColumn(label: Text('Room')),
              DataColumn(label: Text('Floor')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Beds')),
              DataColumn(label: Text('Occupied')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Facilities')),
            ],
            rows: [
              for (final room in rooms)
                DataRow(
                  cells: [
                    DataCell(Text(room.block)),
                    DataCell(Text(room.roomNumber)),
                    DataCell(Text('${room.floor}')),
                    DataCell(Text(_typeLabel(room.type))),
                    DataCell(Text('${room.totalBeds}')),
                    DataCell(Text('${room.occupiedBeds}')),
                    DataCell(_RoomStatusChip(status: room.status)),
                    DataCell(Text(room.facilities)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.typeLabel});

  final HostelRoom room;
  final String typeLabel;

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
            Text('${room.block} ${room.roomNumber}', style: text.titleSmall),
            Text(
              'Floor ${room.floor} · $typeLabel · ${room.occupiedBeds}/${room.totalBeds} beds',
              style: text.bodyMedium,
            ),
            Text(room.facilities, style: text.bodySmall),
            const SizedBox(height: AksharaSpacing.s2),
            _RoomStatusChip(status: room.status),
          ],
        ),
      ),
    );
  }
}

class _RoomStatusChip extends StatelessWidget {
  const _RoomStatusChip({required this.status});

  final HostelRoomStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      HostelRoomStatus.occupied => ('Occupied', KpiAccent.primary),
      HostelRoomStatus.vacant => ('Vacant', KpiAccent.success),
      HostelRoomStatus.maintenance => ('Maintenance', KpiAccent.warning),
      HostelRoomStatus.alert => ('Alert', KpiAccent.error),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Room status: $label',
    );
  }
}
