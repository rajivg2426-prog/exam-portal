import 'dart:io';
import 'dart:math';

import 'package:exam_portal/data/question_bank.dart';
import 'package:exam_portal/models/exam_session.dart';
import 'package:exam_portal/models/question.dart';
import 'package:exam_portal/services/exam_store.dart';
import 'package:exam_portal/services/paper_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bank = QuestionBank.fromJsonStrings(QuestionBank.assetPaths.map((p) => File(p).readAsStringSync()));
  const config = PaperConfig.boardPattern(board: 'CBSE', grade: 10, subject: 'Mathematics', pastPapersOnly: true);

  Paper generate(int seed, {Set<String> seen = const {}}) =>
      PaperGenerator(bank.questions, random: Random(seed), seenIds: seen).generate(config);

  test('a board-pattern paper follows sections A to E and totals 80 marks', () {
    final paper = generate(1);
    List<PaperQuestion> section(String s) => paper.questions.where((q) => q.section == s).toList();

    expect(section('A'), hasLength(20));
    expect(section('A').every((q) => q.question.type == QuestionType.mcq && q.question.marks == 1), isTrue);
    expect(section('B').map((q) => q.question.marks), List.filled(5, 2));
    expect(section('C').map((q) => q.question.marks), List.filled(6, 3));
    expect(section('D').map((q) => q.question.marks), List.filled(4, 5));
    expect(section('E').fold(0, (n, q) => n + q.question.marks), 12);
    expect(section('E').map((q) => q.question.caseStudy).toSet(), hasLength(3));
    expect(paper.totalMarks, 80);
    expect(paper.isShort, isFalse);
    expect(paper.questions.every((q) => q.question.isPastPaper), isTrue);
    expect(paper.questions.map((q) => q.section).toList(), [...paper.questions.map((q) => q.section)]..sort());
  });

  test('a paper never holds both sides of an OR choice, and case studies stay whole', () {
    for (var seed = 0; seed < 20; seed++) {
      final paper = generate(seed);
      final outside = paper.questions.where((q) => q.section != 'E').map((q) => q.question.originKey).toList();
      expect(outside.toSet(), hasLength(outside.length), reason: 'seed $seed');
      for (final group in paper.questions.where((q) => q.section == 'E').map((q) => q.question.caseStudy).toSet()) {
        final parts = paper.questions.where((q) => q.question.caseStudy == group);
        expect(parts.fold(0, (n, q) => n + q.question.marks), 4, reason: 'seed $seed $group');
      }
    }
  });

  test('every paper is different', () {
    final ids = {for (var seed = 0; seed < 10; seed++) generate(seed).questions.map((q) => q.question.id).join(',')};
    expect(ids, hasLength(10));
  });

  test("a student's next paper uses questions they have not seen yet", () {
    final first = generate(1);
    final seen = first.questions.map((q) => q.question.id).toSet();
    final second = generate(2, seen: seen);
    expect(second.questions.where((q) => seen.contains(q.question.id)), isEmpty);
    expect(second.totalMarks, 80);
  });

  test('sections are kept when an exam in progress is saved', () async {
    final store = MemoryExamStore();
    await store.save(ExamSession.start(generate(3)));
    final restored = (await store.load(bank.questions))!;
    expect(restored.paper.config.isBoardPattern, isTrue);
    expect(restored.paper.questions.first.section, 'A');
    expect(restored.paper.questions.last.section, 'E');
  });

  test('a Science board-pattern paper follows its own layout and totals 80 marks', () {
    for (var seed = 0; seed < 10; seed++) {
      final paper = PaperGenerator(bank.questions, random: Random(seed)).generate(
        const PaperConfig.boardPattern(board: 'CBSE', grade: 10, subject: 'Science', pastPapersOnly: true),
      );
      int count(String s) => paper.questions.where((q) => q.section == s).length;
      expect([count('A'), count('B'), count('C'), count('D')], [20, 6, 7, 3], reason: 'seed $seed');
      expect(paper.questions.where((q) => q.section == 'E').fold(0, (n, q) => n + q.question.marks), 12);
      expect(paper.totalMarks, 80, reason: 'seed $seed');
      expect(paper.questions.every((q) => q.question.subject == 'Science'), isTrue);
    }
  });

  test('English and Hindi A board-pattern papers total 80 marks', () {
    for (final subject in ['English', 'Hindi A']) {
      for (var seed = 0; seed < 5; seed++) {
        final paper = PaperGenerator(bank.questions, random: Random(seed)).generate(
          PaperConfig.boardPattern(board: 'CBSE', grade: 10, subject: subject, pastPapersOnly: true),
        );
        expect(paper.totalMarks, 80, reason: '$subject seed $seed');
        expect(paper.questions.every((q) => q.question.subject == subject), isTrue);
      }
    }
  });

  test('a Class XII Mathematics board-pattern paper uses only Class XII questions and totals 80 marks', () {
    for (var seed = 0; seed < 10; seed++) {
      final paper = PaperGenerator(bank.questions, random: Random(seed)).generate(
        const PaperConfig.boardPattern(board: 'CBSE', grade: 12, subject: 'Mathematics', pastPapersOnly: true),
      );
      expect(paper.totalMarks, 80, reason: 'seed $seed');
      expect(paper.questions.every((q) => q.question.grade == 12), isTrue);
      for (final group in paper.questions.where((q) => q.section == 'E').map((q) => q.question.caseStudy).toSet()) {
        final parts = paper.questions.where((q) => q.question.caseStudy == group);
        expect(parts.fold(0, (n, q) => n + q.question.marks), 4, reason: 'seed $seed $group');
      }
    }
  });

  test('a Class XII Physics board-pattern paper totals 70 marks with two whole case studies', () {
    for (var seed = 0; seed < 10; seed++) {
      final paper = PaperGenerator(bank.questions, random: Random(seed)).generate(
        const PaperConfig.boardPattern(board: 'CBSE', grade: 12, subject: 'Physics', pastPapersOnly: true),
      );
      expect(paper.totalMarks, 70, reason: 'seed $seed');
      final cases = paper.questions.where((q) => q.section == 'D').toList();
      expect(cases.map((q) => q.question.caseStudy).toSet(), hasLength(2), reason: 'seed $seed');
      expect(cases.fold(0, (n, q) => n + q.question.marks), 8, reason: 'seed $seed');
    }
  });
}
