import 'package:akshara_erp/core/security/permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionSet', () {
    test('contains single permission', () {
      const set = PermissionSet({Permission.viewFinance});
      expect(set.contains(Permission.viewFinance), isTrue);
      expect(set.contains(Permission.manageFinance), isFalse);
    });

    test('containsAny and containsAll', () {
      const set = PermissionSet({
        Permission.viewAdmissions,
        Permission.manageAdmissions,
      });
      expect(
        set.containsAny([Permission.viewFinance, Permission.viewAdmissions]),
        isTrue,
      );
      expect(
        set.containsAll([
          Permission.viewAdmissions,
          Permission.manageAdmissions,
        ]),
        isTrue,
      );
      expect(
        set.containsAll([
          Permission.viewAdmissions,
          Permission.viewFinance,
        ]),
        isFalse,
      );
    });

    test('equality compares permission contents', () {
      const a = PermissionSet({Permission.viewHr, Permission.manageHr});
      const b = PermissionSet({Permission.manageHr, Permission.viewHr});
      expect(a, equals(b));
    });
  });
}
