import 'dart:io';

import 'package:exam_portal/data/question_bank.dart';
import 'package:exam_portal/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File('assets/question_bank/sample_questions.json').readAsStringSync();

  testWidgets('student can generate a paper and sees the sample notice', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ExamPortalApp(bankLoader: () async => QuestionBank.fromJsonString(raw)));
    await tester.pumpAndSettle();

    // Board, class and subject are pre-selected because the bank has one of each.
    expect(find.text('CBSE'), findsOneWidget);
    expect(find.text('Class 10'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Generate paper'), 200);
    await tester.tap(find.text('Generate paper'));
    await tester.pumpAndSettle();

    expect(find.text('Your paper'), findsOneWidget);
    expect(find.textContaining('not from real board papers'), findsOneWidget);
    expect(find.textContaining('Q1.'), findsOneWidget);
  });
}
