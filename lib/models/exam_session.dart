import '../services/paper_generator.dart';
import 'question.dart';

/// A student's attempt at one paper: answers, flags and the deadline.
///
/// The timer is stored as an absolute [endsAt], so reopening the app resumes
/// with the right time left (the clock keeps running while the app is closed).
class ExamSession {
  ExamSession({
    required this.paper,
    required this.startedAt,
    required this.endsAt,
    Map<int, int>? choices,
    Map<int, String>? written,
    Set<int>? flagged,
    this.current = 0,
  }) : choices = choices ?? {},
       written = written ?? {},
       flagged = flagged ?? {};

  factory ExamSession.start(Paper paper, {DateTime? now}) {
    final start = now ?? DateTime.now();
    return ExamSession(
      paper: paper,
      startedAt: start,
      endsAt: start.add(Duration(minutes: paper.config.duration.minutes)),
    );
  }

  final Paper paper;
  final DateTime startedAt;
  final DateTime endsAt;

  /// MCQ answers: question position → chosen option index.
  final Map<int, int> choices;

  /// Subjective answers: question position → text.
  final Map<int, String> written;

  /// Questions the student marked to come back to.
  final Set<int> flagged;
  int current;

  int get length => paper.questions.length;

  Duration remaining(DateTime now) {
    final left = endsAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isAnswered(int i) => choices.containsKey(i) || (written[i]?.trim().isNotEmpty ?? false);

  int get answeredCount => List.generate(length, isAnswered).where((a) => a).length;

  /// Correct MCQ answers, or null for subjective papers (marked later).
  int? get mcqScore {
    if (paper.config.type != QuestionType.mcq) return null;
    var score = 0;
    for (final e in choices.entries) {
      final item = paper.questions[e.key];
      if (item.answerIndex == e.value) score += item.question.marks;
    }
    return score;
  }

  Map<String, dynamic> toJson() => {
    'config': paper.config.toJson(),
    'questions': [
      for (final q in paper.questions)
        {'id': q.question.id, 'options': q.options, 'answerIndex': q.answerIndex, 'section': q.section},
    ],
    'startedAt': startedAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'choices': {for (final e in choices.entries) '${e.key}': e.value},
    'written': {for (final e in written.entries) '${e.key}': e.value},
    'flagged': flagged.toList(),
    'current': current,
  };

  /// Rebuilds a saved session. Returns null if a question it used is no
  /// longer in the bank.
  static ExamSession? fromJson(Map<String, dynamic> json, List<Question> bank) {
    final byId = {for (final q in bank) q.id: q};
    final items = <PaperQuestion>[];
    for (final raw in (json['questions'] as List).cast<Map<String, dynamic>>()) {
      final q = byId[raw['id']];
      if (q == null) return null;
      items.add(
        PaperQuestion(
          question: q,
          options: (raw['options'] as List).cast<String>(),
          answerIndex: raw['answerIndex'] as int?,
          section: raw['section'] as String?,
        ),
      );
    }
    return ExamSession(
      paper: Paper(config: PaperConfig.fromJson(json['config'] as Map<String, dynamic>), questions: items),
      startedAt: DateTime.parse(json['startedAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      choices: (json['choices'] as Map<String, dynamic>).map((k, v) => MapEntry(int.parse(k), v as int)),
      written: (json['written'] as Map<String, dynamic>).map((k, v) => MapEntry(int.parse(k), v as String)),
      flagged: (json['flagged'] as List).cast<int>().toSet(),
      current: json['current'] as int,
    );
  }
}
