import 'dart:io';
import 'dart:math';

import 'package:exam_portal/data/question_bank.dart';
import 'package:exam_portal/models/question.dart';
import 'package:exam_portal/services/paper_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bank = QuestionBank.fromJsonString(
    File('assets/question_bank/sample_questions.json').readAsStringSync(),
  );

  PaperConfig config({
    Set<String>? chapters,
    QuestionType type = QuestionType.mcq,
    Difficulty difficulty = Difficulty.normal,
    ExamDuration duration = ExamDuration.min30,
  }) =>
      PaperConfig(
        board: 'CBSE',
        grade: 10,
        subject: 'Mathematics',
        chapters: chapters,
        type: type,
        difficulty: difficulty,
        duration: duration,
      );

  test('sample bank loads with unique ids and every question tagged as sample', () {
    expect(bank.questions, hasLength(36));
    expect(bank.questions.map((q) => q.id).toSet(), hasLength(36));
    expect(bank.questions.every((q) => q.isSample && q.year == null), isTrue);
    expect(bank.chaptersFor('CBSE', 10, 'Mathematics'),
        ['Real Numbers', 'Polynomials', 'Quadratic Equations']);
  });

  test('only questions matching every chosen tag are used', () {
    final paper = PaperGenerator(bank.questions, random: Random(1))
        .generate(config(chapters: {'Polynomials'}));
    expect(paper.questions, isNotEmpty);
    for (final item in paper.questions) {
      expect(item.question.chapter, 'Polynomials');
      expect(item.question.type, QuestionType.mcq);
      expect(item.question.difficulty, Difficulty.normal);
    }
  });

  test('no question appears twice and marks stay within the target', () {
    for (final duration in ExamDuration.values) {
      final paper = PaperGenerator(bank.questions, random: Random(2))
          .generate(config(type: QuestionType.subjective, difficulty: Difficulty.tough, duration: duration));
      final ids = paper.questions.map((q) => q.question.id);
      expect(ids.toSet(), hasLength(ids.length));
      expect(paper.totalMarks, lessThanOrEqualTo(duration.targetMarks));
    }
  });

  test('tough papers use tough questions first, then top up with normal ones', () {
    final paper = PaperGenerator(bank.questions, random: Random(3))
        .generate(config(difficulty: Difficulty.tough));
    // 9 tough MCQs exist, fewer than the 12 marks a 30 min paper aims for.
    expect(paper.questions.where((q) => q.question.difficulty == Difficulty.tough), hasLength(9));
    expect(paper.totalMarks, 12);
    expect(paper.isShort, isFalse);
  });

  test('a paper is flagged short when the bank runs out', () {
    final paper = PaperGenerator(bank.questions, random: Random(4))
        .generate(config(duration: ExamDuration.hour3));
    expect(paper.totalMarks, 15); // all normal MCQs
    expect(paper.isShort, isTrue);
  });

  test('shuffled MCQ options keep the correct answer', () {
    final paper = PaperGenerator(bank.questions, random: Random(5)).generate(config());
    for (final item in paper.questions) {
      final q = item.question;
      expect(item.options.toSet(), q.options.toSet());
      expect(item.options[item.answerIndex!], q.options[q.answerIndex!]);
    }
  });

  test('questions are ordered by marks', () {
    final paper = PaperGenerator(bank.questions, random: Random(6))
        .generate(config(type: QuestionType.subjective, difficulty: Difficulty.tough, duration: ExamDuration.hour1));
    final marks = paper.questions.map((q) => q.question.marks).toList();
    expect(marks, [...marks]..sort());
  });
}
