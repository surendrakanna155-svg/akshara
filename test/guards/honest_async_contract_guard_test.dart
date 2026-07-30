/// MECHANICAL GUARD — the honest-async contract (Phase 1 · RC-1).
///
/// Certification cycle 1 found twelve independent instances of demo/seed data
/// reaching a production render (CERT-001, CERT-002, CERT-006, JOURNEY-001,
/// JOURNEY-007, WIDGET-001, WIDGET-002, WIDGET-011, E2E-005, E2E-011, E2E-012,
/// E2E-021). They were not twelve bugs; they were **one idiom copied twelve
/// times**. The roadmap's rule for this wave is that a class is not fixed until
/// a test fails when it comes back.
///
/// This guard scans the SOURCE of `lib/` and fails if a production provider or
/// widget can put a fabricated business value on screen. It enforces the class,
/// not the twelve files: a `?? SomethingData.mock()` written next year in a
/// module that does not exist yet fails this test on its first run.
///
/// It is deliberately source-level rather than behavioural, because the defect
/// is a *reachable code path* and a behavioural test only covers the paths
/// someone remembered to write. The companion behavioural test is
/// `honest_async_render_guard_test.dart`.
///
/// ## Ratchets, not amnesties
/// Two lists below record pre-existing call sites this wave did not fix. Both
/// are asserted by **exact equality**, so the guard fails if a new one appears
/// AND fails if a listed one is fixed but left in the list. They can only
/// shrink.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one place fixture data may live: the mock repository lane, which is
/// resolved only when a module's API is disabled.
const String _mockLane = 'lib/core/repositories/mock/';

/// A fixture-data constructor call: `X.mock(…)`, `X.demoDefault(…)`,
/// `X.demoClassTeacher(…)`, `X.sample(…)`.
final RegExp _fixtureCall =
    RegExp(r'\b[A-Z]\w*\.(mock|demo[A-Z]\w*|sample)\s*\(');

/// An in-memory demo store / registry / bridge — fixture data behind a
/// singleton rather than behind a constructor.
final RegExp _demoStoreSymbol =
    RegExp(r'\bMock[A-Z]\w*(Store|Registry|Bridge|Workflow)\b');

/// The declaration of a fixture factory. Everything inside its body is exempt:
/// a fixture may compose other fixtures. What matters is that nothing OUTSIDE
/// a fixture body reaches one.
final RegExp _fixtureDecl = RegExp(
  r'^\s*(factory\s+\w+\.(mock|demo\w*|sample)\b'
  r'|static\s+[\w<>,\s?]+\s+(mock|demo\w*|sample|snapshotFor\w*|attentionFor\w*)\s*[\(<]'
  r'|[A-Za-z_]\w*\s+get\s+_?(mock|demo)\w*\s*(=>|\{))',
);

/// A terminal `??` fallback that hands back a fabricated shape. Matched against
/// the whitespace-collapsed file so multi-line `a ?? b ?? X.mock()` chains are
/// caught, while still requiring the fixture to be adjacent to the `??`.
final RegExp _fabricatedFallback = RegExp(
  r'\?\?\s*(const\s+)?\b[A-Z]\w*\.(mock|demo[A-Z]\w*|sample)\s*\('
  r'|\?\?\s*_fallback\w*\s*\(',
);

/// A compile-time KPI value. JOURNEY-001 was a `const` table of
/// `AksharaWorkspaceStat` values rendered as live figures to six staff roles.
final RegExp _compileTimeStat =
    RegExp(r'''AksharaWorkspaceStat\s*\(\s*value\s*:\s*['"]''');

/// RATCHET A — fixture-data constructor calls on a production path that this
/// wave did not remove. Each needs a reason; each may only be deleted.
const Map<String, String> _knownFixtureCallSites = {
  'lib/core/school_config/school_configuration_provider.dart':
      'SchoolConfiguration.demoDefault() — capability/branch defaults, not a '
          'displayed school figure. Fixing it changes which modules every '
          'persona sees, so it belongs with the school-configuration work, not '
          'this wave. Tracked as RC-1 residual.',
  'lib/core/teaching/teacher_assignment_registry.dart':
      'TeacherTeachingContext.demoClassTeacher() — resolves a TEACHING '
          'ASSIGNMENT when HR/SIS has none, not a figure shown as school data. '
          'The real fix is the HR assignment source (later roadmap item).',
  'lib/features/auth/auth_provider.dart':
      'AuthClaims.demoForRole() — QA-login claim seeding. Belongs to the RC-2 '
          'role-resolver work (JOURNEY-002/003), which replaces this path '
          'wholesale with one fail-closed resolver.',
};

/// RATCHET B — in-memory demo stores still referenced from production code.
/// E2E-005 (the corrections screen) was one of these and is fixed; the rest are
/// separate registered defects sequenced into later waves.
const Set<String> _knownDemoStoreCallSites = {
  'lib/features/auth/staff/staff_login_provider.dart',
  'lib/features/sis/integration/sis_admissions_integration_provider.dart',
  'lib/features/parent/transport/parent_transport_provider.dart',
  'lib/features/admissions/enrollment/admissions_enrollment_provider.dart',
  'lib/features/finance/integration/finance_admissions_handoff_provider.dart',
  'lib/features/teacher/attendance/teacher_attendance_provider.dart',
  'lib/features/teacher/communication/teacher_parent_communication_provider.dart',
  'lib/features/teacher/timetable/teacher_today_provider.dart',
};

void main() {
  final libFiles = _dartFilesUnder('lib');

  test('the guard is actually scanning the app', () {
    expect(libFiles.length, greaterThan(200));
  });

  group('honest-async contract — no fabricated value on a production path', () {
    test(
      'RULE 1 — no provider falls back to a fabricated shape '
      '(`?? X.mock()`, `?? _fallbackFoo()`)',
      () {
        final violations = <String>[];
        for (final file in libFiles) {
          if (_inMockLane(file)) continue;
          // Files on RATCHET A are excused HERE TOO — with a stated reason —
          // rather than silently: the same call site cannot be a violation
          // under one rule and excused under another.
          if (_knownFixtureCallSites.containsKey(_rel(file))) continue;
          final collapsed = _collapsedSource(file);
          for (final m in _fabricatedFallback.allMatches(collapsed)) {
            violations.add('${_rel(file)}  ->  ${m.group(0)!.trim()}…');
          }
        }
        expect(
          violations,
          isEmpty,
          reason:
              'A production provider falls back to fabricated data. Use a '
              'neutral `.empty()` shape (no money / attendance / names / '
              'counts) and let the screen render loading / error / empty via '
              'ErpAsyncBody or MobileAsyncBody.fromState.\n'
              'Violations:\n  ${violations.join('\n  ')}',
        );
      },
    );

    test(
      'RULE 2 — no production render path constructs fixture data',
      () {
        final offenders = <String, List<String>>{};
        for (final file in libFiles) {
          if (_inMockLane(file)) continue;
          final lines = file.readAsLinesSync();
          final exempt = _fixtureBodyLines(lines);
          for (var i = 0; i < lines.length; i++) {
            if (exempt.contains(i) || _isComment(lines[i])) continue;
            if (_isDirective(lines[i])) continue;
            if (_fixtureCall.hasMatch(lines[i])) {
              offenders
                  .putIfAbsent(_rel(file), () => [])
                  .add('${i + 1}: ${lines[i].trim()}');
            }
          }
        }
        _expectRatchet(
          actual: offenders.keys.toSet(),
          allowed: _knownFixtureCallSites.keys.toSet(),
          label: 'fixture-data constructor call sites',
          detail: offenders,
          fixHint:
              'Fixture constructors belong in $_mockLane, behind a mock '
              'repository that is unreachable once the module runs against the '
              'API. Production code must render server data or an honest '
              'loading / error / empty state.',
        );
      },
    );

    test(
      'RULE 3 — no production render path reads an in-memory demo store',
      () {
        final offenders = <String, List<String>>{};
        for (final file in libFiles) {
          // Scoped to the render path. `lib/core/**` stores wiring to each
          // other is infrastructure; what this rule forbids is a FEATURE
          // (provider or screen) reading a store that production never writes.
          if (!_rel(file).startsWith('lib/features/')) continue;
          final lines = file.readAsLinesSync();
          final exempt = _fixtureBodyLines(lines);
          for (var i = 0; i < lines.length; i++) {
            if (exempt.contains(i) || _isComment(lines[i])) continue;
            if (_isDirective(lines[i])) continue;
            if (_demoStoreSymbol.hasMatch(lines[i])) {
              offenders
                  .putIfAbsent(_rel(file), () => [])
                  .add('${i + 1}: ${lines[i].trim()}');
            }
          }
        }
        _expectRatchet(
          actual: offenders.keys.toSet(),
          allowed: _knownDemoStoreCallSites,
          label: 'in-memory demo store call sites',
          detail: offenders,
          fixHint:
              'E2E-005: `MockAttendanceSyncStore` is written ONLY by '
              '`MockTeacherRepository`, so in a release build it is empty and '
              'every claim derived from it is false. Source the value from its '
              'real endpoint, or remove the surface.',
        );
      },
    );

    test('RULE 4 — no compile-time KPI table anywhere in lib/', () {
      final violations = <String>[];
      for (final file in libFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_isComment(lines[i])) continue;
          if (_compileTimeStat.hasMatch(lines[i])) {
            violations.add('${_rel(file)}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            'A workspace/KPI stat is declared with a literal value. '
            'JOURNEY-001: `1,248 Students · 96% Attendance · ₹4.2L Collected` '
            'was rendered as live data to six staff roles on day one, on a '
            'tenant with zero students. Headline figures may only come from a '
            'real per-workspace provider.\n'
            'Violations:\n  ${violations.join('\n  ')}',
      );
    });

    test('RULE 5 — the sanctioned `.empty()` shapes carry no business values',
        () {
      // `honestPayload` may only hand back a NEUTRAL shape: no money, no
      // percentage, no clock time, no non-zero count. Without this rule RULE 1
      // is trivially satisfiable by renaming `mock()` to `empty()`.
      final violations = <String>[];
      var factoriesChecked = 0;
      for (final file in libFiles) {
        if (_inMockLane(file)) continue;
        for (final body in _emptyFactoryBodies(file.readAsStringSync())) {
          factoriesChecked++;
          for (final bad in _businessValueLiterals(body)) {
            violations.add('${_rel(file)}  ->  $bad');
          }
        }
      }
      expect(factoriesChecked, greaterThan(3),
          reason: 'No `.empty()` neutral shapes found — the contract has no '
              'sanctioned fallback, so RULE 1 proves nothing.');
      expect(
        violations,
        isEmpty,
        reason:
            'An `.empty()` neutral shape contains a business value. The whole '
            'point of the neutral shape is that it asserts nothing.\n'
            'Violations:\n  ${violations.join('\n  ')}',
      );
    });
  });

  group('honest-async contract — the contract itself is wired', () {
    test('the contract renders loading / error / empty from real state', () {
      final source =
          File('lib/shared/async/erp_async_state.dart').readAsStringSync();
      expect(source, contains('AksharaLoadingState'));
      expect(source, contains('AksharaErrorState.fromFailure'));
      expect(source, contains('AksharaEmptyState'));
      // `honestPayload` is the single sanctioned nullable -> non-null bridge.
      expect(source, contains('T honestPayload<T>'));
    });

    test('MobileAsyncBody.fromState derives state from the real AsyncValue', () {
      final source =
          File('lib/shared/widgets/mobile_async_body.dart').readAsStringSync();
      expect(source, contains('MobileAsyncBody.fromState'));
      expect(source, contains('state.isLoading'));
      expect(source, contains('state.hasError'));
    });

    test(
      'RULE 6 — no persona surface derives its state from manual flags alone',
      () {
        // The WIDGET-001 / WIDGET-002 mechanism: a screen reading only
        // `*LoadingProvider` / `*ErrorProvider` — `StateProvider<bool>`s that
        // production never writes — so the skeleton and the error branch are
        // dead code and the fabricated payload is the only thing that renders.
        const screens = [
          'lib/features/parent/dashboard/parent_dashboard_screen.dart',
          'lib/features/teacher/dashboard/teacher_dashboard_screen.dart',
          'lib/features/student_app/dashboard/student_dashboard_screen.dart',
          'lib/features/parent/fees/parent_fees_screen.dart',
          'lib/features/parent/homework/parent_homework_screen.dart',
          'lib/features/parent/payment/parent_payment_screen.dart',
        ];
        final violations = <String>[];
        for (final path in screens) {
          final source = File(path).readAsStringSync();
          final derivesFromAsync = source.contains('ViewStateProvider') ||
              source.contains('async.isLoading') ||
              source.contains('.fromState');
          if (!derivesFromAsync) violations.add(path);
        }
        expect(
          violations,
          isEmpty,
          reason:
              'These screens read only manual override providers, so their '
              'loading/error branches are unreachable in production:\n  '
              '${violations.join('\n  ')}',
        );
      },
    );

    test(
      'RULE 7 — no fabricated amount can reach the payment endpoint '
      '(JOURNEY-007)',
      () {
        final provider = File(
          'lib/features/parent/payment/parent_payment_provider.dart',
        ).readAsStringSync();

        // There is no fallback summary at all…
        expect(provider, isNot(contains('_fallbackSummary')));
        // …the summary is nullable, so "no server payload" is representable…
        expect(provider, contains('Provider<PaymentSummary?>'));
        // …the installment id does not default to a demo fixture id…
        expect(
          RegExp(r"parentPaymentInstallmentIdProvider\s*=\s*StateProvider<String>\(\s*\(ref\)\s*=>\s*''")
              .hasMatch(_collapsedSource(File(
                  'lib/features/parent/payment/parent_payment_provider.dart'))
              .replaceAll(' ', '')
              .replaceAll(
                  "parentPaymentInstallmentIdProvider=StateProvider<String>((ref)=>''",
                  "parentPaymentInstallmentIdProvider = StateProvider<String>((ref) => ''")),
          isTrue,
          reason: 'The pay screen must not default to a demo installment id.',
        );
        // …and submit refuses without a server-issued, positive amount.
        expect(
          _collapsedSource(File(
            'lib/features/parent/payment/parent_payment_provider.dart',
          )),
          contains('summary.totalAmount <= 0'),
          reason: 'submitParentPayment must refuse to initiate without a '
              'server-issued summary carrying a positive amount.',
        );
        final submitBody = provider.substring(
          provider.indexOf('Future<void> submitParentPayment'),
        );
        final guardIndex = submitBody.indexOf('summary == null');
        final initiateIndex = submitBody.indexOf('ParentPaymentInitiateRequest');
        expect(guardIndex, greaterThanOrEqualTo(0));
        expect(
          guardIndex,
          lessThan(initiateIndex),
          reason: 'The money guard must run BEFORE the initiate call is built.',
        );
      },
    );
  });
}

// ── helpers ────────────────────────────────────────────────────────────────

void _expectRatchet({
  required Set<String> actual,
  required Set<String> allowed,
  required String label,
  required Map<String, List<String>> detail,
  required String fixHint,
}) {
  final added = actual.difference(allowed).toList()..sort();
  final stale = allowed.difference(actual).toList()..sort();
  final message = StringBuffer()
    ..writeln('The $label ratchet moved.')
    ..writeln(fixHint);
  if (added.isNotEmpty) {
    message.writeln('\nNEW violations (fix these — do not add them to the '
        'allow-list):');
    for (final path in added) {
      message.writeln('  $path');
      for (final line in detail[path] ?? const <String>[]) {
        message.writeln('      $line');
      }
    }
  }
  if (stale.isNotEmpty) {
    message.writeln('\nFIXED but still listed (delete these entries so the '
        'ratchet tightens):');
    for (final path in stale) {
      message.writeln('  $path');
    }
  }
  expect(added, isEmpty, reason: message.toString());
  expect(stale, isEmpty, reason: message.toString());
}

List<File> _dartFilesUnder(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList(growable: false);

String _rel(File f) => f.path.replaceFirst(RegExp(r'^\./'), '');

bool _inMockLane(File f) => _rel(f).startsWith(_mockLane);

bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

bool _isDirective(String line) {
  final t = line.trimLeft();
  return t.startsWith('import ') || t.startsWith('export ') ||
      t.startsWith('part ');
}

/// The file with comments removed and whitespace collapsed, so a multi-line
/// `a ?? b ?? X.mock()` chain reads as one line.
String _collapsedSource(File file) {
  final kept = <String>[];
  for (final line in file.readAsLinesSync()) {
    if (_isComment(line)) continue;
    kept.add(line.split('//').first);
  }
  return kept.join(' ').replaceAll(RegExp(r'\s+'), ' ');
}

/// Line indices inside a fixture-factory body (brace matched).
Set<int> _fixtureBodyLines(List<String> lines) {
  final exempt = <int>{};
  for (var i = 0; i < lines.length; i++) {
    if (!_fixtureDecl.hasMatch(lines[i])) continue;
    var depth = 0;
    var started = false;
    for (var j = i; j < lines.length; j++) {
      exempt.add(j);
      for (final ch in lines[j].split('')) {
        if (ch == '{') {
          depth++;
          started = true;
        } else if (ch == '}') {
          depth--;
        }
      }
      // An expression-bodied fixture (`=> Foo(...);`) ends at its semicolon.
      if (!started && lines[j].trimRight().endsWith(';')) break;
      if (started && depth <= 0) break;
    }
  }
  return exempt;
}

Iterable<String> _emptyFactoryBodies(String source) sync* {
  for (final match in RegExp(
    r'(factory\s+\w+\.empty|static\s+[\w<>?]+\s+empty)\s*\([^)]*\)\s*\{',
  ).allMatches(source)) {
    final buffer = StringBuffer();
    var depth = 0;
    var started = false;
    for (var i = match.end - 1; i < source.length; i++) {
      final ch = source[i];
      buffer.write(ch);
      if (ch == '{') {
        depth++;
        started = true;
      } else if (ch == '}') {
        depth--;
        if (started && depth == 0) break;
      }
    }
    yield buffer.toString();
  }
}

/// Money, percentages, clock times and non-zero counts inside a neutral shape.
Iterable<String> _businessValueLiterals(String body) sync* {
  for (final m in RegExp(r"'[^']*₹[^']*'").allMatches(body)) {
    yield m.group(0)!;
  }
  for (final m in RegExp(r"'\s*\d+(\.\d+)?\s*%\s*'").allMatches(body)) {
    yield m.group(0)!;
  }
  for (final m in RegExp(r"'\s*\d{1,2}:\d{2}\s*(AM|PM)\s*'").allMatches(body)) {
    yield m.group(0)!;
  }
  // A named field assigned a non-zero number, e.g. `unreadNotifications: 2`.
  for (final m in RegExp(r'\b\w+:\s*([1-9]\d*)\b').allMatches(body)) {
    yield m.group(0)!;
  }
}
