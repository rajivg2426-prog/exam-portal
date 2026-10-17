import 'package:flutter/material.dart';

import '../models/exam_result.dart';
import '../models/question.dart';
import '../services/exam_store.dart';

/// Score, chapter breakdown and a review of every answer with its solution.
/// Subjective answers are marked here by the student against the solution.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.result, required this.store, this.justSubmitted = false});

  final ExamResult result;
  final ExamStore store;

  /// True when opened straight after submitting (vs from My results).
  final bool justSubmitted;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  ExamResult get _r => widget.result;

  void _award(int i, int marks) {
    setState(() => _r.awarded[i] = marks);
    widget.store.saveResult(_r);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _r.config;
    final toMark = _r.count(AnswerStatus.toMark);
    final isMcq = c.type == QuestionType.mcq;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        automaticallyImplyLeading: !widget.justSubmitted,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.justSubmitted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _r.timeUp ? "Time's up. Your paper was submitted automatically." : 'Your paper has been submitted.',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                Text('${c.board} · Class ${c.grade} · ${c.subject}', style: theme.textTheme.titleLarge),
                Text('${c.isFullSyllabus ? 'Full syllabus' : c.chapters!.join(', ')} · '
                    '${isMcq ? 'MCQ' : 'Subjective'} · ${c.difficulty == Difficulty.tough ? 'Tough' : 'Normal'}'),
                const SizedBox(height: 16),
                _ScoreCard(result: _r),
                if (toMark > 0)
                  Card(
                    color: theme.colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '$toMark ${toMark == 1 ? 'answer needs' : 'answers need'} marking. Open each one below, '
                        'compare it with the solution and choose the marks you earned.',
                        style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text('By chapter', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final e in _r.byChapter.entries)
                  _ChapterBar(chapter: e.key, scored: e.value.scored, total: e.value.total),
                const SizedBox(height: 16),
                Text('Review answers', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                for (var i = 0; i < _r.length; i++)
                  _ReviewTile(result: _r, index: i, onAward: (m) => _award(i, m)),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: const Text('Back to home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.result});

  final ExamResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    final isMcq = r.config.type == QuestionType.mcq;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${r.score}', style: theme.textTheme.displaySmall),
                Text(' / ${r.totalMarks}', style: theme.textTheme.titleLarge),
                const Spacer(),
                Text('${r.percent}%', style: theme.textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: r.totalMarks == 0 ? 0 : r.score / r.totalMarks, minHeight: 8),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                if (isMcq) ...[
                  _Stat('Correct', r.count(AnswerStatus.correct)),
                  _Stat('Wrong', r.count(AnswerStatus.wrong)),
                ] else ...[
                  _Stat('Marked', r.count(AnswerStatus.marked)),
                  _Stat('To mark', r.count(AnswerStatus.toMark)),
                ],
                _Stat('Skipped', r.count(AnswerStatus.skipped)),
                _Stat('Time', '${r.timeTaken.inMinutes} min'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ChapterBar extends StatelessWidget {
  const _ChapterBar({required this.chapter, required this.scored, required this.total});

  final String chapter;
  final int scored;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(chapter)), Text('$scored / $total')]),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: total == 0 ? 0 : scored / total, minHeight: 6),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.result, required this.index, required this.onAward});

  final ExamResult result;
  final int index;
  final ValueChanged<int> onAward;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = result.paper.questions[index];
    final q = item.question;
    final status = result.status(index);
    final (icon, color, label) = _statusLook(context, status);

    return Card(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: color, semanticLabel: label),
        title: Text('Q${index + 1} · ${result.marksFor(index)} / ${q.marks} marks'),
        subtitle: Text(q.text, maxLines: 1, overflow: TextOverflow.ellipsis),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.text, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          if (q.type == QuestionType.mcq)
            for (var o = 0; o < item.options.length; o++)
              _OptionLine(
                text: '(${String.fromCharCode(97 + o)}) ${item.options[o]}',
                isCorrect: o == item.answerIndex,
                isChosen: o == result.session.choices[index],
              )
          else ...[
            Text('Your answer', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              result.session.isAnswered(index) ? result.session.written[index]!.trim() : 'Not answered',
              style: result.session.isAnswered(index) ? null : TextStyle(color: theme.colorScheme.outline),
            ),
          ],
          const SizedBox(height: 12),
          Text('Solution', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(q.solution),
          if (q.type == QuestionType.subjective && result.session.isAnswered(index)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Marks you earned')),
                DropdownButton<int>(
                  value: result.awarded[index],
                  hint: const Text('Choose'),
                  items: [for (var m = 0; m <= q.marks; m++) DropdownMenuItem(value: m, child: Text('$m / ${q.marks}'))],
                  onChanged: (m) => m == null ? null : onAward(m),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (IconData, Color, String) _statusLook(BuildContext context, AnswerStatus s) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final green = dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    final scheme = Theme.of(context).colorScheme;
    return switch (s) {
      AnswerStatus.correct => (Icons.check_circle, green, 'Correct'),
      AnswerStatus.wrong => (Icons.cancel, scheme.error, 'Wrong'),
      AnswerStatus.skipped => (Icons.remove_circle_outline, scheme.outline, 'Skipped'),
      AnswerStatus.toMark => (Icons.rate_review_outlined, scheme.tertiary, 'Needs marking'),
      AnswerStatus.marked => (Icons.task_alt, green, 'Marked'),
    };
  }
}

class _OptionLine extends StatelessWidget {
  const _OptionLine({required this.text, required this.isCorrect, required this.isChosen});

  final String text;
  final bool isCorrect;
  final bool isChosen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final green = dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    final note = [if (isCorrect) 'correct answer', if (isChosen) 'your answer'].join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: isCorrect
                ? Icon(Icons.check, size: 20, color: green)
                : isChosen
                    ? Icon(Icons.close, size: 20, color: scheme.error)
                    : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note.isEmpty ? text : '$text  ($note)',
              style: TextStyle(fontWeight: isCorrect || isChosen ? FontWeight.w600 : null),
            ),
          ),
        ],
      ),
    );
  }
}
