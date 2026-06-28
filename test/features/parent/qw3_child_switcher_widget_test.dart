import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/parent/parent_active_child_provider.dart';
import 'package:akshara_erp/features/parent/widgets/parent_child_switcher_sheet.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW3 · QA-F-016 — parent child switcher sheet open + select. The
/// multi-child switcher was never pumped; this proves the sheet opens with two
/// children and that tapping a sibling updates the active child the parent
/// modules read from (`parentActiveChildProvider`).

const _ravi = LinkedChild(id: 'child-ravi', name: 'Ravi Kumar', classLabel: '8-A');
const _priya =
    LinkedChild(id: 'child-priya', name: 'Priya Kumar', classLabel: '5-B');

/// Auth notifier pinned to a 2-child parent session whose [selectChild] updates
/// the active child in memory (no SharedPreferences dependency in widget tests).
class _SwitcherAuthNotifier extends AuthNotifier {
  _SwitcherAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> selectChild(LinkedChild child) async {
    if (state.linkedChildren.any((c) => c.id == child.id)) {
      state = state.copyWith(selectedChild: child);
    }
  }
}

AuthState get _parentAuth => AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: '9000100001',
      displayName: 'Parent User',
      role: UserRole.parent,
      selectedChild: _ravi,
      linkedChildren: const [_ravi, _priya],
      claims: AuthClaims.demoForRole(erpRole: ErpRole.parent),
    );

void main() {
  testWidgets('QA-F-016 · opens the switcher and selects a sibling',
      (tester) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _SwitcherAuthNotifier(_parentAuth)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showParentChildSwitcherSheet(context, ref),
                  child: const Text('switch'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Active child starts on Ravi.
    expect(container.read(parentActiveChildProvider)?.id, _ravi.id);

    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();

    // Sheet open with both children listed.
    expect(find.text('Switch child'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Priya Kumar'), findsOneWidget);

    // Select the sibling → sheet closes, active child updates.
    await tester.tap(find.byKey(QaTestKeys.parentChildSwitcherOption(_priya.id)));
    await tester.pumpAndSettle();

    expect(find.text('Switch child'), findsNothing);
    expect(container.read(parentActiveChildProvider)?.id, _priya.id);
  });
}
