import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';

/// Read-only view over the tagged question bank.
///
/// For now the bank is a set of bundled JSON files: sample questions written
/// for this app, plus questions from real CBSE board papers. Later the
/// content will be edited through the admin panel.
class QuestionBank {
  QuestionBank(List<Question> questions) : questions = List.unmodifiable(questions);

  static const assetPaths = [
    'assets/question_bank/sample_questions.json',
    'assets/question_bank/cbse_2022_30-1-1.json',
    'assets/question_bank/cbse_2023_30-1-1.json',
    'assets/question_bank/cbse_2024_30-1-1.json',
    'assets/question_bank/cbse_2025_30-1-1.json',
    'assets/question_bank/cbse_2026_30-1-1.json',
    'assets/question_bank/cbse_sst_2022_32-1-1.json',
    'assets/question_bank/cbse_sst_2023_32-1-1.json',
    'assets/question_bank/cbse_sst_2024_32-1-1.json',
    'assets/question_bank/cbse_sst_2025_32-1-1.json',
    'assets/question_bank/cbse_sst_2026_32-1-1.json',
    'assets/question_bank/cbse_science_2022_31-1-1.json',
    'assets/question_bank/cbse_science_2023_31-1-1.json',
    'assets/question_bank/cbse_science_2024_31-1-1.json',
    'assets/question_bank/cbse_science_2025_31-1-1.json',
    'assets/question_bank/cbse_science_2026_31-1-1.json',
    'assets/question_bank/cbse_english_2023_2-1-1.json',
    'assets/question_bank/cbse_english_2024_2-1-1.json',
    'assets/question_bank/cbse_english_2025_2-1-1.json',
    'assets/question_bank/cbse_english_2026_2-1-1.json',
    'assets/question_bank/cbse_hindi_a_2023_3-1-1.json',
    'assets/question_bank/cbse_hindi_a_2024_3-1-1.json',
    'assets/question_bank/cbse_hindi_a_2025_3-1-1.json',
    'assets/question_bank/cbse_hindi_a_2026_3-1-1.json',
    'assets/question_bank/cbse12_maths_2023_65-1-1.json',
    'assets/question_bank/cbse12_maths_2024_65-1-1.json',
    'assets/question_bank/cbse12_maths_2025_65-1-1.json',
    'assets/question_bank/cbse12_maths_2026_65-1-1.json',
    'assets/question_bank/cbse12_physics_2023_55-1-1.json',
    'assets/question_bank/cbse12_physics_2024_55-1-1.json',
    'assets/question_bank/cbse12_physics_2025_55-1-1.json',
    'assets/question_bank/cbse12_physics_2026_55-1-1.json',
    'assets/question_bank/cbse12_chemistry_2025_56-1-1.json',
    'assets/question_bank/cbse12_chemistry_2026_56-1-1.json',
  ];

  /// NCERT chapter order, so chapters are listed as in the textbook.
  static const _syllabusOrderX = {
    'Mathematics': [
      'Real Numbers',
      'Polynomials',
      'Pair of Linear Equations in Two Variables',
      'Quadratic Equations',
      'Arithmetic Progressions',
      'Triangles',
      'Coordinate Geometry',
      'Introduction to Trigonometry',
      'Some Applications of Trigonometry',
      'Circles',
      'Areas Related to Circles',
      'Surface Areas and Volumes',
      'Statistics',
      'Probability',
    ],
    'Science': [
      'Chemical Reactions and Equations',
      'Acids, Bases and Salts',
      'Metals and Non-metals',
      'Carbon and its Compounds',
      'Life Processes',
      'Control and Coordination',
      'How do Organisms Reproduce?',
      'Heredity',
      'Light – Reflection and Refraction',
      'The Human Eye and the Colourful World',
      'Electricity',
      'Magnetic Effects of Electric Current',
      'Our Environment',
    ],
    'Social Science': [
      'History: The Rise of Nationalism in Europe',
      'History: Nationalism in India',
      'History: The Making of a Global World',
      'History: The Age of Industrialisation',
      'History: Print Culture and the Modern World',
      'Geography: Resources and Development',
      'Geography: Forest and Wildlife Resources',
      'Geography: Water Resources',
      'Geography: Agriculture',
      'Geography: Minerals and Energy Resources',
      'Geography: Manufacturing Industries',
      'Geography: Lifelines of National Economy',
      'Political Science: Power Sharing',
      'Political Science: Federalism',
      'Political Science: Gender, Religion and Caste',
      'Political Science: Political Parties',
      'Political Science: Outcomes of Democracy',
      'Economics: Development',
      'Economics: Sectors of the Indian Economy',
      'Economics: Money and Credit',
      'Economics: Globalisation and the Indian Economy',
      'Economics: Consumer Rights',
    ],
  };

  static const _syllabusOrderXII = {
    'Mathematics': [
      'Relations and Functions',
      'Inverse Trigonometric Functions',
      'Matrices',
      'Determinants',
      'Continuity and Differentiability',
      'Application of Derivatives',
      'Integrals',
      'Application of Integrals',
      'Differential Equations',
      'Vector Algebra',
      'Three Dimensional Geometry',
      'Linear Programming',
      'Probability',
    ],
    'Physics': [
      'Electric Charges and Fields',
      'Electrostatic Potential and Capacitance',
      'Current Electricity',
      'Moving Charges and Magnetism',
      'Magnetism and Matter',
      'Electromagnetic Induction',
      'Alternating Current',
      'Electromagnetic Waves',
      'Ray Optics and Optical Instruments',
      'Wave Optics',
      'Dual Nature of Radiation and Matter',
      'Atoms',
      'Nuclei',
      'Semiconductor Electronics',
    ],
    'Chemistry': [
      'Solutions',
      'Electrochemistry',
      'Chemical Kinetics',
      'The d- and f-Block Elements',
      'Coordination Compounds',
      'Haloalkanes and Haloarenes',
      'Alcohols, Phenols and Ethers',
      'Aldehydes, Ketones and Carboxylic Acids',
      'Amines',
      'Biomolecules',
    ],
  };

  final List<Question> questions;

  static Future<QuestionBank> loadFromAssets() async {
    final raws = await Future.wait(assetPaths.map(rootBundle.loadString));
    return QuestionBank.fromJsonStrings(raws);
  }

  factory QuestionBank.fromJsonString(String raw) => QuestionBank.fromJsonStrings([raw]);

  factory QuestionBank.fromJsonStrings(Iterable<String> raws) {
    final questions = <Question>[];
    for (final raw in raws) {
      final list = (jsonDecode(raw) as Map<String, dynamic>)['questions'] as List;
      questions.addAll(list.map((e) => Question.fromJson(e as Map<String, dynamic>)));
    }
    final ids = <String>{};
    for (final q in questions) {
      if (!ids.add(q.id)) throw FormatException('Duplicate question id ${q.id}');
    }
    return QuestionBank(questions);
  }

  List<String> get boards => _sorted(questions.map((q) => q.board));

  List<int> gradesFor(String board) =>
      questions.where((q) => q.board == board).map((q) => q.grade).toSet().toList()..sort();

  List<String> subjectsFor(String board, int grade) =>
      _sorted(questions.where((q) => q.board == board && q.grade == grade).map((q) => q.subject));

  /// Chapters in syllabus order; any not in the known order come last.
  List<String> chaptersFor(String board, int grade, String subject) {
    final order = (grade == 12 ? _syllabusOrderXII : _syllabusOrderX)[subject] ?? const [];
    int rank(String c) {
      final i = order.indexOf(c);
      return i < 0 ? order.length : i;
    }

    return questions
        .where((q) => q.board == board && q.grade == grade && q.subject == subject)
        .map((q) => q.chapter)
        .toSet()
        .toList()
      ..sort((a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : a.compareTo(b));
  }

  /// Whether any past-paper questions exist for this class and subject.
  bool hasPastPapers(String board, int grade, String subject) =>
      questions.any((q) => q.isPastPaper && q.board == board && q.grade == grade && q.subject == subject);

  static List<String> _sorted(Iterable<String> values) => values.toSet().toList()..sort();
}
