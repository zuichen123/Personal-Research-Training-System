enum AITutorToolType {
  questionGeneration,
  grading,
  scheduleCreation,
  pomodoro,
}

extension AITutorToolTypeX on AITutorToolType {
  String get label {
    switch (this) {
      case AITutorToolType.questionGeneration:
        return '题目生成';
      case AITutorToolType.grading:
        return 'AI批阅';
      case AITutorToolType.scheduleCreation:
        return '计划创建';
      case AITutorToolType.pomodoro:
        return '番茄钟';
    }
  }

  String get description {
    switch (this) {
      case AITutorToolType.questionGeneration:
        return '根据主题与难度生成练习题';
      case AITutorToolType.grading:
        return '结合答案与附件进行作答批阅';
      case AITutorToolType.scheduleCreation:
        return '生成并管理学习计划';
      case AITutorToolType.pomodoro:
        return '进入专注计时并跟踪执行';
    }
  }
}

class AITutorAgent {
  const AITutorAgent({
    required this.id,
    required this.name,
    required this.role,
    required this.subject,
    required this.mission,
    this.isController = false,
  });

  final String id;
  final String name;
  final String role;
  final String subject;
  final String mission;
  final bool isController;
}

class AIToolCallRecord {
  const AIToolCallRecord({
    required this.tool,
    required this.routeLabel,
    required this.triggeredAt,
  });

  final AITutorToolType tool;
  final String routeLabel;
  final DateTime triggeredAt;
}

class AITutorAgentContext {
  AITutorAgentContext({
    List<String>? notes,
    List<AIToolCallRecord>? toolCalls,
    DateTime? updatedAt,
  }) : notes = notes ?? <String>[],
       toolCalls = toolCalls ?? <AIToolCallRecord>[],
       updatedAt = updatedAt ?? DateTime.now();

  final List<String> notes;
  final List<AIToolCallRecord> toolCalls;
  DateTime updatedAt;
}
