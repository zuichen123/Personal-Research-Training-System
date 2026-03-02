class PomodoroSession {
  final String id;
  final String taskTitle;
  final String planId;
  final int durationMinutes;
  final int breakMinutes;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;

  PomodoroSession({
    required this.id,
    required this.taskTitle,
    required this.planId,
    required this.durationMinutes,
    required this.breakMinutes,
    required this.status,
    required this.startedAt,
    required this.endedAt,
  });

  factory PomodoroSession.fromJson(Map<String, dynamic> json) {
    return PomodoroSession(
      id: json['id']?.toString() ?? '',
      taskTitle: json['task_title']?.toString() ?? '',
      planId: json['plan_id']?.toString() ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 25,
      breakMinutes: (json['break_minutes'] as num?)?.toInt() ?? 5,
      status: json['status']?.toString() ?? 'running',
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
    );
  }
}
