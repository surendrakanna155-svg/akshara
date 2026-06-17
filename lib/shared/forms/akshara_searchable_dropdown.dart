import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Searchable dropdown for form catalogs (classes, sections, etc.).
class AksharaSearchableDropdown extends StatelessWidget {
  const AksharaSearchableDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.required = false,
    this.errorText,
    this.resolveSelection,
    this.enabled = true,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool required;
  final String? errorText;
  final String Function(String selected, List<String> options)? resolveSelection;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    final selection = resolveSelection != null
        ? resolveSelection!(value, options)
        : options.contains(value)
            ? value
            : (options.isNotEmpty ? options.first : value);
    final decorationLabel = required ? '$label *' : label;

    final enableFilter = options.length > 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownMenu<String>(
          key: ValueKey('$decorationLabel-$selection'),
          enabled: enabled,
          initialSelection: selection,
          label: Text(decorationLabel),
          expandedInsets: EdgeInsets.zero,
          requestFocusOnTap: true,
          enableFilter: enableFilter,
          filterCallback: enableFilter
              ? (entries, filter) {
                  if (filter.isEmpty) return entries;
                  final query = filter.toLowerCase();
                  return entries
                      .where((entry) => entry.label.toLowerCase().contains(query))
                      .toList();
                }
              : null,
          dropdownMenuEntries: [
            for (final option in options)
              DropdownMenuEntry(value: option, label: option),
          ],
          onSelected: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: AksharaSpacing.s1),
          Text(
            errorText!,
            style: text.bodySmall.copyWith(color: colors.error),
          ),
        ],
      ],
    );
  }
}
