import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam_session.dart';
import '../models/question.dart';

/// Saves the exam in progress on the device so it survives a refresh or the
/// app being closed. Only one unfinished exam is kept at a time.
abstract class ExamStore {
  Future<void> save(ExamSession session);
  Future<ExamSession?> load(List<Question> bank);
  Future<void> clear();
}

class LocalExamStore implements ExamStore {
  static const _key = 'exam_in_progress_v1';

  @override
  Future<void> save(ExamSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session.toJson()));
  }

  @override
  Future<ExamSession?> load(List<Question> bank) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return ExamSession.fromJson(jsonDecode(raw) as Map<String, dynamic>, bank);
    } on Object {
      await prefs.remove(_key); // unreadable save from an older version
      return null;
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class MemoryExamStore implements ExamStore {
  String? saved;

  @override
  Future<void> save(ExamSession session) async => saved = jsonEncode(session.toJson());

  @override
  Future<ExamSession?> load(List<Question> bank) async =>
      saved == null ? null : ExamSession.fromJson(jsonDecode(saved!) as Map<String, dynamic>, bank);

  @override
  Future<void> clear() async => saved = null;
}
