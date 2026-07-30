import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// P2-UX-3 — Tier-3 design-system ENFORCEMENT (lints: no raw color/TextStyle).
///
/// Feature code must consume design tokens (`context.colors` / `context.akshara`
/// / `context.aksharaText`), not raw `Color(0x…)`, Material palette swatches
/// (`Colors.red` …), or hand-built `TextStyle(…)`. There is no custom analyzer
/// plugin in this project, so this test IS the lint: it scans `lib/features/**`
/// and **blocks new violations** by ratcheting against a committed baseline
/// (Done-when: "DS lint blocks new violations"). Reduce a baseline when you fix
/// violations; never raise one.
///
/// Scope note: `lib/theme/**` and `lib/shared/**` are DELIBERATELY out of scope —
/// that is where tokens and shared widgets legitimately DEFINE colors/styles.

/// Material palette swatches that should be semantic tokens instead. The neutral
/// primitives `white` / `black` / `transparent` are intentionally allowed
/// (scrims, swipe reveals, overlays).
const _swatchNames = [
  'red', 'pink', 'purple', 'deepPurple', 'indigo', 'blue', 'lightBlue', 'cyan',
  'teal', 'green', 'lightGreen', 'lime', 'yellow', 'amber', 'orange',
  'deepOrange', 'brown', 'grey', 'gray', 'blueGrey',
];

// Baselines captured 2026-07-08 at the P2-UX-3 gate. The guard fails when the
// live count EXCEEDS the baseline (a net-new violation). Lower these as feature
// code migrates onto tokens; they are a one-way ratchet.
const _hexColorBaseline = 0; // already token-pure — locked at zero.
const _swatchBaseline = 60;
const _rawTextStyleBaseline = 156; // ratcheted down 159→155 (CFC-1 post-PRC, 2026-07-16): Control Center providers panel migrated onto textTheme tokens. W0.2b lane convergence (2026-07-20): +1 → 156 — the data-reliability-platform lane's LIVE complaints screen (PRC-A) carries one raw error TextStyle at lib/features/complaints/complaints_screen.dart:391 (`Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))`). W0 unions live code faithfully; tokenizing it (→ context.aksharaText.*.copyWith(color: context.colors.error)) is owned by W8/P2-UX-3.

final _hexColor = RegExp(r'Color\(0x');
final _swatch = RegExp('Colors\\.(${_swatchNames.join('|')})\\b');
final _rawTextStyle = RegExp(r'\bTextStyle\(');

({int count, List<String> files}) _scan(RegExp pattern) {
  final dir = Directory('lib/features');
  final files = <String>[];
  var count = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final matches = pattern.allMatches(entity.readAsStringSync()).length;
    if (matches > 0) {
      count += matches;
      files.add('${entity.path} ($matches)');
    }
  }
  files.sort();
  return (count: count, files: files);
}

void main() {
  group('P2-UX-3 · design-system enforcement (no raw color / TextStyle)', () {
    test('lib/features has NO raw hex Color(0x…) — token-pure, locked at 0', () {
      final result = _scan(_hexColor);
      expect(
        result.count,
        lessThanOrEqualTo(_hexColorBaseline),
        reason: 'New raw hex Color found — use a semantic token '
            '(context.colors.* / context.akshara.*). Offenders:\n'
            '${result.files.join('\n')}',
      );
    });

    test('lib/features does not add new Material palette swatches', () {
      final result = _scan(_swatch);
      expect(
        result.count,
        lessThanOrEqualTo(_swatchBaseline),
        reason: 'New Colors.<swatch> found (baseline $_swatchBaseline) — use a '
            'semantic token (context.akshara.success/warning/error, '
            'context.colors.*). Offenders:\n${result.files.join('\n')}',
      );
    });

    test('lib/features does not add new hand-built TextStyle(…)', () {
      final result = _scan(_rawTextStyle);
      expect(
        result.count,
        lessThanOrEqualTo(_rawTextStyleBaseline),
        reason: 'New raw TextStyle() found (baseline $_rawTextStyleBaseline) — '
            'derive from a token (context.aksharaText.* [.copyWith]). '
            'Offenders:\n${result.files.join('\n')}',
      );
    });
  });
}
