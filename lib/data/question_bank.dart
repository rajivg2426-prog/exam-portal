import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';

/// Read-only view over the tagged question bank.
///
/// For now the bank is a set of bundled JSON files: sample questions written
/// for this app, plus questions from real CBSE board papers. Later the
/// content will be edited through the admin panel.
class QuestionBank {
  QuestionBank(List<Question> questions) : questions = List.unmodifiable(questions);

  static const assetPaths = [
    'assets/question_bank/sample_questions.json',
    'assets/question_bank/cbse_2024_30-1-1.json',
    'assets/question_bank/cbse_2025_30-1-1.json',
    'assets/question_bank/cbse_2026_30-1-1.json',
  ];

  /// NCERT chapter order, so chapters are listed as in the textbook.
  static const _syllabusOrder = {
    'Mathematics': [
      'Real Numbers',
      'Polynomials',
      'Pair of Linear Equations in Two Variables',
      'Quadratic Equations',
      'Arithmetic Progressions',
      'Triangles',
      'Coordinate Geometry',
      'Introduction to Trigonometry',
      'Some Applications of Trigonometry',
      'Circles',
      'Areas Related to Circles',
      'Surface Areas and Volumes',
      'Statistics',
      'Probability',
    ],
  };

  final List<Question> questions;

  static Future<QuestionBank> loadFromAssets() async {
    final raws = await Future.wait(assetPaths.map(rootBundle.loadString));
    return QuestionBank.fromJsonStrings(raws);
  }

  factory QuestionBank.fromJsonString(String raw) => QuestionBank.fromJsonStrings([raw]);

  factory QuestionBank.fromJsonStrings(Iterable<String> raws) {
    final questions = <Question>[];
    for (final raw in raws) {
      final list = (jsonDecode(raw) as Map<String, dynamic>)['questions'] as List;
      questions.addAll(list.map((e) => Question.fromJson(e as Map<String, dynamic>)));
    }
    final ids = <String>{};
    for (final q in questions) {
      if (!ids.add(q.id)) throw FormatException('Duplicate question id ${q.id}');
    }
    return QuestionBank(questions);
  }

  List<String> get boards => _sorted(questions.map((q) => q.board));

  List<int> gradesFor(String board) =>
      questions.where((q) => q.board == board).map((q) => q.grade).toSet().toList()..sort();

  List<String> subjectsFor(String board, int grade) => _sorted(
        questions.where((q) => q.board == board && q.grade == grade).map((q) => q.subject),
      );

  /// Chapters in syllabus order; any not in the known order come last.
  List<String> chaptersFor(String board, int grade, String subject) {
    final order = _syllabusOrder[subject] ?? const [];
    int rank(String c) {
      final i = order.indexOf(c);
      return i < 0 ? order.length : i;
    }

    return questions
        .where((q) => q.board == board && q.grade == grade && q.subject == subject)
        .map((q) => q.chapter)
        .toSet()
        .toList()
      ..sort((a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : a.compareTo(b));
  }

  /// Whether any past-paper questions exist for this class and subject.
  bool hasPastPapers(String board, int grade, String subject) => questions
      .any((q) => q.isPastPaper && q.board == board && q.grade == grade && q.subject == subject);

  static List<String> _sorted(Iterable<String> values) => values.toSet().toList()..sort();
}
