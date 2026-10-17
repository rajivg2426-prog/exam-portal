import '../models/question.dart';
import '../services/paper_generator.dart';
import 'exam_session.dart';

enum AnswerStatus { correct, wrong, skipped, toMark, marked }

/// A submitted paper with everything needed to show results and analytics.
///
/// MCQs are marked automatically. Subjective answers are marked by the
/// student against the model solution; until then they count as 0 and show
/// as "to mark".
class ExamResult {
  ExamResult({
    required this.id,
    required this.session,
    required this.submittedAt,
    required this.timeUp,
    Map<int, int>? awarded,
  }) : awarded = awarded ?? {};

  factory ExamResult.fromSession(ExamSession session, {required DateTime submittedAt, required bool timeUp}) =>
      ExamResult(
        id: submittedAt.microsecondsSinceEpoch.toString(),
        session: session,
        submittedAt: submittedAt,
        timeUp: timeUp,
      );

  final String id;
  final ExamSession session;
  final DateTime submittedAt;
  final bool timeUp;

  /// Subjective marks the student gave themselves: question position → marks.
  final Map<int, int> awarded;

  Paper get paper => session.paper;
  PaperConfig get config => paper.config;
  int get length => session.length;
  int get totalMarks => paper.totalMarks;

  Duration get timeTaken {
    final taken = submittedAt.difference(session.startedAt);
    final max = session.endsAt.difference(session.startedAt);
    return taken > max ? max : taken;
  }

  AnswerStatus status(int i) {
    final item = paper.questions[i];
    if (!session.isAnswered(i)) return AnswerStatus.skipped;
    if (item.question.type == QuestionType.mcq) {
      return session.choices[i] == item.answerIndex ? AnswerStatus.correct : AnswerStatus.wrong;
    }
    return awarded.containsKey(i) ? AnswerStatus.marked : AnswerStatus.toMark;
  }

  int marksFor(int i) {
    final item = paper.questions[i];
    if (item.question.type == QuestionType.mcq) {
      return status(i) == AnswerStatus.correct ? item.question.marks : 0;
    }
    return awarded[i] ?? 0;
  }

  int get score => List.generate(length, marksFor).fold(0, (a, b) => a + b);

  /// Score as a whole-number percentage of the paper's marks.
  int get percent => totalMarks == 0 ? 0 : (score * 100 / totalMarks).round();

  int count(AnswerStatus s) => List.generate(length, status).where((x) => x == s).length;

  /// Marks scored and available per chapter, in paper order.
  Map<String, ({int scored, int total})> get byChapter {
    final out = <String, ({int scored, int total})>{};
    for (var i = 0; i < length; i++) {
      final q = paper.questions[i].question;
      final prev = out[q.chapter] ?? (scored: 0, total: 0);
      out[q.chapter] = (scored: prev.scored + marksFor(i), total: prev.total + q.marks);
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'session': session.toJson(),
    'submittedAt': submittedAt.toIso8601String(),
    'timeUp': timeUp,
    'awarded': {for (final e in awarded.entries) '${e.key}': e.value},
  };

  /// Returns null if a question the result used is no longer in the bank.
  static ExamResult? fromJson(Map<String, dynamic> json, List<Question> bank) {
    final session = ExamSession.fromJson(json['session'] as Map<String, dynamic>, bank);
    if (session == null) return null;
    return ExamResult(
      id: json['id'] as String,
      session: session,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      timeUp: json['timeUp'] as bool,
      awarded: (json['awarded'] as Map<String, dynamic>).map((k, v) => MapEntry(int.parse(k), v as int)),
    );
  }
}

/// Totals across all of a student's results, for the dashboard.
class ResultsSummary {
  ResultsSummary(this.results);

  /// Newest first.
  final List<ExamResult> results;

  int get attempts => results.length;

  int get averagePercent =>
      results.isEmpty ? 0 : (results.map((r) => r.percent).reduce((a, b) => a + b) / results.length).round();

  int get bestPercent => results.isEmpty ? 0 : results.map((r) => r.percent).reduce((a, b) => a > b ? a : b);

  /// Per subject and chapter, the share of marks scored across all papers,
  /// weakest first.
  List<({String subject, String chapter, int scored, int total})> get chapters {
    final totals = <(String, String), ({int scored, int total})>{};
    for (final r in results) {
      for (final e in r.byChapter.entries) {
        final key = (r.config.subject, e.key);
        final prev = totals[key] ?? (scored: 0, total: 0);
        totals[key] = (scored: prev.scored + e.value.scored, total: prev.total + e.value.total);
      }
    }
    final list = [
      for (final e in totals.entries)
        (subject: e.key.$1, chapter: e.key.$2, scored: e.value.scored, total: e.value.total),
    ];
    list.sort((a, b) => (a.scored / a.total).compareTo(b.scored / b.total));
    return list;
  }
}
