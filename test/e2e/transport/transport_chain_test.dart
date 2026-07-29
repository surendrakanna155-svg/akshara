import 'package:flutter_test/flutter_test.dart';

import 'transport_chain_harness.dart';

/// BUS-014 — runs every registered chain scenario and emits the coverage report.
///
/// This suite is the executable form of the roadmap's completion rule: a task is
/// complete only when it is proven across Transport Admin → Driver → Backend →
/// Parent → Student. Unbuilt hops are reported with their blocking task rather
/// than passing silently, so "how far is Bus Tracking really?" has one honest
/// answer that cannot drift from the code.
void main() {
  for (final scenario in transportChainScenarios) {
    runChainScenario(scenario);
  }
  reportChainCoverage(transportChainScenarios);

  group('BUS-014 · harness self-checks', () {
    test('every scenario declares all five hops', () {
      for (final s in transportChainScenarios) {
        for (final hop in ChainHop.values) {
          expect(s.hops[hop], isNotNull,
              reason: '${s.taskId} is missing its ${hop.label} hop');
        }
      }
    });

    test('no hop claims verified without an assertion', () {
      for (final s in transportChainScenarios) {
        s.hops.forEach((hopKey, hop) {
          if (hop.status == HopStatus.verified) {
            expect(hop.assertion, isNotNull,
                reason: '${s.taskId} ${hopKey.label} claims verified but '
                    'asserts nothing — exactly how the capacity guard '
                    'shipped dead');
          }
        });
      }
    });

    test('no hop is skipped without a stated reason or blocking task', () {
      for (final s in transportChainScenarios) {
        s.hops.forEach((hopKey, hop) {
          switch (hop.status) {
            case HopStatus.notApplicable:
              expect(hop.reason, isNotNull);
              expect(hop.reason, isNotEmpty);
            case HopStatus.notBuilt:
              expect(hop.blockedBy, isNotNull);
              expect(hop.blockedBy, startsWith('BUS-'));
            case HopStatus.verified:
              break;
          }
        });
      }
    });
  });
}
