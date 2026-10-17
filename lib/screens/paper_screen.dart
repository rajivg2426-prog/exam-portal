import 'package:flutter/material.dart';

import '../models/exam_session.dart';
import '../models/question.dart';
import '../services/exam_store.dart';
import '../services/paper_generator.dart';
import 'exam_screen.dart';

/// Preview of a generated paper, with the button that starts the timed exam.
class PaperScreen extends StatelessWidget {
  const PaperScreen({super.key, required this.paper, required this.store});

  final Paper paper;
  final ExamStore store;

  void _start(BuildContext context) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ExamScreen(session: ExamSession.start(paper), store: store),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final config = paper.config;
    final theme = Theme.of(context);
    final scope = config.isFullSyllabus ? 'Full syllabus' : config.chapters!.join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Your paper')),
      bottomNavigationBar: paper.questions.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: () => _start(context),
                  icon: const Icon(Icons.timer_outlined),
                  label: Text('Start exam (${config.duration.label})'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: paper.questions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No questions in the bank match these choices yet. '
                      'Try another question type, difficulty or chapter.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('${config.board} · Class ${config.grade} · ${config.subject}',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        '$scope · ${config.type == QuestionType.mcq ? 'MCQ' : 'Subjective'} · '
                        '${config.difficulty == Difficulty.tough ? 'Tough' : 'Normal'}',
                      ),
                      Text('Time: ${config.duration.label} · Maximum marks: ${paper.totalMarks}'),
                      const SizedBox(height: 12),
                      if (paper.hasSampleQuestions)
                        const _Notice(
                          icon: Icons.info_outline,
                          text: 'These are sample practice questions written for this app. '
                              'They are not from real board papers.',
                        ),
                      if (paper.isShort)
                        _Notice(
                          icon: Icons.warning_amber_outlined,
                          text: 'The question bank has only ${paper.totalMarks} marks of matching questions, '
                              'so this paper is shorter than a usual ${config.duration.label} paper '
                              '(${config.duration.targetMarks} marks).',
                        ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < paper.questions.length; i++)
                        _QuestionCard(number: i + 1, item: paper.questions[i]),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer))),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.number, required this.item});

  final int number;
  final PaperQuestion item;

  @override
  Widget build(BuildContext context) {
    final q = item.question;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text('Q$number. ${q.text}', style: theme.textTheme.bodyLarge)),
                const SizedBox(width: 8),
                Text('[${q.marks}]', semanticsLabel: '${q.marks} marks', style: theme.textTheme.labelLarge),
              ],
            ),
            if (item.options.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (var i = 0; i < item.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('(${String.fromCharCode(97 + i)}) ${item.options[i]}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
