import 'package:flutter/material.dart';

import '../../theme/spacing.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor;
    final headerStyle = theme.dataTableTheme.headingTextStyle ??
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);

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
                height: headingRowHeight,
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
                          return _VirtualDataRow(
                            row: row,
                            columnCount: columns.length,
                            minHeight: dataRowMinHeight,
                            dividerColor: dividerColor,
                            showCheckboxColumn: showCheckboxColumn,
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
      decoration: BoxDecoration(
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
              child: DefaultTextStyle(
                style: textStyle ?? const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                child: column.label,
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
    required this.dividerColor,
    required this.showCheckboxColumn,
  });

  final DataRow row;
  final int columnCount;
  final double minHeight;
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: AksharaSpacing.s3,
                      vertical: AksharaSpacing.s2,
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
