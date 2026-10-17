import 'dart:io';
import 'dart:math';

import 'package:exam_portal/data/question_bank.dart';
import 'package:exam_portal/main.dart';
import 'package:exam_portal/models/exam_result.dart';
import 'package:exam_portal/models/exam_session.dart';
import 'package:exam_portal/models/question.dart';
import 'package:exam_portal/services/exam_store.dart';
import 'package:exam_portal/services/paper_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bank = QuestionBank.fromJsonString(File('assets/question_bank/sample_questions.json').readAsStringSync());

  Paper paper(QuestionType type, {int seed = 1}) =>
      PaperGenerator(bank.questions, random: Random(seed)).generate(PaperConfig(
        board: 'CBSE',
        grade: 10,
        subject: 'Mathematics',
        type: type,
        difficulty: Difficulty.normal,
        duration: ExamDuration.min30,
      ));

  ExamResult submit(ExamSession s, {int minutes = 10}) =>
      ExamResult.fromSession(s, submittedAt: s.startedAt.add(Duration(minutes: minutes)), timeUp: false);

  group('ExamResult', () {
    test('marks MCQs: correct, wrong and skipped', () {
      final s = ExamSession.start(paper(QuestionType.mcq), now: DateTime(2026, 1, 1));
      final q = s.paper.questions;
      s.choices[0] = q[0].answerIndex!; // correct
      s.choices[1] = (q[1].answerIndex! + 1) % q[1].options.length; // wrong
      s.choices[2] = q[2].answerIndex!; // correct
      final r = submit(s);

      expect(r.status(0), AnswerStatus.correct);
      expect(r.status(1), AnswerStatus.wrong);
      expect(r.status(3), AnswerStatus.skipped);
      expect(r.score, 2);
      expect(r.totalMarks, 12);
      expect(r.percent, 17);
      expect(r.count(AnswerStatus.skipped), 9);
      expect(r.timeTaken, const Duration(minutes: 10));
      final byChapter = r.byChapter.values;
      expect(byChapter.fold(0, (a, c) => a + c.total), 12);
      expect(byChapter.fold(0, (a, c) => a + c.scored), 2);
    });

    test('subjective answers count once the student marks them', () {
      final s = ExamSession.start(paper(QuestionType.subjective), now: DateTime(2026, 1, 1));
      s.written[0] = 'my working';
      s.written[1] = '   '; // blank counts as skipped
      final r = submit(s);
      expect(r.status(0), AnswerStatus.toMark);
      expect(r.status(1), AnswerStatus.skipped);
      expect(r.score, 0);

      r.awarded[0] = 2;
      expect(r.status(0), AnswerStatus.marked);
      expect(r.score, 2);
    });

    test('time taken never exceeds the paper length', () {
      final s = ExamSession.start(paper(QuestionType.mcq), now: DateTime(2026, 1, 1));
      expect(submit(s, minutes: 45).timeTaken, const Duration(minutes: 30));
    });

    test('results are saved, updated and loaded newest first', () async {
      final store = MemoryExamStore();
      final older = submit(ExamSession.start(paper(QuestionType.mcq), now: DateTime(2026, 1, 1)));
      final newer = submit(ExamSession.start(paper(QuestionType.subjective), now: DateTime(2026, 1, 2))..written[0] = 'x');
      await store.saveResult(older);
      await store.saveResult(newer);
      newer.awarded[0] = 1;
      await store.saveResult(newer);

      final loaded = await store.loadResults(bank.questions);
      expect(loaded.map((r) => r.id), [newer.id, older.id]);
      expect(loaded.first.awarded, {0: 1});
    });

    test('summary averages scores and lists weakest chapters first', () {
      final a = ExamSession.start(paper(QuestionType.mcq), now: DateTime(2026, 1, 1));
      for (var i = 0; i < a.length; i++) {
        a.choices[i] = a.paper.questions[i].answerIndex!;
      }
      final b = ExamSession.start(paper(QuestionType.mcq, seed: 2), now: DateTime(2026, 1, 2));
      final summary = ResultsSummary([submit(b), submit(a)]);
      expect(summary.attempts, 2);
      expect(summary.bestPercent, 100);
      expect(summary.averagePercent, 50);
      final ratios = summary.chapters.map((c) => c.scored / c.total).toList();
      expect(ratios, [...ratios]..sort());
    });
  });

  testWidgets('results page shows the score and lets the student mark a written answer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = MemoryExamStore();
    final s = ExamSession.start(paper(QuestionType.subjective), now: DateTime(2026, 1, 1))..written[0] = 'my working';
    await store.saveResult(submit(s));

    await tester.pumpWidget(ExamPortalApp(bankLoader: () async => bank, store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('My results'));
    await tester.pumpAndSettle();
    expect(find.text('My results'), findsOneWidget);
    expect(find.textContaining('needs marking'), findsOneWidget);

    await tester.tap(find.textContaining('Subjective').first);
    await tester.pumpAndSettle();
    expect(find.text('Results'), findsOneWidget);
    expect(find.textContaining('1 answer needs marking'), findsOneWidget);

    await tester.scrollUntilVisible(find.textContaining('Q1 ·'), 200);
    await tester.tap(find.textContaining('Q1 ·'));
    await tester.pumpAndSettle();
    expect(find.text('my working'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Choose'), 200);
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    final marks = s.paper.questions[0].question.marks;
    await tester.tap(find.text('$marks / $marks').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('needs marking'), findsNothing);
    final saved = await store.loadResults(bank.questions);
    expect(saved.single.awarded, {0: marks});
  });
}
