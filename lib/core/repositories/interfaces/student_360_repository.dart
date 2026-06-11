import '../../../features/student_360/student_360_models.dart';
import '../repository_query.dart';

abstract class Student360Repository {
  Future<Student360Profile> getProfile({
    required RepositoryQuery query,
    required String studentId,
  });

  Future<List<StudentTimelineEvent>> getTimeline({
    required RepositoryQuery query,
    required String studentId,
  });
}
