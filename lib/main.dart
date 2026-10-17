import 'package:flutter/material.dart';

import 'data/question_bank.dart';
import 'screens/setup_screen.dart';

void main() {
  runApp(const ExamPortalApp());
}

class ExamPortalApp extends StatelessWidget {
  const ExamPortalApp({super.key, this.bankLoader = QuestionBank.loadFromAssets});

  final Future<QuestionBank> Function() bankLoader;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3F51B5);
    return MaterialApp(
      title: 'Exam Practice Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: _BankLoader(loader: bankLoader),
    );
  }
}

class _BankLoader extends StatefulWidget {
  const _BankLoader({required this.loader});

  final Future<QuestionBank> Function() loader;

  @override
  State<_BankLoader> createState() => _BankLoaderState();
}

class _BankLoaderState extends State<_BankLoader> {
  late final Future<QuestionBank> _bank = widget.loader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuestionBank>(
      future: _bank,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Could not load the question bank.\n${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return SetupScreen(bank: snapshot.data!);
      },
    );
  }
}
