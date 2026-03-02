class Option {
  final String key;
  final String text;
  final int score;

  Option({
    required this.key,
    required this.text,
    this.score = 0,
  });

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(
      key: json['key'] ?? '',
      text: json['text'] ?? '',
      score: json['score'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'text': text,
      'score': score,
    };
  }
}

class Question {
  final String id;
  final String title;
  final String stem;
  final String type; // single_choice, multi_choice, short_answer
  final List<Option> options;
  final List<String> answerKey;
  final List<String> tags;
  final int difficulty;
  final DateTime createdAt;
  final DateTime updatedAt;

  Question({
    required this.id,
    required this.title,
    required this.stem,
    required this.type,
    required this.options,
    required this.answerKey,
    required this.tags,
    required this.difficulty,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      stem: json['stem'] ?? '',
      type: json['type'] ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => Option.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      answerKey: (json['answer_key'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      difficulty: json['difficulty'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'stem': stem,
      'type': type,
      'options': options.map((e) => e.toJson()).toList(),
      'answer_key': answerKey,
      'tags': tags,
      'difficulty': difficulty,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
