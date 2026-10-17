import 'package:flutter/material.dart';

import '../models/exam_session.dart';

/// Shown right after submitting. Full results, solutions and analytics come
/// in phase 3.
class SubmittedScreen extends StatelessWidget {
  const SubmittedScreen({super.key, required this.session, required this.submittedAt, required this.timeUp});

  final ExamSession session;
  final DateTime submittedAt;
  final bool timeUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taken = submittedAt.difference(session.startedAt);
    final maxTime = session.endsAt.difference(session.startedAt);
    final minutes = (taken > maxTime ? maxTime : taken).inMinutes;
    final score = session.mcqScore;

    return Scaffold(
      appBar: AppBar(title: const Text('Paper submitted'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(timeUp ? Icons.timer_off_outlined : Icons.check_circle_outline,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  timeUp ? "Time's up. Your paper was submitted automatically." : 'Your paper has been submitted.',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _Row('Answered', '${session.answeredCount} of ${session.length}'),
                _Row('Time taken', '$minutes min'),
                if (score != null) _Row('Score', '$score / ${session.paper.totalMarks}'),
                if (score == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Subjective answers will be checked against the solutions in the results screen.'),
                  ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: const Text('Create another paper'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
