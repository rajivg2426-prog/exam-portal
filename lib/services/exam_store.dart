import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam_result.dart';
import '../models/exam_session.dart';
import '../models/question.dart';

/// Keeps the student's exam data on the device: the one exam in progress
/// (so it survives a refresh or the app closing) and every submitted result.
abstract class ExamStore {
  static const inProgressKey = 'exam_in_progress_v1';
  static const resultsKey = 'exam_results_v1';

  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);

  Future<void> save(ExamSession session) => write(inProgressKey, jsonEncode(session.toJson()));

  Future<ExamSession?> load(List<Question> bank) async {
    final raw = await read(inProgressKey);
    if (raw == null) return null;
    try {
      return ExamSession.fromJson(jsonDecode(raw) as Map<String, dynamic>, bank);
    } on Object {
      await remove(inProgressKey); // unreadable save from an older version
      return null;
    }
  }

  Future<void> clear() => remove(inProgressKey);

  /// Adds or replaces a result (matched by id).
  Future<void> saveResult(ExamResult result) async {
    final all = await _rawResults();
    all.removeWhere((r) => r['id'] == result.id);
    all.add(result.toJson());
    await write(resultsKey, jsonEncode(all));
  }

  /// All results, newest first. Results whose questions have left the bank
  /// are skipped.
  Future<List<ExamResult>> loadResults(List<Question> bank) async {
    final results = <ExamResult>[];
    for (final json in await _rawResults()) {
      try {
        final r = ExamResult.fromJson(json, bank);
        if (r != null) results.add(r);
      } on Object {
        // Skip a result saved in an unreadable format.
      }
    }
    results.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return results;
  }

  Future<List<Map<String, dynamic>>> _rawResults() async {
    final raw = await read(resultsKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } on Object {
      return [];
    }
  }
}

class LocalExamStore extends ExamStore {
  @override
  Future<String?> read(String key) async => (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);

  @override
  Future<void> remove(String key) async => (await SharedPreferences.getInstance()).remove(key);
}

class MemoryExamStore extends ExamStore {
  final Map<String, String> values = {};

  /// The exam in progress as saved JSON, for tests.
  String? get saved => values[ExamStore.inProgressKey];

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}
