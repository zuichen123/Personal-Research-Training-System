enum AITutorToolType {
  questionGeneration,
  grading,
  scheduleCreation,
  pomodoro,
}

const int aiTutorContextCompressTokenThreshold = 100000;
const Duration aiTutorContextCompressAgeThreshold = Duration(days: 7);

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
    required this.agentId,
    required this.agentName,
    this.switchedByController = false,
  });

  final AITutorToolType tool;
  final String routeLabel;
  final DateTime triggeredAt;
  final String agentId;
  final String agentName;
  final bool switchedByController;
}

class AITutorScheduleDecision {
  const AITutorScheduleDecision({
    required this.tool,
    required this.assignedAgentId,
    required this.assignedAgentName,
    this.suggestedAgentId,
    this.suggestedAgentName,
    this.reason = '',
    this.autoSwitched = false,
    required this.scheduledAt,
  });

  final AITutorToolType tool;
  final String assignedAgentId;
  final String assignedAgentName;
  final String? suggestedAgentId;
  final String? suggestedAgentName;
  final String reason;
  final bool autoSwitched;
  final DateTime scheduledAt;

  bool get hasSuggestion {
    final suggested = suggestedAgentId;
    return suggested != null &&
        suggested.isNotEmpty &&
        suggested != assignedAgentId;
  }
}

class AITutorAgentContext {
  AITutorAgentContext({
    List<String>? notes,
    List<AIToolCallRecord>? toolCalls,
    List<String>? compressedSummaries,
    DateTime? updatedAt,
    this.tokenEstimate = 0,
    this.compressionCount = 0,
    this.lastCompressedAt,
  }) : notes = notes ?? <String>[],
       toolCalls = toolCalls ?? <AIToolCallRecord>[],
       compressedSummaries = compressedSummaries ?? <String>[],
       updatedAt = updatedAt ?? DateTime.now();

  final List<String> notes;
  final List<AIToolCallRecord> toolCalls;
  final List<String> compressedSummaries;
  DateTime updatedAt;
  int tokenEstimate;
  int compressionCount;
  DateTime? lastCompressedAt;
}
