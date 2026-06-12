import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/config/staging_probe_ids.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/parent/parent_active_child_provider.dart';

void main() {
  group('parent active child', () {
    test('maps auth child ids to student ids', () {
      expect(parentStudentIdForChild('child-ravi'), StagingProbeIds.studentAId);
      expect(parentStudentIdForChild('child-priya'), StagingProbeIds.studentBId);
      expect(parentStudentIdForChild('unknown'), 'unknown');
    });

    test('linked children support sibling navigation ids', () {
      const children = [
        LinkedChild(id: 'child-ravi', name: 'Ravi Kumar', classLabel: '8-A'),
        LinkedChild(id: 'child-priya', name: 'Priya Kumar', classLabel: '5-B'),
      ];
      expect(children.length, 2);
      expect(parentStudentIdForChild(children[0].id), isNot(equals(children[1].id)));
    });
  });
}
