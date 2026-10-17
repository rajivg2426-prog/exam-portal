import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';

/// Read-only view over the tagged question bank.
///
/// For now the bank is a bundled JSON file of sample questions. Later phases
/// replace this with content edited through the admin panel.
class QuestionBank {
  QuestionBank(List<Question> questions) : questions = List.unmodifiable(questions);

  static const assetPath = 'assets/question_bank/sample_questions.json';

  final List<Question> questions;

  static Future<QuestionBank> loadFromAssets() async {
    final raw = await rootBundle.loadString(assetPath);
    return QuestionBank.fromJsonString(raw);
  }

  factory QuestionBank.fromJsonString(String raw) {
    final list = (jsonDecode(raw) as Map<String, dynamic>)['questions'] as List;
    return QuestionBank(
      list.map((e) => Question.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  List<String> get boards => _sorted(questions.map((q) => q.board));

  List<int> gradesFor(String board) =>
      questions.where((q) => q.board == board).map((q) => q.grade).toSet().toList()..sort();

  List<String> subjectsFor(String board, int grade) => _sorted(
        questions.where((q) => q.board == board && q.grade == grade).map((q) => q.subject),
      );

  /// Chapters in the order they first appear in the bank (syllabus order).
  List<String> chaptersFor(String board, int grade, String subject) => questions
      .where((q) => q.board == board && q.grade == grade && q.subject == subject)
      .map((q) => q.chapter)
      .toSet()
      .toList();

  static List<String> _sorted(Iterable<String> values) => values.toSet().toList()..sort();
}
