import 'package:akshara_erp/core/communication/school_broadcast_store.dart';
import 'package:akshara_erp/core/repositories/interfaces/communication_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_communication_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;

  setUp(() => SchoolBroadcastStore.instance.reset());

  Future<void> send(String audience, String title) async {
    await MockCommunicationRepository().sendBroadcast(
      query: query,
      request: BroadcastRequest(
        audience: audience,
        title: title,
        body: 'Details for $title.',
      ),
    );
  }

  test('a broadcast to parents shows in parent notices, not student notices',
      () async {
    await send('all_parents', 'PTM on Saturday');

    final parent = await MockParentRepository().getNotices(query: query);
    final student = await MockStudentRepository().getNotices(query: query);

    expect(parent.any((n) => n.title == 'PTM on Saturday'), isTrue);
    expect(student.any((n) => n.title == 'PTM on Saturday'), isFalse);
  });

  test('a broadcast to all reaches both parents and students', () async {
    await send('all', 'Holiday on Friday');

    final parent = await MockParentRepository().getNotices(query: query);
    final student = await MockStudentRepository().getNotices(query: query);

    expect(parent.any((n) => n.title == 'Holiday on Friday'), isTrue);
    expect(student.any((n) => n.title == 'Holiday on Friday'), isTrue);
  });

  test('newest broadcast appears at the top of parent notices', () async {
    await send('all_parents', 'First notice');
    await send('all_parents', 'Second notice');

    final parent = await MockParentRepository().getNotices(query: query);
    expect(parent.first.title, 'Second notice');
  });
}
