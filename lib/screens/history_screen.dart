import 'package:flutter/material.dart';

import '../data/question_bank.dart';
import '../models/exam_result.dart';
import '../models/question.dart';
import '../services/exam_store.dart';
import 'result_screen.dart';

/// The student's dashboard: overall scores, chapters to work on, and every
/// past paper.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.bank, required this.store});

  final QuestionBank bank;
  final ExamStore store;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<ExamResult>> _results = _load();

  Future<List<ExamResult>> _load() => widget.store.loadResults(widget.bank.questions);

  Future<void> _open(ExamResult r) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(result: r, store: widget.store),
    ));
    setState(() => _results = _load()); // marks may have changed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My results')),
      body: SafeArea(
        child: FutureBuilder<List<ExamResult>>(
          future: _results,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final results = snapshot.data!;
            if (results.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No results yet. Finish a paper to see your scores here.', textAlign: TextAlign.center),
                ),
              );
            }
            return _Dashboard(summary: ResultsSummary(results), onOpen: _open);
          },
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.summary, required this.onOpen});

  final ResultsSummary summary;
  final ValueChanged<ExamResult> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weak = summary.chapters.where((c) => c.scored / c.total < 0.6).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: _Tile(label: 'Papers', value: '${summary.attempts}')),
                const SizedBox(width: 8),
                Expanded(child: _Tile(label: 'Average', value: '${summary.averagePercent}%')),
                const SizedBox(width: 8),
                Expanded(child: _Tile(label: 'Best', value: '${summary.bestPercent}%')),
              ],
            ),
            const SizedBox(height: 20),
            Text('Chapters', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              weak.isEmpty
                  ? 'You are scoring 60% or more in every chapter you have practised.'
                  : 'Below 60% so far: ${weak.map((c) => c.chapter).join(', ')}.',
            ),
            const SizedBox(height: 8),
            for (final c in summary.chapters)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text('${c.chapter} · ${c.subject}')),
                      Text('${(c.scored * 100 / c.total).round()}%'),
                    ]),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: c.scored / c.total, minHeight: 6),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text('Past papers', style: theme.textTheme.titleMedium),
            for (final r in summary.results)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  title: Text('${r.config.subject} · Class ${r.config.grade} · '
                      '${r.config.type == QuestionType.mcq ? 'MCQ' : 'Subjective'}'),
                  subtitle: Text('${_date(r.submittedAt)} · ${r.config.duration.label}'
                      '${r.count(AnswerStatus.toMark) > 0 ? ' · needs marking' : ''}'),
                  trailing: Text('${r.percent}%', style: theme.textTheme.titleMedium),
                  onTap: () => onOpen(r),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}, $hh:$mm';
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
