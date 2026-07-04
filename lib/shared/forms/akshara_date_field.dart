import 'package:flutter/material.dart';

/// XCT-3 — the shared date-picker field. Replaces free-text `YYYY-MM-DD`
/// `TextField`s (which accept typos, impossible dates, and wrong formats) with a
/// tap-to-open [showDatePicker]. The field is read-only; the chosen day is
/// written back into [controller] as a canonical ISO `yyyy-MM-dd` string, so
/// existing call sites that read `controller.text.trim()` keep working unchanged
/// — they just can no longer receive malformed input.
class AksharaDateField extends StatefulWidget {
  const AksharaDateField({
    super.key,
    required this.controller,
    required this.labelText,
    this.firstDate,
    this.lastDate,
    this.helperText,
    this.onChanged,
  });

  /// Holds the selected date as an ISO `yyyy-MM-dd` string (read/written here).
  final TextEditingController controller;
  final String labelText;

  /// Selectable range. Defaults to a wide, sensible span around today.
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? helperText;

  /// Called with the ISO string after a date is picked (for forms that also
  /// keep their own draft state alongside the controller).
  final ValueChanged<String>? onChanged;

  /// Formats a [DateTime] as a zero-padded ISO `yyyy-MM-dd` date (no intl dep).
  static String formatIso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  State<AksharaDateField> createState() => _AksharaDateFieldState();
}

class _AksharaDateFieldState extends State<AksharaDateField> {
  Future<void> _pick() async {
    final now = DateTime.now();
    final DateTime first = widget.firstDate ?? DateTime(now.year - 5);
    final DateTime last = widget.lastDate ?? DateTime(now.year + 5);
    final existing = DateTime.tryParse(widget.controller.text.trim());
    DateTime initial = existing ?? now;
    // Clamp the initial date into the allowed range so the picker never throws.
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    final iso = AksharaDateField.formatIso(picked);
    widget.controller.text = iso;
    widget.onChanged?.call(iso);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      readOnly: true,
      onTap: _pick,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
    );
  }
}
