class MistakeRecord {
  final String id;
  final String questionId;
  final String subject;
  final int difficulty;
  final int masteryLevel;
  final List<String> userAnswer;
  final String feedback;
  final String reason;
  final DateTime createdAt;

  MistakeRecord({
    required this.id,
    required this.questionId,
    required this.subject,
    required this.difficulty,
    required this.masteryLevel,
    required this.userAnswer,
    required this.feedback,
    required this.reason,
    required this.createdAt,
  });

  factory MistakeRecord.fromJson(Map<String, dynamic> json) {
    return MistakeRecord(
      id: json['id']?.toString() ?? '',
      questionId: json['question_id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'general',
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      masteryLevel: (json['mastery_level'] as num?)?.toInt() ?? 0,
      userAnswer:
          (json['user_answer'] as List<dynamic>?)?.map((e) => '$e').toList() ??
          [],
      feedback: json['feedback']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'subject': subject,
      'difficulty': difficulty,
      'mastery_level': masteryLevel,
      'user_answer': userAnswer,
      'feedback': feedback,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
