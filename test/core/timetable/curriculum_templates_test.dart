import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/timetable/curriculum_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> subjectNames(SchoolCurriculum c, int grade) =>
      curriculumTemplateFor(c, grade).map((s) => s.subjectName).toList();

  group('grade bands', () {
    test('1-5 lower primary, 6-8 middle, 9-10 secondary', () {
      expect(gradeBandFor(1), GradeBand.lowerPrimary);
      expect(gradeBandFor(5), GradeBand.lowerPrimary);
      expect(gradeBandFor(6), GradeBand.middle);
      expect(gradeBandFor(8), GradeBand.middle);
      expect(gradeBandFor(9), GradeBand.secondary);
      expect(gradeBandFor(10), GradeBand.secondary);
    });
  });

  group('lower primary (1-5)', () {
    test('uses combined EVS and has NO Physics/Chemistry/Biology split', () {
      final names = subjectNames(SchoolCurriculum.cbse, 3);
      expect(names.any((n) => n.contains('EVS')), isTrue);
      expect(names, isNot(contains('Physics')));
      expect(names, isNot(contains('Chemistry')));
      expect(names, isNot(contains('Biology')));
      // No standalone "Science" or "Social Science" in lower primary either.
      expect(names, isNot(contains('Science')));
      expect(names, isNot(contains('Social Science')));
    });
  });

  group('middle (6-8)', () {
    test('has one combined Science plus Social Science, no PCB split', () {
      final names = subjectNames(SchoolCurriculum.cbse, 7);
      expect(names, contains('Science'));
      expect(names, contains('Social Science'));
      expect(names, isNot(contains('Physics')));
      expect(names, isNot(contains('Biology')));
    });

    test('CBSE adds Sanskrit as a third language in middle grades only', () {
      expect(subjectNames(SchoolCurriculum.cbse, 7), contains('Sanskrit'));
      expect(subjectNames(SchoolCurriculum.cbse, 3), isNot(contains('Sanskrit')));
      expect(subjectNames(SchoolCurriculum.cbse, 10), isNot(contains('Sanskrit')));
    });
  });

  group('secondary (9-10)', () {
    test('keeps Science and Social Science with a heavier load', () {
      final names = subjectNames(SchoolCurriculum.icse, 10);
      expect(names, contains('Science'));
      expect(names, contains('Mathematics'));
      expect(names, contains('Social Science'));
    });
  });

  group('board language differences', () {
    test('state board includes the regional language (Telugu)', () {
      expect(subjectNames(SchoolCurriculum.stateBoard, 6), contains('Telugu'));
    });

    test('CBSE includes Hindi and English', () {
      final names = subjectNames(SchoolCurriculum.cbse, 6);
      expect(names, contains('Hindi'));
      expect(names, contains('English'));
    });

    test('IB / Cambridge / Custom fall back to a generic language set', () {
      for (final c in [
        SchoolCurriculum.ib,
        SchoolCurriculum.cambridge,
        SchoolCurriculum.custom,
      ]) {
        final names = subjectNames(c, 6);
        expect(names, contains('English'));
        expect(names, contains('Second Language'));
      }
    });
  });

  group('activities', () {
    test('every band offers room-bound activities', () {
      for (final grade in [3, 7, 10]) {
        final specs = curriculumTemplateFor(SchoolCurriculum.cbse, grade);
        final activities = specs.where((s) => s.isActivity).toList();
        expect(activities, isNotEmpty);
        // PE -> Playground, Computer -> Computer Lab, Library -> Library.
        expect(
          activities.any((a) => a.requiresRoom == 'Computer Lab'),
          isTrue,
          reason: 'grade $grade should include a Computer Lab activity',
        );
        expect(
          activities.any((a) => a.requiresRoom == 'Playground'),
          isTrue,
        );
      }
    });
  });

  group('weekly load', () {
    test('every grade proposes a positive, sane weekly load', () {
      for (final grade in [1, 5, 6, 8, 9, 10]) {
        final load = curriculumWeeklyLoad(SchoolCurriculum.cbse, grade);
        expect(load, greaterThan(20));
        expect(load, lessThan(50));
      }
    });
  });
}
