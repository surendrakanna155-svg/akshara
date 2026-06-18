import 'package:akshara_erp/core/exams/exam_administration_persistence.dart';
import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resets exam store with isolated mock persistence for widget/provider tests.
Future<SharedPreferences> resetExamAdministrationForTest() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = ExamAdministrationStore.instance;
  store.attachPersistence(ExamAdministrationPersistence(prefs));
  store.reset();
  store.ensureSeeded();
  return prefs;
}

Override sharedPreferencesTestOverride(SharedPreferences prefs) =>
    sharedPreferencesProvider.overrideWithValue(prefs);
