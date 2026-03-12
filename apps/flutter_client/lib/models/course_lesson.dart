class CourseLesson {
  final String id;
  final String date;
  final int period;
  final String subject;
  final String topic;
  final String classroom;
  final String startTime;
  final String endTime;

  CourseLesson({
    required this.id,
    required this.date,
    required this.period,
    required this.subject,
    required this.topic,
    required this.classroom,
    required this.startTime,
    required this.endTime,
  });

  factory CourseLesson.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw FormatException('CourseLesson requires non-empty id');
    }
    return CourseLesson(
      id: id,
      date: json['date']?.toString() ?? '',
      period: (json['period'] as num?)?.toInt() ?? 1,
      subject: json['subject']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      classroom: json['classroom']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
    );
  }
}
