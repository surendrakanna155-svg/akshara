import 'package:akshara_erp/core/dai/dai_intent.dart';
import 'package:akshara_erp/core/dai/dai_resolver.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

/// One golden corpus row: what a real user types, and what NIKSHA OS must do.
class _Case {
  const _Case(this.query, this.kind, {this.route, this.check});
  final String query;
  final DaiIntentKind kind;
  final String? route;
  final void Function(DaiIntent)? check;
}

/// The DAI golden corpus.
///
/// This is the NLU certification: every phrasing a principal, teacher, parent or
/// student is expected to type, with the destination it must resolve to. Because
/// [DaiResolver] is pure, this corpus is a hard contract — a regression cannot
/// hide behind flakiness.
///
/// Add a row whenever a real user says something we did not anticipate. Never
/// delete a row to make a change pass.
const _corpus = <_Case>[
  // ── Principal ──────────────────────────────────────────────────────────────
  _Case('Show fee defaulters', DaiIntentKind.feeDefaulters,
      route: RouteNames.financeDefaulters),
  _Case('fee defaulters', DaiIntentKind.feeDefaulters),
  _Case('pending fees', DaiIntentKind.feeDefaulters),
  _Case('outstanding dues', DaiIntentKind.feeDefaulters),
  _Case('unpaid fees', DaiIntentKind.feeDefaulters),

  _Case('Students below 75% attendance', DaiIntentKind.lowAttendance),
  _Case('attendance below 75', DaiIntentKind.lowAttendance),
  _Case('students under 60 percent attendance', DaiIntentKind.lowAttendance),
  _Case('attendance less than 80%', DaiIntentKind.lowAttendance),

  _Case("Today's attendance", DaiIntentKind.attendanceToday),
  _Case('attendance today', DaiIntentKind.attendanceToday),

  _Case('Open Teacher Ravi', DaiIntentKind.openPerson),
  _Case('teacher ravi', DaiIntentKind.openPerson),
  _Case('Rohan', DaiIntentKind.openPerson),
  _Case('staff Priya', DaiIntentKind.openPerson),

  _Case('Class 8A', DaiIntentKind.openClass),
  _Case('grade 10', DaiIntentKind.openClass),

  _Case('Bus 5', DaiIntentKind.openTransport),
  _Case('Transport Route 3', DaiIntentKind.openTransport),
  _Case('route 12', DaiIntentKind.openTransport),

  _Case('Fee Receipt 1023', DaiIntentKind.openReceipt),
  _Case('receipt no 4471', DaiIntentKind.openReceipt),

  // ── Teacher ────────────────────────────────────────────────────────────────
  _Case('Pending homework', DaiIntentKind.homework),
  _Case('Homework pending', DaiIntentKind.homework),
  _Case('show homework', DaiIntentKind.homework),

  // ── Parent ─────────────────────────────────────────────────────────────────
  _Case('Has my child paid fees?', DaiIntentKind.myFees,
      route: RouteNames.parentFees),
  _Case('my fees', DaiIntentKind.myFees),

  // ── Student ────────────────────────────────────────────────────────────────
  _Case('My attendance', DaiIntentKind.myAttendance,
      route: RouteNames.studentAttendance),
  _Case('My exam schedule', DaiIntentKind.exams,
      route: RouteNames.studentExams),

  // ── Must NOT resolve ───────────────────────────────────────────────────────
  // The resolver refuses rather than guesses. These fall through to plain
  // directory search in the UI.
  _Case('', DaiIntentKind.unknown),
  _Case('   ', DaiIntentKind.unknown),
  _Case('asdfghjkl qwertyuiop zxcvbnm plus more words', DaiIntentKind.unknown),
];

void main() {
  group('DAI golden corpus — deterministic intent, zero cloud calls', () {
    for (final c in _corpus) {
      test('"${c.query}" -> ${c.kind.name}', () {
        final intent = DaiResolver.resolve(c.query);
        expect(intent.kind, c.kind, reason: 'resolved: $intent');
        if (c.route != null) expect(intent.route, c.route);
        c.check?.call(intent);
      });
    }
  });

  group('entity extraction', () {
    test('threshold is captured from every comparator phrasing', () {
      for (final q in [
        'students below 75% attendance',
        'attendance under 75',
        'attendance less than 75 percent',
      ]) {
        expect(DaiResolver.resolve(q).threshold, 75, reason: q);
      }
    });

    test('class and section are captured together', () {
      final i = DaiResolver.resolve('Class 8A');
      expect(i.className, '8');
      expect(i.section, 'A');
    });

    test('a class scope narrows a fee-defaulter query', () {
      final i = DaiResolver.resolve('Grade 10 fee defaulters');
      expect(i.kind, DaiIntentKind.feeDefaulters);
      expect(i.className, '10');
      expect(i.answer, contains('Class 10'));
    });

    test('bus number is captured', () {
      expect(DaiResolver.resolve('Bus 5').routeNumber, 5);
      expect(DaiResolver.resolve('Transport Route 3').routeNumber, 3);
    });

    test('receipt number is captured', () {
      expect(DaiResolver.resolve('Fee Receipt 1023').receiptNumber, '1023');
    });

    test('an explicit person qualifier outscores a bare name', () {
      final qualified = DaiResolver.resolve('teacher Ravi');
      final bare = DaiResolver.resolve('Ravi');
      expect(qualified.personHint, DaiPersonHint.staff);
      expect(bare.personHint, DaiPersonHint.any);
      expect(qualified.confidence, greaterThan(bare.confidence));
    });
  });

  group('safety contract', () {
    test('resolves meaning, never access — destinations carry a permission', () {
      // The resolver must not be the thing that decides who may see fees.
      final i = DaiResolver.resolve('show fee defaulters');
      expect(i.requiredPermission, Permission.viewFinance);
    });

    test('a person query defers to the RBAC-scoped directory, not a name index',
        () {
      final i = DaiResolver.resolve('Rohan');
      expect(i.needsDirectoryLookup, isTrue,
          reason: 'the DAI layer must not resolve a person to an id itself — '
              'the directory lookup is where tenancy and RBAC are enforced');
      expect(i.route, isNull);
    });

    test('every answer is composed, never empty, for a resolved intent', () {
      for (final c in _corpus.where((c) => c.kind != DaiIntentKind.unknown)) {
        expect(DaiResolver.resolve(c.query).answer, isNotEmpty, reason: c.query);
      }
    });

    test('is pure — the same query always resolves identically', () {
      for (final c in _corpus) {
        final a = DaiResolver.resolve(c.query);
        final b = DaiResolver.resolve(c.query);
        expect(a.kind, b.kind);
        expect(a.route, b.route);
        expect(a.answer, b.answer);
        expect(a.confidence, b.confidence);
      }
    });

    test('below the confidence floor nothing is returned as understood', () {
      final i = DaiResolver.resolve('asdfghjkl qwertyuiop zxcvbnm plus more words');
      expect(i.isResolved, isFalse);
    });
  });

  group('fuzz — never throws, never resolves garbage confidently', () {
    test('survives punctuation, unicode, length and emptiness', () {
      const inputs = [
        '???', '...', '!!!', '@@@ ###', '   \t  \n ',
        '🎓📚', 'ಕನ್ನಡ', 'తెలుగు', 'हिन्दी',
        'a', 'ab', '1', '999999999',
        'fee fee fee fee fee fee fee fee fee fee',
        'SHOW FEE DEFAULTERS', 'ShOw FeE dEfAuLtErS',
        'show  fee   defaulters',
        r'DROP TABLE students; --',
        '<script>alert(1)</script>',
      ];
      for (final input in inputs) {
        late DaiIntent i;
        expect(() => i = DaiResolver.resolve(input), returnsNormally,
            reason: input);
        if (i.isResolved) {
          expect(i.confidence, greaterThanOrEqualTo(DaiResolver.minConfidence),
              reason: input);
        }
      }
    });

    test('case and spacing do not change the outcome', () {
      final a = DaiResolver.resolve('SHOW FEE DEFAULTERS');
      final b = DaiResolver.resolve('show  fee   defaulters');
      expect(a.kind, DaiIntentKind.feeDefaulters);
      expect(b.kind, a.kind);
      expect(b.route, a.route);
    });

    test('an injection-shaped string is never treated as a person', () {
      final i = DaiResolver.resolve(r'DROP TABLE students; --');
      expect(i.kind, isNot(DaiIntentKind.openPerson));
    });
  });
}
