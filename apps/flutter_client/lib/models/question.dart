class QuestionOption {
  final String key;
  final String text;
  final int score;

  QuestionOption({required this.key, required this.text, this.score = 0});

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      key: json['key']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'key': key, 'text': text, 'score': score};
  }
}

class Question {
  final String id;
  final String title;
  final String stem;
  final String type;
  final String subject;
  final String source;
  final List<QuestionOption> options;
  final List<String> answerKey;
  final List<String> tags;
  final int difficulty;
  final int masteryLevel;
  final DateTime createdAt;
  final DateTime updatedAt;

  Question({
    required this.id,
    required this.title,
    required this.stem,
    required this.type,
    required this.subject,
    required this.source,
    required this.options,
    required this.answerKey,
    required this.tags,
    required this.difficulty,
    required this.masteryLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      stem: json['stem']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'general',
      source: json['source']?.toString() ?? 'unit_test',
      options:
          (json['options'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(QuestionOption.fromJson)
              .toList() ??
          [],
      answerKey:
          (json['answer_key'] as List<dynamic>?)?.map((e) => '$e').toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)?.map((e) => '$e').toList() ?? [],
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 0,
      masteryLevel: (json['mastery_level'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'stem': stem,
      'type': type,
      'subject': subject,
      'source': source,
      'options': options.map((e) => e.toJson()).toList(),
      'answer_key': answerKey,
      'tags': tags,
      'difficulty': difficulty,
      'mastery_level': masteryLevel,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
