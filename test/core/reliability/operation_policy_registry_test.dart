import 'package:akshara_erp/core/reliability/model/operation_policy.dart';
import 'package:akshara_erp/core/reliability/model/reliability_enums.dart';
import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unregistered type falls back to online-only + high-risk (safe default)',
      () {
    final r = OperationPolicyRegistry();
    final p = r.policyFor('unknown.op');
    expect(p.kind, OperationKind.onlineOnly);
    expect(p.conflictCategory, ConflictCategory.highRisk);
    expect(r.isRegistered('unknown.op'), isFalse);
  });

  test('withDefaults seeds pilot-critical operations correctly', () {
    final r = OperationPolicyRegistry.withDefaults();

    final attendance = r.policyFor(OperationTypes.markAttendance);
    expect(attendance.kind, OperationKind.queueable);
    expect(attendance.conflictCategory, ConflictCategory.lowRisk);

    final fee = r.policyFor(OperationTypes.collectFee);
    expect(fee.kind, OperationKind.queueable);
    expect(fee.conflictCategory, ConflictCategory.highRisk);
    expect(fee.requiresExplicitConflictResolution, isTrue);

    final login = r.policyFor(OperationTypes.login);
    expect(login.kind, OperationKind.onlineOnly);
  });

  test('register overrides an operation policy (one-line opt-in)', () {
    final r = OperationPolicyRegistry();
    r.register(
      'library.issueBook',
      const OperationPolicy(
        kind: OperationKind.queueable,
        conflictCategory: ConflictCategory.lowRisk,
      ),
    );
    expect(r.policyFor('library.issueBook').isQueueable, isTrue);
    expect(r.registeredTypes, contains('library.issueBook'));
  });
}
