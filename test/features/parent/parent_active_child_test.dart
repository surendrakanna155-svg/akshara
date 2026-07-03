import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/parent/parent_active_child_provider.dart';

void main() {
  group('parent active child', () {
    test('active student id is the real auth-backed child id (not a SIS map)',
        () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _StubAuthNotifier(
              const AuthState(
                status: AuthStatus.authenticated,
                role: UserRole.parent,
                selectedChild:
                    LinkedChild(id: 'child-ravi', name: 'Ravi', classLabel: '8-A'),
                linkedChildren: [
                  LinkedChild(id: 'child-ravi', name: 'Ravi', classLabel: '8-A'),
                  LinkedChild(id: 'child-priya', name: 'Priya', classLabel: '5-B'),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // The resolved student id is the child_ids-backed id itself — never a
      // hardcoded demo / SIS student id.
      expect(container.read(parentActiveStudentIdProvider), 'child-ravi');
    });

    test('active student id is empty when no child is resolved', () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _StubAuthNotifier(
              const AuthState(
                status: AuthStatus.authenticated,
                role: UserRole.parent,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(parentActiveStudentIdProvider), '');
    });

    test('linked children keep distinct ids for sibling navigation', () {
      const children = [
        LinkedChild(id: 'child-ravi', name: 'Ravi Kumar', classLabel: '8-A'),
        LinkedChild(id: 'child-priya', name: 'Priya Kumar', classLabel: '5-B'),
      ];
      expect(children.length, 2);
      expect(children[0].id, isNot(equals(children[1].id)));
    });
  });
}

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}
