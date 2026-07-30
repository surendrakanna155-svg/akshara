import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// C2 (Product Excellence Master Plan) — row density as a table PROPERTY, not an
/// app mode. `compact` (40px rows, tighter header + cell padding) suits the
/// high-volume clerk persona; `standard` (52px) is the calm default.
enum AksharaTableDensity { standard, compact }

/// Virtualized table with a fixed [DataTable] header and [ListView.builder] body.
///
/// Use for large ERP lists where building every [DataRow] at once is expensive.
class AksharaVirtualizedDataTable extends StatelessWidget {
  const AksharaVirtualizedDataTable({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.rowBuilder,
    this.headingRowHeight = 48,
    this.dataRowMinHeight = 52,
    this.dataRowMaxHeight = 72,
    this.showCheckboxColumn = false,
    this.tableHeight = 480,
    this.semanticLabel,
    this.density = AksharaTableDensity.standard,
  });

  final List<DataColumn> columns;
  final int rowCount;
  final DataRow Function(int index) rowBuilder;
  final double headingRowHeight;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final bool showCheckboxColumn;
  final double tableHeight;
  final String? semanticLabel;

  /// Row density; [AksharaTableDensity.compact] overrides the row/header heights
  /// with the clerk-density 40px preset.
  final AksharaTableDensity density;

  bool get _compact => density == AksharaTableDensity.compact;
  double get _rowMinHeight => _compact ? 40 : dataRowMinHeight;
  double get _headerHeight => _compact ? 40 : headingRowHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor;
    final headerStyle = theme.dataTableTheme.headingTextStyle ??
        context.aksharaText.tableHeader;
    final cellStyle = theme.dataTableTheme.dataTextStyle ??
        context.aksharaText.tableCell;

    return Semantics(
      container: true,
      label: semanticLabel ?? 'Data table, $rowCount rows',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _estimatedTableWidth(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderRow(
                columns: columns,
                height: _headerHeight,
                dividerColor: dividerColor,
                textStyle: headerStyle,
                showCheckboxColumn: showCheckboxColumn,
              ),
              SizedBox(
                height: tableHeight,
                child: rowCount == 0
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        itemCount: rowCount,
                        itemBuilder: (context, index) {
                          final row = rowBuilder(index);
                          return DefaultTextStyle(
                            style: cellStyle,
                            child: _VirtualDataRow(
                              row: row,
                              columnCount: columns.length,
                              minHeight: _rowMinHeight,
                              cellVerticalPadding:
                                  _compact ? AksharaSpacing.s1 : AksharaSpacing.s2,
                              dividerColor: dividerColor,
                              showCheckboxColumn: showCheckboxColumn,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _estimatedTableWidth(BuildContext context) {
    final minWidth = MediaQuery.sizeOf(context).width - (AksharaSpacing.s6 * 2);
    return minWidth < 960 ? 960 : minWidth;
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.height,
    required this.dividerColor,
    required this.textStyle,
    required this.showCheckboxColumn,
  });

  final List<DataColumn> columns;
  final double height;
  final Color dividerColor;
  final TextStyle? textStyle;
  final bool showCheckboxColumn;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      // DS V2 P2-7 — a filled header band (was bare text on the page bg) so the
      // header reads as a distinct row — premium, and clearer scanning. Uses
      // `surfaceContainerHighest` so it stays visible against the typical
      // `surfaceContainerLow` page the table sits on (the rows are transparent).
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Row(
        children: [
          if (showCheckboxColumn)
            const SizedBox(
              width: 56,
              child: Center(child: SizedBox(width: 18, height: 18)),
            ),
          for (final column in columns)
            Expanded(
              flex: column.numeric ? 1 : 2,
              // Match the data cells' horizontal padding so the header labels
              // line up with the column values below them (they didn't).
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AksharaSpacing.s3,
                ),
                child: DefaultTextStyle(
                  style:
                      textStyle ?? const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  child: column.label,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VirtualDataRow extends StatelessWidget {
  const _VirtualDataRow({
    required this.row,
    required this.columnCount,
    required this.minHeight,
    required this.cellVerticalPadding,
    required this.dividerColor,
    required this.showCheckboxColumn,
  });

  final DataRow row;
  final int columnCount;
  final double minHeight;
  final double cellVerticalPadding;
  final Color dividerColor;
  final bool showCheckboxColumn;

  @override
  Widget build(BuildContext context) {
    final cells = row.cells;
    final onSelect = row.onSelectChanged;

    return Material(
      color: row.color?.resolve({WidgetState.selected}) ?? Colors.transparent,
      child: InkWell(
        onTap: onSelect == null ? null : () => onSelect(true),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: dividerColor)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showCheckboxColumn)
                SizedBox(
                  width: 56,
                  child: Checkbox(
                    value: row.selected,
                    onChanged: onSelect,
                  ),
                ),
              for (var index = 0; index < columnCount; index++)
                Expanded(
                  flex: index < cells.length && _isNumericCell(cells[index]) ? 1 : 2,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AksharaSpacing.s3,
                      vertical: cellVerticalPadding,
                    ),
                    child: index < cells.length ? cells[index].child : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isNumericCell(DataCell cell) => false;
}
