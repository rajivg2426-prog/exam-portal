import 'dart:io';
import 'dart:math';

import 'package:exam_portal/data/question_bank.dart';
import 'package:exam_portal/main.dart';
import 'package:exam_portal/models/exam_session.dart';
import 'package:exam_portal/models/question.dart';
import 'package:exam_portal/screens/exam_screen.dart';
import 'package:exam_portal/services/exam_store.dart';
import 'package:exam_portal/services/paper_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File('assets/question_bank/sample_questions.json').readAsStringSync();
  final bank = QuestionBank.fromJsonString(raw);

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Paper mcqPaper() => PaperGenerator(bank.questions, random: Random(7)).generate(const PaperConfig(
        board: 'CBSE',
        grade: 10,
        subject: 'Mathematics',
        type: QuestionType.mcq,
        difficulty: Difficulty.normal,
        duration: ExamDuration.min30,
      ));

  testWidgets('student generates a paper, answers, and submits after confirming', (tester) async {
    phoneSize(tester);
    final store = MemoryExamStore();
    await tester.pumpWidget(ExamPortalApp(bankLoader: () async => bank, store: store));
    await tester.pumpAndSettle();

    // Board, class and subject are pre-selected because the bank has one of each.
    expect(find.text('CBSE'), findsOneWidget);
    expect(find.text('Class 10'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);

    // Board pattern is the default; this test uses a short custom paper.
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Generate paper'), 200);
    await tester.tap(find.text('Generate paper'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not from real board papers'), findsOneWidget);

    await tester.tap(find.text('Start exam (30 min)'));
    await tester.pumpAndSettle();
    expect(find.text('Q1 of 12'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^(30:00|29:5\d)$')), findsOneWidget); // real clock in this test

    // Answering auto-saves.
    await tester.tap(find.byType(RadioListTile<int>).first);
    await tester.pump();
    expect(store.saved, contains('"choices":{"0":0}'));

    await tester.tap(find.byTooltip('Next question'));
    await tester.pump();
    expect(find.text('Q2 of 12'), findsOneWidget);

    // Cancelling the confirm keeps the exam going.
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('answered 1 of 12'), findsOneWidget);
    await tester.tap(find.text('Keep working'));
    await tester.pumpAndSettle();
    expect(find.text('Q2 of 12'), findsOneWidget);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
    await tester.pumpAndSettle();
    expect(find.text('Your paper has been submitted.'), findsOneWidget);
    expect(store.saved, isNull);
  });

  testWidgets('the paper is submitted automatically when time runs out', (tester) async {
    phoneSize(tester);
    var now = DateTime(2026, 1, 1, 10);
    final session = ExamSession.start(mcqPaper(), now: now);
    final store = MemoryExamStore();
    await tester.pumpWidget(MaterialApp(
      home: ExamScreen(session: session, store: store, clock: () => now),
    ));
    await tester.pump();
    expect(find.text('30:00'), findsOneWidget);

    now = now.add(const Duration(minutes: 26));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('04:00'), findsOneWidget); // under 5 minutes: shown in warning colour

    now = now.add(const Duration(minutes: 4));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining("Time's up"), findsOneWidget);
    expect(store.saved, isNull);
  });

  testWidgets('an unfinished exam can be resumed with its answers', (tester) async {
    phoneSize(tester);
    final store = MemoryExamStore();
    final session = ExamSession.start(mcqPaper())
      ..choices[0] = 2
      ..flagged.add(1)
      ..current = 1;
    await store.save(session);

    await tester.pumpWidget(ExamPortalApp(bankLoader: () async => bank, store: store));
    await tester.pumpAndSettle();
    expect(find.text('You have an unfinished exam'), findsOneWidget);

    await tester.tap(find.text('Resume exam'));
    await tester.pumpAndSettle();
    expect(find.text('Q2 of 12'), findsOneWidget);

    await tester.tap(find.byTooltip('All questions'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 12 answered'), findsOneWidget);
    expect(find.bySemanticsLabel('Question 2, not answered, flagged, current'), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // stop the exam timer
  });

  test('a saved session round-trips with shuffled options intact', () async {
    final store = MemoryExamStore();
    final session = ExamSession.start(mcqPaper())..choices[3] = 1;
    await store.save(session);
    final restored = (await store.load(bank.questions))!;
    expect(restored.choices, {3: 1});
    expect(restored.endsAt, session.endsAt);
    for (var i = 0; i < session.length; i++) {
      expect(restored.paper.questions[i].options, session.paper.questions[i].options);
      expect(restored.paper.questions[i].answerIndex, session.paper.questions[i].answerIndex);
    }
  });
}
