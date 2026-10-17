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
  const BoardSection(
    this.name,
    this.title,
    this.count,
    this.marks, {
    this.mcq = false,
    this.caseStudy = false,
    this.partMarks = const [],
    this.tag,
  });

  final String name;
  final String title;
  final int count;

  /// Marks per question (per case study for section E).
  final int marks;
  final bool mcq;
  final bool caseStudy;

  /// For a section made of tagged parts (such as map work): the marks of each
  /// part, one question per entry, taken only from questions tagged with this
  /// section.
  final List<int> partMarks;

  /// When set, this section takes [count] questions of [marks] each from
  /// questions whose `boardSection` equals this tag (for example English
  /// 'reading' passages or 'letter' writing tasks), of any question type.
  final String? tag;

  int get totalMarks => partMarks.isNotEmpty ? partMarks.fold(0, (a, b) => a + b) : count * marks;
}

/// CBSE Class X board paper layouts (2023 onwards), by subject.
const _boardLayouts = {
  'Mathematics': [
    BoardSection('A', 'Multiple choice and assertion-reason', 20, 1, mcq: true),
    BoardSection('B', 'Very short answer', 5, 2),
    BoardSection('C', 'Short answer', 6, 3),
    BoardSection('D', 'Long answer', 4, 5),
    BoardSection('E', 'Case studies', 3, 4, caseStudy: true),
  ],
  'Social Science': [
    BoardSection('A', 'Multiple choice', 20, 1, mcq: true),
    BoardSection('B', 'Very short answer', 4, 2),
    BoardSection('C', 'Short answer', 5, 3),
    BoardSection('D', 'Long answer', 4, 5),
    BoardSection('E', 'Case/source-based', 3, 4, caseStudy: true),
    BoardSection('F', 'Map skills (text version)', 1, 5, partMarks: [2, 3]),
  ],
  'English': [
    BoardSection('A', 'Reading', 2, 10, tag: 'reading'),
    BoardSection('B', 'Grammar', 10, 1, tag: 'grammar'),
    BoardSection('C', 'Writing', 1, 5, tag: 'letter'),
    BoardSection('C', 'Writing', 1, 5, tag: 'paragraph'),
    BoardSection('D', 'Literature', 1, 5, tag: 'extract-prose'),
    BoardSection('D', 'Literature', 1, 5, tag: 'extract-poetry'),
    BoardSection('D', 'Literature', 4, 3, tag: 'lit-short'),
    BoardSection('D', 'Literature', 2, 3, tag: 'supp-short'),
    BoardSection('D', 'Literature', 1, 6, tag: 'lit-long'),
    BoardSection('D', 'Literature', 1, 6, tag: 'supp-long'),
  ],
  'Hindi A': [
    BoardSection('क', 'अपठित बोध', 2, 7, tag: 'reading'),
    BoardSection('ख', 'व्यावहारिक व्याकरण', 16, 1, tag: 'grammar'),
    BoardSection('ग', 'पाठ्य-पुस्तक एवं पूरक पाठ्य-पुस्तक', 1, 5, tag: 'extract-prose'),
    BoardSection('ग', 'पाठ्य-पुस्तक एवं पूरक पाठ्य-पुस्तक', 3, 2, tag: 'lit-short'),
    BoardSection('ग', 'पाठ्य-पुस्तक एवं पूरक पाठ्य-पुस्तक', 1, 5, tag: 'extract-poetry'),
    BoardSection('ग', 'पाठ्य-पुस्तक एवं पूरक पाठ्य-पुस्तक', 3, 2, tag: 'poem-short'),
    BoardSection('ग', 'पाठ्य-पुस्तक एवं पूरक पाठ्य-पुस्तक', 2, 4, tag: 'supp-long'),
    BoardSection('घ', 'रचनात्मक लेखन', 1, 6, tag: 'paragraph'),
    BoardSection('घ', 'रचनात्मक लेखन', 1, 5, tag: 'letter'),
    BoardSection('घ', 'रचनात्मक लेखन', 1, 5, tag: 'format'),
    BoardSection('घ', 'रचनात्मक लेखन', 1, 4, tag: 'message'),
  ],
  'Science': [
    BoardSection('A', 'Multiple choice and assertion-reason', 20, 1, mcq: true),
    BoardSection('B', 'Very short answer', 6, 2),
    BoardSection('C', 'Short answer', 7, 3),
    BoardSection('D', 'Long answer', 3, 5),
    BoardSection('E', 'Case studies', 3, 4, caseStudy: true),
  ],
};

/// CBSE Class XII board paper layouts (2024 onwards), by subject.
const _boardLayoutsXII = {
  'Mathematics': [
    BoardSection('A', 'Multiple choice and assertion-reason', 20, 1, mcq: true),
    BoardSection('B', 'Very short answer', 5, 2),
    BoardSection('C', 'Short answer', 6, 3),
    BoardSection('D', 'Long answer', 4, 5),
    BoardSection('E', 'Case studies', 3, 4, caseStudy: true),
  ],
  'Physics': _scienceXII,
  'Chemistry': _scienceXII,
  'Biology': _scienceXII,
  'English Core': [
    BoardSection('A', 'Reading', 1, 12, tag: 'reading'),
    BoardSection('A', 'Reading', 1, 10, tag: 'case'),
    BoardSection('B', 'Creative writing', 1, 4, tag: 'notice'),
    BoardSection('B', 'Creative writing', 1, 4, tag: 'invitation'),
    BoardSection('B', 'Creative writing', 1, 5, tag: 'letter'),
    BoardSection('B', 'Creative writing', 1, 5, tag: 'article'),
    BoardSection('C', 'Literature', 1, 6, tag: 'extract-poetry'),
    BoardSection('C', 'Literature', 1, 4, tag: 'extract-vistas'),
    BoardSection('C', 'Literature', 1, 6, tag: 'extract-prose'),
    BoardSection('C', 'Literature', 5, 2, tag: 'lit-short'),
    BoardSection('C', 'Literature', 2, 2, tag: 'supp-short'),
    BoardSection('C', 'Literature', 1, 5, tag: 'lit-long'),
    BoardSection('C', 'Literature', 1, 5, tag: 'supp-long'),
  ],
};

/// Physics, Chemistry and Biology: 70 marks.
const _scienceXII = [
  BoardSection('A', 'Multiple choice and assertion-reason', 16, 1, mcq: true),
  BoardSection('B', 'Very short answer', 5, 2),
  BoardSection('C', 'Short answer', 7, 3),
  BoardSection('D', 'Case studies', 2, 4, caseStudy: true),
  BoardSection('E', 'Long answer', 3, 5),
];

/// The board layout for [subject] in Class [grade]; subjects without their
/// own layout use that class's Mathematics one.
List<BoardSection> boardSectionsFor(int grade, String subject) {
  final layouts = grade == 12 ? _boardLayoutsXII : _boardLayouts;
  return layouts[subject] ?? layouts['Mathematics']!;
}

/// Total marks of a full board-pattern paper in [subject] for Class [grade].
int boardMarksFor(int grade, String subject) => boardSectionsFor(grade, subject).fold(0, (n, s) => n + s.totalMarks);

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

  /// Marks a full paper with these settings aims for.
  int get targetMarks => isBoardPattern ? boardMarksFor(grade, subject) : duration.targetMarks;

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
  bool get isShort => totalMarks < config.targetMarks;

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

    for (final section in boardSectionsFor(config.grade, config.subject)) {
      if (section.caseStudy) {
        items.addAll(_pickCaseStudies(matching, section, config.difficulty));
        continue;
      }
      if (section.tag != null) {
        var count = 0;
        for (final q in _ordered(
          matching.where((q) => q.boardSection == section.tag && q.marks == section.marks),
          config.difficulty,
        )) {
          if (count == section.count) break;
          // Tagged sections hold separate tasks (e.g. 'answer any three of four'), so
          // they are not de-duplicated by question number.

          items.add(_toPaperQuestion(q, section: section.name));
          count++;
        }
        continue;
      }
      if (section.partMarks.isNotEmpty) {
        for (final m in section.partMarks) {
          final part = _ordered(
            matching.where((q) => q.boardSection == section.name && q.marks == m),
            config.difficulty,
          );
          if (part.isNotEmpty) items.add(_toPaperQuestion(part.first, section: section.name));
        }
        continue;
      }
      final candidates = matching.where(
        (q) =>
            q.caseStudy == null &&
            q.boardSection == null &&
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

  /// Picks whole case studies worth [BoardSection.marks] each: one question
  /// from every part (one side of each OR choice), in their original order.
  List<PaperQuestion> _pickCaseStudies(List<Question> matching, BoardSection section, Difficulty difficulty) {
    final groups = <String, List<Question>>{};
    for (final q in matching.where((q) => q.caseStudy != null)) {
      groups.putIfAbsent(q.caseStudy!, () => []).add(q);
    }

    // One question from each part. The sides of an OR choice share a part:
    // they are numbered like 36(iii)(a) and 36(iii)(b), or 37(c) and 37(c) OR.
    List<Question> pickParts(List<Question> parts) {
      final byPart = <String, List<Question>>{};
      for (final q in parts) {
        final part = (q.number ?? q.id)
            .replaceFirst(RegExp(r'\s*OR$'), '')
            .replaceFirstMapped(RegExp(r'(\([^)]+\))\([^)]+\)$'), (m) => m[1]!);
        byPart.putIfAbsent(part, () => []).add(q);
      }
      final chosen = {for (final options in byPart.values) _ordered(options, difficulty).first};
      return parts.where(chosen.contains).toList();
    }

    final picks = {for (final g in groups.entries) g.key: pickParts(g.value)};
    final complete =
        picks.entries.where((g) => g.value.fold(0, (n, q) => n + q.marks) == section.marks).map((g) => g.key).toList()
          ..shuffle(_random);
    // Unseen case studies first.
    complete.sort((a, b) {
      bool seen(String g) => groups[g]!.any((q) => seenIds.contains(q.id));
      return (seen(a) ? 1 : 0).compareTo(seen(b) ? 1 : 0);
    });

    return [
      for (final g in complete.take(section.count))
        for (final q in picks[g]!) _toPaperQuestion(q, section: section.name),
    ];
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
