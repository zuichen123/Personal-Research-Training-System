class MistakeRecord {
  final String id;
  final String questionId;
  final List<String> userAnswer;
  final String feedback;
  final String reason;
  final DateTime createdAt;

  MistakeRecord({
    required this.id,
    required this.questionId,
    required this.userAnswer,
    required this.feedback,
    required this.reason,
    required this.createdAt,
  });

  factory MistakeRecord.fromJson(Map<String, dynamic> json) {
    return MistakeRecord(
      id: json['id'] ?? '',
      questionId: json['question_id'] ?? '',
      userAnswer: (json['user_answer'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      feedback: json['feedback'] ?? '',
      reason: json['reason'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'user_answer': userAnswer,
      'feedback': feedback,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
