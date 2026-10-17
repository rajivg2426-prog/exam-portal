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

/// How a paper is put together.
enum PaperPattern {
  /// The student's own choice of chapters, question type and length.
  custom,

  /// The CBSE board exam layout: sections A to E, 80 marks, 3 hours.
  board,
}

/// One section of the board pattern.
class BoardSection {
  const BoardSection(this.name, this.title, this.count, this.marks, {this.mcq = false, this.caseStudy = false});

  final String name;
  final String title;
  final int count;

  /// Marks per question (per case study for section E).
  final int marks;
  final bool mcq;
  final bool caseStudy;

  int get totalMarks => count * marks;
}

/// CBSE Class X board paper layout (2023 onwards).
const boardSections = [
  BoardSection('A', 'Multiple choice and assertion-reason', 20, 1, mcq: true),
  BoardSection('B', 'Very short answer', 5, 2),
  BoardSection('C', 'Short answer', 6, 3),
  BoardSection('D', 'Long answer', 4, 5),
  BoardSection('E', 'Case studies', 3, 4, caseStudy: true),
];

class PaperConfig {
  const PaperConfig({
    required this.board,
    required this.grade,
    required this.subject,
    required this.type,
    required this.difficulty,
    required this.duration,
    this.chapters,
    this.pastPapersOnly = false,
    this.pattern = PaperPattern.custom,
  });

  /// A full board-pattern paper: whole syllabus, both question types, 3 hours.
  const PaperConfig.boardPattern({
    required this.board,
    required this.grade,
    required this.subject,
    this.difficulty = Difficulty.normal,
    this.pastPapersOnly = false,
  }) : type = QuestionType.mcq,
       duration = ExamDuration.hour3,
       chapters = null,
       pattern = PaperPattern.board;

  final String board;
  final int grade;
  final String subject;

  /// `null` means full syllabus.
  final Set<String>? chapters;

  /// Custom papers only; board-pattern papers mix both types.
  final QuestionType type;
  final Difficulty difficulty;
  final ExamDuration duration;

  /// Use only questions from real board papers, no sample questions.
  final bool pastPapersOnly;
  final PaperPattern pattern;

  bool get isFullSyllabus => chapters == null;
  bool get isBoardPattern => pattern == PaperPattern.board;

  /// Short description of the question types, for headings.
  String get kindLabel => isBoardPattern ? 'Board pattern' : (type == QuestionType.mcq ? 'MCQ' : 'Subjective');

  /// Whether the paper can contain MCQs / subjective questions.
  bool get hasMcq => isBoardPattern || type == QuestionType.mcq;
  bool get hasSubjective => isBoardPattern || type == QuestionType.subjective;

  Map<String, dynamic> toJson() => {
    'board': board,
    'grade': grade,
    'subject': subject,
    'chapters': chapters?.toList(),
    'type': type.name,
    'difficulty': difficulty.name,
    'duration': duration.name,
    'pastPapersOnly': pastPapersOnly,
    'pattern': pattern.name,
  };

  factory PaperConfig.fromJson(Map<String, dynamic> json) => PaperConfig(
    board: json['board'] as String,
    grade: json['grade'] as int,
    subject: json['subject'] as String,
    chapters: (json['chapters'] as List?)?.cast<String>().toSet(),
    type: QuestionType.values.byName(json['type'] as String),
    difficulty: Difficulty.values.byName(json['difficulty'] as String),
    duration: ExamDuration.values.byName(json['duration'] as String),
    pastPapersOnly: json['pastPapersOnly'] as bool? ?? false,
    pattern: PaperPattern.values.byName(json['pattern'] as String? ?? 'custom'),
  );
}

/// A question as it appears on one generated paper. MCQ options are shuffled
/// per paper, so [answerIndex] points into [options], not the bank's order.
class PaperQuestion {
  const PaperQuestion({required this.question, required this.options, this.answerIndex, this.section});

  final Question question;
  final List<String> options;
  final int? answerIndex;

  /// Board-pattern section letter (A to E), or null for custom papers.
  final String? section;
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
  bool get hasPastPaperQuestions => questions.any((q) => q.question.isPastPaper);
}

class PaperGenerator {
  PaperGenerator(this.bank, {Random? random, this.seenIds = const {}}) : _random = random ?? Random();

  final List<Question> bank;
  final Random _random;

  /// Questions this student has already had on earlier papers. They are used
  /// only after every unseen question that fits.
  final Set<String> seenIds;

  Paper generate(PaperConfig config) => config.isBoardPattern ? _generateBoard(config) : _generateCustom(config);

  Iterable<Question> _matching(PaperConfig config) => bank.where(
    (q) =>
        q.board == config.board &&
        q.grade == config.grade &&
        q.subject == config.subject &&
        (!config.pastPapersOnly || q.isPastPaper) &&
        (config.chapters == null || config.chapters!.contains(q.chapter)),
  );

  /// Shuffles, then puts unseen questions first and, for tough papers, tough
  /// questions ahead of normal ones.
  List<Question> _ordered(Iterable<Question> questions, Difficulty difficulty) {
    final list = questions.toList()..shuffle(_random);
    int rank(Question q) =>
        (seenIds.contains(q.id) ? 2 : 0) + (difficulty == Difficulty.tough && q.difficulty != Difficulty.tough ? 1 : 0);
    return list..sort((a, b) => rank(a).compareTo(rank(b))); // List.sort is stable
  }

  /// Custom paper: questions of the chosen type up to the usual marks for the
  /// chosen duration. Normal papers use normal questions; tough papers use
  /// tough questions first and top up with normal ones.
  Paper _generateCustom(PaperConfig config) {
    final candidates = _matching(config).where(
      (q) => q.type == config.type && (config.difficulty == Difficulty.tough || q.difficulty == Difficulty.normal),
    );

    final picked = <Question>[];
    final origins = <String>{};
    var marks = 0;
    for (final q in _ordered(candidates, config.difficulty)) {
      if (marks >= config.duration.targetMarks) break;
      if (marks + q.marks > config.duration.targetMarks || origins.contains(q.originKey)) continue;
      picked.add(q);
      origins.add(q.originKey);
      marks += q.marks;
    }

    // Lower-mark questions first, like a board paper's sections.
    picked.sort((a, b) => a.marks.compareTo(b.marks));
    return Paper(config: config, questions: picked.map((q) => _toPaperQuestion(q)).toList());
  }

  /// Board-pattern paper: each section filled at random from the matching
  /// questions with that section's type and marks.
  Paper _generateBoard(PaperConfig config) {
    final matching = _matching(config).toList();
    final origins = <String>{};
    final items = <PaperQuestion>[];

    for (final section in boardSections) {
      if (section.caseStudy) {
        items.addAll(_pickCaseStudies(matching, section, config.difficulty));
        continue;
      }
      final candidates = matching.where(
        (q) =>
            q.caseStudy == null &&
            q.marks == section.marks &&
            q.type == (section.mcq ? QuestionType.mcq : QuestionType.subjective),
      );
      var count = 0;
      for (final q in _ordered(candidates, config.difficulty)) {
        if (count == section.count) break;
        if (!origins.add(q.originKey)) continue;
        items.add(_toPaperQuestion(q, section: section.name));
        count++;
      }
    }
    return Paper(config: config, questions: items);
  }

  /// Picks whole case studies worth [BoardSection.marks] each: both 1-mark
  /// parts plus one of the 2-mark alternatives, in their original order.
  List<PaperQuestion> _pickCaseStudies(List<Question> matching, BoardSection section, Difficulty difficulty) {
    final groups = <String, List<Question>>{};
    for (final q in matching.where((q) => q.caseStudy != null)) {
      groups.putIfAbsent(q.caseStudy!, () => []).add(q);
    }
    final complete =
        groups.entries
            .where((g) {
              final ones = g.value.where((q) => q.marks == 1).length;
              return ones == 2 && g.value.any((q) => q.marks == 2);
            })
            .map((g) => g.key)
            .toList()
          ..shuffle(_random);
    // Unseen case studies first.
    complete.sort((a, b) {
      bool seen(String g) => groups[g]!.any((q) => seenIds.contains(q.id));
      return (seen(a) ? 1 : 0).compareTo(seen(b) ? 1 : 0);
    });

    final items = <PaperQuestion>[];
    for (final g in complete.take(section.count)) {
      final parts = groups[g]!;
      final twos = _ordered(parts.where((q) => q.marks == 2), difficulty);
      final chosen = {...parts.where((q) => q.marks == 1), twos.first};
      for (final q in parts.where(chosen.contains)) {
        items.add(_toPaperQuestion(q, section: section.name));
      }
    }
    return items;
  }

  PaperQuestion _toPaperQuestion(Question q, {String? section}) {
    if (q.type != QuestionType.mcq) return PaperQuestion(question: q, options: const [], section: section);
    final order = List.generate(q.options.length, (i) => i)..shuffle(_random);
    return PaperQuestion(
      question: q,
      options: [for (final i in order) q.options[i]],
      answerIndex: order.indexOf(q.answerIndex!),
      section: section,
    );
  }
}
