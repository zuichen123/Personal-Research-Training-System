class UserProfile {
  final String userId;
  final String nickname;
  final int age;
  final String academicStatus;
  final List<String> goals;
  final String goalTargetDate;
  final int dailyStudyMinutes;
  final List<String> weakSubjects;
  final String targetDestination;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.userId,
    required this.nickname,
    required this.age,
    required this.academicStatus,
    required this.goals,
    required this.goalTargetDate,
    required this.dailyStudyMinutes,
    required this.weakSubjects,
    required this.targetDestination,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id']?.toString() ?? 'default',
      nickname: json['nickname']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      academicStatus: json['academic_status']?.toString() ?? '',
      goals: (json['goals'] as List<dynamic>?)?.map((e) => '$e').toList() ?? [],
      goalTargetDate: json['goal_target_date']?.toString() ?? '',
      dailyStudyMinutes: (json['daily_study_minutes'] as num?)?.toInt() ?? 0,
      weakSubjects:
          (json['weak_subjects'] as List<dynamic>?)
              ?.map((e) => '$e')
              .toList() ??
          [],
      targetDestination: json['target_destination']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
