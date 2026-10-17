import 'dart:math';

import '../models/question.dart';

enum ExamDuration {
  min30(30, 12),
  hour1(60, 25),
  hour2(120, 50),
  hour3(180, 80);

  const ExamDuration(this.minutes, this.targetMarks);

  final int minutes;

  /// Marks a full paper of this length aims for (a 3-hour board paper is 80).
  final int targetMarks;

  String get label => minutes < 60 ? '$minutes min' : '${minutes ~/ 60} hr';
}

class PaperConfig {
  const PaperConfig({
    required this.board,
    required this.grade,
    required this.subject,
    required this.type,
    required this.difficulty,
    required this.duration,
    this.chapters,
  });

  final String board;
  final int grade;
  final String subject;

  /// `null` means full syllabus.
  final Set<String>? chapters;
  final QuestionType type;
  final Difficulty difficulty;
  final ExamDuration duration;

  bool get isFullSyllabus => chapters == null;

  Map<String, dynamic> toJson() => {
        'board': board,
        'grade': grade,
        'subject': subject,
        'chapters': chapters?.toList(),
        'type': type.name,
        'difficulty': difficulty.name,
        'duration': duration.name,
      };

  factory PaperConfig.fromJson(Map<String, dynamic> json) => PaperConfig(
        board: json['board'] as String,
        grade: json['grade'] as int,
        subject: json['subject'] as String,
        chapters: (json['chapters'] as List?)?.cast<String>().toSet(),
        type: QuestionType.values.byName(json['type'] as String),
        difficulty: Difficulty.values.byName(json['difficulty'] as String),
        duration: ExamDuration.values.byName(json['duration'] as String),
      );
}

/// A question as it appears on one generated paper. MCQ options are shuffled
/// per paper, so [answerIndex] points into [options], not the bank's order.
class PaperQuestion {
  const PaperQuestion({required this.question, required this.options, this.answerIndex});

  final Question question;
  final List<String> options;
  final int? answerIndex;
}

class Paper {
  const Paper({required this.config, required this.questions});

  final PaperConfig config;
  final List<PaperQuestion> questions;

  int get totalMarks => questions.fold(0, (sum, q) => sum + q.question.marks);

  /// True when the bank didn't have enough matching questions to reach the
  /// usual marks for this duration.
  bool get isShort => totalMarks < config.duration.targetMarks;

  bool get hasSampleQuestions => questions.any((q) => q.question.isSample);
}

class PaperGenerator {
  PaperGenerator(this.bank, {Random? random}) : _random = random ?? Random();

  final List<Question> bank;
  final Random _random;

  /// Builds a paper only from bank questions whose tags match [config].
  ///
  /// Normal papers use normal questions. Tough papers use tough questions
  /// first and top up with normal ones if the bank runs short.
  Paper generate(PaperConfig config) {
    final matching = bank.where((q) =>
        q.board == config.board &&
        q.grade == config.grade &&
        q.subject == config.subject &&
        q.type == config.type &&
        (config.chapters == null || config.chapters!.contains(q.chapter)));

    final tough = matching.where((q) => q.difficulty == Difficulty.tough).toList()..shuffle(_random);
    final normal = matching.where((q) => q.difficulty == Difficulty.normal).toList()..shuffle(_random);
    final pool = config.difficulty == Difficulty.tough ? [...tough, ...normal] : normal;

    final picked = <Question>[];
    var marks = 0;
    for (final q in pool) {
      if (marks >= config.duration.targetMarks) break;
      if (marks + q.marks > config.duration.targetMarks) continue;
      picked.add(q);
      marks += q.marks;
    }

    // Lower-mark questions first, like a board paper's sections.
    picked.sort((a, b) => a.marks.compareTo(b.marks));
    return Paper(config: config, questions: picked.map(_toPaperQuestion).toList());
  }

  PaperQuestion _toPaperQuestion(Question q) {
    if (q.type != QuestionType.mcq) return PaperQuestion(question: q, options: const []);
    final order = List.generate(q.options.length, (i) => i)..shuffle(_random);
    return PaperQuestion(
      question: q,
      options: [for (final i in order) q.options[i]],
      answerIndex: order.indexOf(q.answerIndex!),
    );
  }
}
