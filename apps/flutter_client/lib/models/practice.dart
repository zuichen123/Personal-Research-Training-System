class PracticeAttempt {
  final String id;
  final String questionId;
  final List<String> userAnswer;
  final double score;
  final bool correct;
  final String feedback;
  final DateTime submittedAt;

  PracticeAttempt({
    required this.id,
    required this.questionId,
    required this.userAnswer,
    required this.score,
    required this.correct,
    required this.feedback,
    required this.submittedAt,
  });

  factory PracticeAttempt.fromJson(Map<String, dynamic> json) {
    return PracticeAttempt(
      id: json['id'] ?? '',
      questionId: json['question_id'] ?? '',
      userAnswer:
          (json['user_answer'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      correct: json['correct'] ?? false,
      feedback: json['feedback'] ?? '',
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'user_answer': userAnswer,
      'score': score,
      'correct': correct,
      'feedback': feedback,
      'submitted_at': submittedAt.toIso8601String(),
    };
  }
}
