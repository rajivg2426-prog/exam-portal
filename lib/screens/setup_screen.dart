import 'package:flutter/material.dart';

import '../data/question_bank.dart';
import '../models/exam_session.dart';
import '../models/question.dart';
import '../services/exam_store.dart';
import '../services/paper_generator.dart';
import 'exam_screen.dart';
import 'history_screen.dart';
import 'paper_screen.dart';

/// Lets the student pick board, class, subject, chapters, question type,
/// difficulty and duration. Only options that exist in the bank are offered.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.bank, required this.store});

  final QuestionBank bank;
  final ExamStore store;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? _board;
  int? _grade;
  String? _subject;
  bool _fullSyllabus = true;
  final Set<String> _chapters = {};
  QuestionType _type = QuestionType.mcq;
  Difficulty _difficulty = Difficulty.normal;
  ExamDuration _duration = ExamDuration.min30;
  bool _pastPapersOnly = false;
  PaperPattern _pattern = PaperPattern.board;

  ExamSession? _unfinished;

  QuestionBank get _bank => widget.bank;

  @override
  void initState() {
    super.initState();
    final boards = _bank.boards;
    if (boards.length == 1) _selectBoard(boards.single);
    _checkUnfinished();
  }

  Future<void> _checkUnfinished() async {
    final saved = await widget.store.load(_bank.questions);
    if (mounted) setState(() => _unfinished = saved);
  }

  Future<void> _resume() async {
    final session = _unfinished!;
    setState(() => _unfinished = null);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamScreen(session: session, store: widget.store),
      ),
    );
    _checkUnfinished();
  }

  Future<void> _discard() async {
    await widget.store.clear();
    if (mounted) setState(() => _unfinished = null);
  }

  void _selectBoard(String? board) {
    _board = board;
    _grade = null;
    _subject = null;
    _chapters.clear();
    final grades = board == null ? <int>[] : _bank.gradesFor(board);
    if (grades.length == 1) _selectGrade(grades.single);
  }

  void _selectGrade(int? grade) {
    _grade = grade;
    _subject = null;
    _chapters.clear();
    final subjects = grade == null ? <String>[] : _bank.subjectsFor(_board!, grade);
    if (subjects.length == 1) _subject = subjects.single;
  }

  bool get _isBoard => _pattern == PaperPattern.board;

  bool get _canGenerate =>
      _board != null && _grade != null && _subject != null && (_isBoard || _fullSyllabus || _chapters.isNotEmpty);

  Future<void> _generate() async {
    final pastOnly = _pastPapersOnly && _bank.hasPastPapers(_board!, _grade!, _subject!);
    final config = _isBoard
        ? PaperConfig.boardPattern(
            board: _board!,
            grade: _grade!,
            subject: _subject!,
            difficulty: _difficulty,
            pastPapersOnly: pastOnly,
          )
        : PaperConfig(
            board: _board!,
            grade: _grade!,
            subject: _subject!,
            chapters: _fullSyllabus ? null : Set.of(_chapters),
            type: _type,
            difficulty: _difficulty,
            duration: _duration,
            pastPapersOnly: pastOnly,
          );
    // Questions from the student's earlier papers go last, so each new paper
    // is as fresh as the bank allows.
    final seen = {
      for (final r in await widget.store.loadResults(_bank.questions))
        for (final q in r.paper.questions) q.question.id,
    };
    final paper = PaperGenerator(_bank.questions, seenIds: seen).generate(config);
    if (!mounted) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PaperScreen(paper: paper, store: widget.store),
          ),
        )
        .then((_) => _checkUnfinished());
  }

  @override
  Widget build(BuildContext context) {
    final grades = _board == null ? <int>[] : _bank.gradesFor(_board!);
    final subjects = _grade == null ? <String>[] : _bank.subjectsFor(_board!, _grade!);
    final chapters = _subject == null ? <String>[] : _bank.chaptersFor(_board!, _grade!, _subject!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a practice paper'),
        actions: [
          IconButton(
            tooltip: 'My results',
            icon: const Icon(Icons.insights),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HistoryScreen(bank: _bank, store: widget.store),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_unfinished != null) _ResumeCard(onResume: _resume, onDiscard: _discard),
                _Section(
                  label: 'Board',
                  child: DropdownButtonFormField<String>(
                    initialValue: _board,
                    hint: const Text('Choose board'),
                    items: [for (final b in _bank.boards) DropdownMenuItem(value: b, child: Text(b))],
                    onChanged: (v) => setState(() => _selectBoard(v)),
                  ),
                ),
                _Section(
                  label: 'Class',
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('grade-$_board'),
                    initialValue: _grade,
                    hint: const Text('Choose class'),
                    items: [for (final g in grades) DropdownMenuItem(value: g, child: Text('Class $g'))],
                    onChanged: _board == null ? null : (v) => setState(() => _selectGrade(v)),
                  ),
                ),
                _Section(
                  label: 'Subject',
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('subject-$_board-$_grade'),
                    initialValue: _subject,
                    hint: const Text('Choose subject'),
                    items: [for (final s in subjects) DropdownMenuItem(value: s, child: Text(s))],
                    onChanged: _grade == null
                        ? null
                        : (v) => setState(() {
                            _subject = v;
                            _chapters.clear();
                          }),
                  ),
                ),
                _Section(
                  label: 'Paper',
                  child: SegmentedButton<PaperPattern>(
                    segments: const [
                      ButtonSegment(value: PaperPattern.board, label: Text('Board pattern')),
                      ButtonSegment(value: PaperPattern.custom, label: Text('Custom')),
                    ],
                    selected: {_pattern},
                    onSelectionChanged: (s) => setState(() => _pattern = s.single),
                  ),
                ),
                if (_isBoard && _subject != null) _BoardPatternCard(subject: _subject!),
                if (!_isBoard)
                  _Section(
                    label: 'Syllabus',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('Full syllabus')),
                            ButtonSegment(value: false, label: Text('Chapters')),
                          ],
                          selected: {_fullSyllabus},
                          onSelectionChanged: (s) => setState(() => _fullSyllabus = s.single),
                        ),
                        if (!_fullSyllabus) ...[
                          const SizedBox(height: 12),
                          if (chapters.isEmpty) const Text('Choose a subject to see its chapters.'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final c in chapters)
                                FilterChip(
                                  label: Text(c),
                                  selected: _chapters.contains(c),
                                  onSelected: (on) => setState(() => on ? _chapters.add(c) : _chapters.remove(c)),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                if (_subject != null && _bank.hasPastPapers(_board!, _grade!, _subject!))
                  _Section(
                    label: 'Questions from',
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('All')),
                        ButtonSegment(value: true, label: Text('Past papers only')),
                      ],
                      selected: {_pastPapersOnly},
                      onSelectionChanged: (s) => setState(() => _pastPapersOnly = s.single),
                    ),
                  ),
                if (!_isBoard)
                  _Section(
                    label: 'Question type',
                    child: SegmentedButton<QuestionType>(
                      segments: const [
                        ButtonSegment(value: QuestionType.mcq, label: Text('MCQ')),
                        ButtonSegment(value: QuestionType.subjective, label: Text('Subjective')),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => setState(() => _type = s.single),
                    ),
                  ),
                _Section(
                  label: 'Difficulty',
                  child: SegmentedButton<Difficulty>(
                    segments: const [
                      ButtonSegment(value: Difficulty.normal, label: Text('Normal')),
                      ButtonSegment(value: Difficulty.tough, label: Text('Tough')),
                    ],
                    selected: {_difficulty},
                    onSelectionChanged: (s) => setState(() => _difficulty = s.single),
                  ),
                ),
                if (!_isBoard)
                  _Section(
                    label: 'Duration',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in ExamDuration.values)
                          ChoiceChip(
                            label: Text(d.label),
                            selected: _duration == d,
                            onSelected: (_) => setState(() => _duration = d),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _canGenerate ? _generate : null,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Generate paper'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardPatternCard extends StatelessWidget {
  const _BoardPatternCard({required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = boardSectionsFor(subject);
    final questions = sections.fold(0, (n, s) => n + s.count);
    final marks = boardMarksFor(subject);
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Full syllabus · $questions questions · $marks marks · 3 hours', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            const Text('A new random paper every time, laid out like the CBSE board exam.'),
            const SizedBox(height: 8),
            for (final s in sections)
              Text(
                'Section ${s.name}: ${s.title}, ${s.count} × ${s.marks} '
                '${s.marks == 1 ? 'mark' : 'marks'}',
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.onResume, required this.onDiscard});

  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have an unfinished exam',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onTertiaryContainer),
            ),
            const SizedBox(height: 4),
            Text(
              'Your answers were saved. The timer kept running while you were away.',
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(onPressed: onResume, child: const Text('Resume exam')),
                TextButton(onPressed: onDiscard, child: const Text('Discard')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
