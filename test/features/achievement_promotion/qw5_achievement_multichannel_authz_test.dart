import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW5 · QA-J-067 — Cross-cutting · create achievement → approve → multi-channel
/// publish.
///
/// The publish fan-out is real and already asserted per-channel by
/// `promotion/publisher_test.ts`: in-app (parent/student/teacher/staff apps) +
/// school website create real broadcast/delivery/post rows. Two channels are
/// honestly limited (NOT faked): WhatsApp returns a share-deeplink (no Business
/// API send — Phase 1) and Facebook/Instagram return `pending_connection` until a
/// Meta account is linked (Phase 2). This test proves the create/approve/publish
/// authorization separation against the server-enforced gates: drafting is
/// `manageAchievementPromotion`; approving + publishing is the higher
/// `approveAchievementPromotion` (no create→publish self-escalation).
UserPermissions _role(ErpRole r) => UserPermissions.forRole(r);

void main() {
  group('QW5 · QA-J-067 achievement multi-channel publish authorization', () {
    test('School Admin holds the full create → approve → publish chain', () {
      final admin = _role(ErpRole.schoolAdmin);
      expect(admin.has(Permission.manageAchievementPromotion), isTrue);
      expect(admin.has(Permission.approveAchievementPromotion), isTrue);
    });

    test('a teacher may DRAFT an achievement but cannot APPROVE/PUBLISH it '
        '(no create→publish escalation)', () {
      final teacher = _role(ErpRole.teacher);
      expect(teacher.has(Permission.manageAchievementPromotion), isTrue);
      expect(teacher.has(Permission.approveAchievementPromotion), isFalse);
    });

    test('unrelated personas are DENIED the achievement verbs entirely', () {
      for (final role in [ErpRole.financeAdmin, ErpRole.parent, ErpRole.student]) {
        expect(_role(role).has(Permission.manageAchievementPromotion), isFalse,
            reason: '${role.name} cannot draft achievements');
        expect(_role(role).has(Permission.approveAchievementPromotion), isFalse,
            reason: '${role.name} cannot publish achievements');
      }
    });
  });
}
