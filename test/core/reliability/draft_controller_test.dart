import 'package:akshara_erp/core/reliability/drafts/draft_controller.dart';
import 'package:akshara_erp/core/reliability/drafts/draft_model.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _ExamMarksDraft implements DraftModel {
  _ExamMarksDraft(this.examId, this.marks);
  final String examId;
  final Map<String, int> marks;
  @override
  String get draftKey => 'exam_marks:$examId';
  @override
  String? get draftLabel => 'Exam $examId marks';
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'marks': marks};
}

void main() {
  test('saves, recovers and discards a draft (resume where you left off)',
      () async {
    final store = InMemoryReliabilityStore();
    final controller = DraftController(store, userId: 'teacher-1');

    // Teacher enters 35 of 50 marks; autosave fires.
    await controller.save(_ExamMarksDraft('E1', <String, int>{'s1': 8, 's35': 9}));
    expect(await controller.hasDraft('exam_marks:E1'), isTrue);

    // Returns later → the work is still there.
    final recovered = await controller.recover('exam_marks:E1');
    expect(recovered, isNotNull);
    expect(recovered!.json['marks'], <String, dynamic>{'s1': 8, 's35': 9});
    expect(recovered.label, 'Exam E1 marks');

    // On confirmed submit the draft is cleared.
    await controller.discard('exam_marks:E1');
    expect(await controller.hasDraft('exam_marks:E1'), isFalse);
  });

  test('drafts are scoped to the user', () async {
    final store = InMemoryReliabilityStore();
    final t1 = DraftController(store, userId: 'teacher-1');
    final t2 = DraftController(store, userId: 'teacher-2');
    await t1.save(_ExamMarksDraft('E1', const <String, int>{}));
    expect((await t1.myDrafts()).length, 1);
    expect((await t2.myDrafts()).length, 0);
  });
}
