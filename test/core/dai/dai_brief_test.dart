import 'package:akshara_erp/core/dai/dai_brief.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Principal Morning Brief — deterministic composition', () {
    test('says nothing when there is nothing to say', () {
      // A brief that manufactures filler to look busy is worse than silence.
      expect(DaiBriefComposer.compose(const DaiBriefFacts()), isEmpty);
      expect(DaiBriefComposer.headline(const []),
          'Nothing needs your attention this morning.');
    });

    test('orders by urgency to the school, not by module', () {
      final lines = DaiBriefComposer.compose(const DaiBriefFacts(
        pendingApprovals: 3,
        feeDefaulters: 12,
        atRiskStudents: 4,
        admissionsJoinedMtd: 8,
        staffAbsentToday: 2,
      ));
      final texts = lines.map((l) => l.text).toList();
      // Approvals block other people, so they come first; good news comes last.
      expect(texts.first, contains('approvals'));
      expect(texts.last, contains('admissions'));
      expect(
        texts.indexWhere((t) => t.contains('outstanding')),
        lessThan(texts.indexWhere((t) => t.contains('at risk'))),
        reason: 'money precedes at-risk in the agreed ordering',
      );
    });

    test('singular and plural are both correct', () {
      final one = DaiBriefComposer.compose(const DaiBriefFacts(pendingApprovals: 1));
      expect(one.first.text, '1 approval is waiting on you.');
      final many = DaiBriefComposer.compose(const DaiBriefFacts(pendingApprovals: 4));
      expect(many.first.text, '4 approvals are waiting on you.');
    });

    test('escalates tone with volume, and never beyond the facts', () {
      expect(
        DaiBriefComposer.compose(const DaiBriefFacts(pendingApprovals: 2)).first.tone,
        DaiBriefTone.warning,
      );
      expect(
        DaiBriefComposer.compose(const DaiBriefFacts(pendingApprovals: 9)).first.tone,
        DaiBriefTone.critical,
      );
    });

    test('reports the money figure finance computed, never a re-derived one', () {
      final lines = DaiBriefComposer.compose(const DaiBriefFacts(
        feeDefaulters: 12,
        feeOutstanding: '₹4,20,000',
      ));
      final money = lines.firstWhere((l) => l.text.contains('outstanding'));
      expect(money.text, contains('₹4,20,000'));
    });

    test('good fee news is only stated when there are genuinely no defaulters',
        () {
      final good = DaiBriefComposer.compose(
          const DaiBriefFacts(feeCollectionRate: '96%'));
      expect(good.single.text, contains('no defaulters'));
      expect(good.single.tone, DaiBriefTone.positive);

      final bad = DaiBriefComposer.compose(
          const DaiBriefFacts(feeDefaulters: 3, feeCollectionRate: '96%'));
      expect(bad.any((l) => l.text.contains('no defaulters')), isFalse,
          reason: 'never claim a clean sheet while defaulters exist');
    });

    test('attendance wording stays defensible', () {
      final healthy =
          DaiBriefComposer.compose(const DaiBriefFacts(attendancePercentToday: 94));
      expect(healthy.single.text, 'Attendance is 94% today.');
      expect(healthy.single.hasAction, isFalse,
          reason: 'a healthy number needs no call to action');

      final low =
          DaiBriefComposer.compose(const DaiBriefFacts(attendancePercentToday: 71));
      expect(low.single.text, contains('below the usual range'));
      expect(low.single.tone, DaiBriefTone.critical);
      expect(low.single.hasAction, isTrue);
    });

    test('is pure — same facts always compose the same brief', () {
      const facts = DaiBriefFacts(
        pendingApprovals: 2,
        feeDefaulters: 7,
        attendancePercentToday: 88,
        atRiskStudents: 1,
        staffAbsentToday: 3,
        expiringStaffDocuments: 2,
        admissionsJoinedMtd: 5,
      );
      final a = DaiBriefComposer.compose(facts);
      final b = DaiBriefComposer.compose(facts);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].text, b[i].text);
        expect(a[i].tone, b[i].tone);
        expect(a[i].actionRoute, b[i].actionRoute);
      }
    });

    test('every line with an action carries a real route', () {
      final lines = DaiBriefComposer.compose(const DaiBriefFacts(
        pendingApprovals: 1,
        feeDefaulters: 1,
        atRiskStudents: 1,
        attendancePercentToday: 60,
        staffAbsentToday: 1,
        expiringStaffDocuments: 1,
        unsubmittedMarksClasses: 1,
      ));
      for (final l in lines.where((l) => l.actionLabel != null)) {
        expect(l.actionRoute, isNotNull, reason: l.text);
        expect(l.actionRoute, startsWith('/'), reason: l.text);
      }
    });

    test('every action route is a REAL route, not a plausible-looking string',
        () {
      // Two of these were wrong on first write ('/exam-administration' and
      // '/academics/timetable/substitutions') and would have sent a principal
      // to a 404 from their morning brief. Pin them against the actual route
      // table so a typo can never ship again.
      final lines = DaiBriefComposer.compose(const DaiBriefFacts(
        pendingApprovals: 1,
        unsubmittedMarksClasses: 1,
        feeDefaulters: 1,
        atRiskStudents: 1,
        attendancePercentToday: 60,
        staffAbsentToday: 1,
        expiringStaffDocuments: 1,
      ));
      final known = {
        RouteNames.managementApprovals,
        RouteNames.examAdministration,
        RouteNames.financeDefaulters,
        RouteNames.sisStudents,
        RouteNames.managementAnalytics,
        RouteNames.substituteManager,
        RouteNames.hrEmployees,
      };
      // NOTE on what this test does and does NOT prove. It asserts every
      // actionRoute equals some RouteNames constant. It does NOT prove the
      // route is registered in the router, nor that the persona reading the
      // brief can actually reach it — and it passed while two routes sent a
      // principal to teacher-shell paths the router would bounce. The set below
      // is hand-maintained, so it is a spelling check, not a reachability
      // check. Before this composer is ever surfaced, replace this with an
      // assertion against the real route table plus the reading persona's
      // permissions.
      final used = lines
          .map((l) => l.actionRoute)
          .whereType<String>()
          .toSet();
      expect(used, isNotEmpty);
      expect(used.difference(known), isEmpty,
          reason: 'the brief points at a route that is not in RouteNames');
    });

    test('headline counts only what is genuinely critical', () {
      final lines = DaiBriefComposer.compose(const DaiBriefFacts(
        pendingApprovals: 9, // critical
        atRiskStudents: 2, // critical
        staffAbsentToday: 1, // neutral
      ));
      expect(DaiBriefComposer.headline(lines), '2 things need your attention');
    });
  });
}
