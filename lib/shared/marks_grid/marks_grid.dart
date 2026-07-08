import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../widgets/akshara_status_chip.dart';

// P2-UX-2 §2.2/2.5 — the ONE shared spreadsheet-grade marks-entry kit. Both
// marks chains (the rich exam-admin grid and the teacher grid) render these
// primitives so a mark is entered, tracked and totalled the SAME way
// everywhere — a locked number-pad cell, a per-cell save-state dot, and an
// inline column-stats footer. The kit is presentation only: each chain keeps
// its own model, providers, validation and save path.

/// Per-cell save state, shown by [MarksCellSaveDot].
enum MarksCellState {
  /// No mark typed yet.
  empty,

  /// Typed but not yet persisted (differs from the saved value).
  unsaved,

  /// A save is in flight.
  saving,

  /// The field matches the persisted mark.
  saved,

  /// The last save failed.
  error,
}

/// A small dot that tells the teacher, at a glance, whether a cell's mark is
/// saved, still dirty, mid-save or errored — the spreadsheet "unsaved cell"
/// affordance, one per row.
class MarksCellSaveDot extends StatelessWidget {
  const MarksCellSaveDot({super.key, required this.state, this.size = 10});

  final MarksCellState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ext = context.akshara;
    final colors = context.colors;

    if (state == MarksCellState.saving) {
      return SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 1.6),
      );
    }

    final (color, semantic) = switch (state) {
      MarksCellState.empty => (colors.outlineVariant, 'not entered'),
      MarksCellState.unsaved => (ext.warning, 'unsaved'),
      MarksCellState.saved => (ext.success, 'saved'),
      MarksCellState.error => (colors.error, 'save failed'),
      MarksCellState.saving => (colors.primary, 'saving'),
    };

    return Semantics(
      label: 'Mark $semantic',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: state == MarksCellState.empty ? Colors.transparent : color,
          shape: BoxShape.circle,
          border: state == MarksCellState.empty
              ? Border.all(color: color)
              : null,
        ),
      ),
    );
  }
}

/// The shared locked number-pad marks field: digits only, a `/max` suffix, and
/// (for the admin grid) Enter/Tab advancing to the next row. A single place so
/// both chains validate and key marks identically.
class MarksEntryField extends StatelessWidget {
  const MarksEntryField({
    super.key,
    required this.controller,
    required this.maxMarks,
    this.enabled = true,
    this.focusNode,
    this.onSubmitted,
    this.fieldKey,
    this.width = 88,
    this.label = 'Marks',
  });

  final TextEditingController controller;
  final int maxMarks;
  final bool enabled;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;
  final Key? fieldKey;
  final double width;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixText: '/$maxMarks',
        ),
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      ),
    );
  }
}

/// The inline column-stats footer: how many of the roster are entered, how many
/// are still pending, and the class average — the "you're X/Y done" line every
/// spreadsheet grid carries. [averagePercent] is null when nothing is entered.
class MarksColumnStats extends StatelessWidget {
  const MarksColumnStats({
    super.key,
    required this.entered,
    required this.total,
    this.averagePercent,
    this.maxMarks,
  });

  final int entered;
  final int total;
  final double? averagePercent;
  final int? maxMarks;

  int get pending => (total - entered).clamp(0, total);

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    final avg = averagePercent;

    return Semantics(
      container: true,
      label: 'Marks progress: $entered of $total entered, $pending pending'
          '${avg == null ? '' : ', average ${avg.round()} percent'}',
      child: Row(
        children: [
          Icon(Icons.grid_on_outlined, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: Text(
              [
                '$entered / $total entered',
                if (pending > 0) '$pending pending',
                if (avg != null) 'avg ${avg.round()}%',
                if (maxMarks != null) 'max $maxMarks',
              ].join(' · '),
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          if (pending == 0 && total > 0)
            const AksharaStatusChip(
              label: 'All entered',
              tone: KpiAccent.success,
            ),
        ],
      ),
    );
  }
}
