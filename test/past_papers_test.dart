import 'dart:io';
import 'dart:math';

import 'package:exam_portal/data/question_bank.dart';
import 'package:exam_portal/models/question.dart';
import 'package:exam_portal/services/paper_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bank = QuestionBank.fromJsonStrings(QuestionBank.assetPaths.map((p) => File(p).readAsStringSync()));
  final past = bank.questions.where((q) => q.isPastPaper).toList();

  test('every bundled question bank file loads with unique ids', () {
    expect(bank.questions.length, greaterThan(36));
    expect(past, isNotEmpty);
  });

  test('past-paper questions carry board, year, paper code and question number', () {
    for (final q in past) {
      expect(q.year, isNotNull, reason: q.id);
      expect(q.paper, isNotNull, reason: q.id);
      expect(q.number, isNotNull, reason: q.id);
      expect(q.sourceLabel, startsWith('CBSE ${q.year} board exam · Q.P. '));
      expect(q.solution.trim(), isNotEmpty, reason: q.id);
    }
  });

  test('chapters are listed in NCERT order', () {
    final chapters = bank.chaptersFor('CBSE', 10, 'Mathematics');
    expect(chapters.first, 'Real Numbers');
    expect(chapters.indexOf('Polynomials'), lessThan(chapters.indexOf('Quadratic Equations')));
    expect(chapters.indexOf('Statistics'), lessThan(chapters.indexOf('Probability')));
  });

  test('past papers only uses no sample questions', () {
    for (final type in QuestionType.values) {
      final paper = PaperGenerator(bank.questions, random: Random(3)).generate(PaperConfig(
        board: 'CBSE',
        grade: 10,
        subject: 'Mathematics',
        type: type,
        difficulty: Difficulty.normal,
        duration: ExamDuration.hour1,
        pastPapersOnly: true,
      ));
      expect(paper.questions, isNotEmpty);
      expect(paper.questions.every((q) => q.question.isPastPaper), isTrue);
      expect(paper.hasSampleQuestions, isFalse);
    }
  });

  test('the option is saved with an exam in progress', () {
    const config = PaperConfig(
      board: 'CBSE',
      grade: 10,
      subject: 'Mathematics',
      type: QuestionType.mcq,
      difficulty: Difficulty.normal,
      duration: ExamDuration.min30,
      pastPapersOnly: true,
    );
    expect(PaperConfig.fromJson(config.toJson()).pastPapersOnly, isTrue);
  });
}
