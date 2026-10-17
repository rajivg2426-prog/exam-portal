enum QuestionType { mcq, subjective }

enum Difficulty { normal, tough }

/// One question from the tagged question bank.
///
/// Every question carries the tags papers are built from: board, grade,
/// subject, chapter, type, difficulty and (for real past papers) year.
/// [source] says where it came from, so sample content is never shown as a
/// real past-paper question.
class Question {
  const Question({
    required this.id,
    required this.board,
    required this.grade,
    required this.subject,
    required this.chapter,
    required this.type,
    required this.difficulty,
    required this.marks,
    required this.text,
    required this.solution,
    required this.source,
    this.year,
    this.options = const [],
    this.answerIndex,
  });

  final String id;
  final String board;
  final int grade;
  final String subject;
  final String chapter;
  final QuestionType type;
  final Difficulty difficulty;
  final int marks;
  final String text;
  final String solution;

  /// `sample` for practice content written for this app, `past_paper` for
  /// questions taken from a real board paper (then [year] is set).
  final String source;
  final int? year;

  /// MCQ only.
  final List<String> options;
  final int? answerIndex;

  bool get isSample => source == 'sample';

  factory Question.fromJson(Map<String, dynamic> json) {
    final type = QuestionType.values.byName(json['type'] as String);
    final options = (json['options'] as List?)?.cast<String>() ?? const [];
    final answerIndex = json['answerIndex'] as int?;
    if (type == QuestionType.mcq &&
        (options.length < 2 ||
            answerIndex == null ||
            answerIndex < 0 ||
            answerIndex >= options.length)) {
      throw FormatException('MCQ ${json['id']} needs options and a valid answerIndex');
    }
    return Question(
      id: json['id'] as String,
      board: json['board'] as String,
      grade: json['grade'] as int,
      subject: json['subject'] as String,
      chapter: json['chapter'] as String,
      type: type,
      difficulty: Difficulty.values.byName(json['difficulty'] as String),
      marks: json['marks'] as int,
      text: json['text'] as String,
      solution: json['solution'] as String,
      source: json['source'] as String,
      year: json['year'] as int?,
      options: options,
      answerIndex: answerIndex,
    );
  }
}
