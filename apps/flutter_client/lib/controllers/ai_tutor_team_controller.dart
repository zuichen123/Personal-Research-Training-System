import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/ai_tutor_team.dart';

class AITutorTeamController extends ChangeNotifier {
  AITutorTeamController() {
    for (final agent in _agents) {
      _contexts[agent.id] = AITutorAgentContext(
        notes: [agent.mission],
      );
    }
  }

  static const String controllerAgentId = 'controller';

  final List<AITutorAgent> _agents = const [
    AITutorAgent(
      id: controllerAgentId,
      name: 'Controller',
      role: '总控编排',
      subject: '全科',
      mission: '分派工具调用并汇总团队上下文，不直接污染学科 Agent 的独立记忆。',
      isController: true,
    ),
    AITutorAgent(
      id: 'math_agent',
      name: 'Math Agent',
      role: '出题专家',
      subject: '数学',
      mission: '负责数学向题目生成与难度分层策略。',
    ),
    AITutorAgent(
      id: 'review_agent',
      name: 'Review Agent',
      role: '批阅专家',
      subject: '通用批阅',
      mission: '专注作答诊断、题目解析与补救建议。',
    ),
    AITutorAgent(
      id: 'planner_agent',
      name: 'Planner Agent',
      role: '计划专家',
      subject: '学习规划',
      mission: '负责学习计划创建、优化与导入策略。',
    ),
    AITutorAgent(
      id: 'focus_agent',
      name: 'Focus Agent',
      role: '执行专家',
      subject: '专注训练',
      mission: '负责番茄钟节奏、执行反馈与中断恢复。',
    ),
  ];

  final Map<String, AITutorAgentContext> _contexts = <String, AITutorAgentContext>{};

  List<AITutorAgent> get agents => List.unmodifiable(_agents);

  AITutorAgent get controllerAgent =>
      _agents.firstWhere((item) => item.id == controllerAgentId);

  List<AITutorAgent> get subjectAgents => _agents
      .where((item) => !item.isController)
      .toList(growable: false);

  AITutorAgentContext contextOf(String agentId) {
    final context = _contexts[agentId];
    if (context == null) {
      return AITutorAgentContext();
    }
    return AITutorAgentContext(
      notes: List<String>.from(context.notes),
      toolCalls: List<AIToolCallRecord>.from(context.toolCalls),
      updatedAt: context.updatedAt,
    );
  }

  int toolCallCount(String agentId) {
    return _contexts[agentId]?.toolCalls.length ?? 0;
  }

  int get totalToolCalls {
    var total = 0;
    for (final context in _contexts.values) {
      total += context.toolCalls.length;
    }
    return total;
  }

  UnmodifiableListView<AIToolCallRecord> latestControllerRecords({int limit = 8}) {
    final controllerContext = _contexts[controllerAgentId];
    if (controllerContext == null || controllerContext.toolCalls.isEmpty) {
      return UnmodifiableListView(const <AIToolCallRecord>[]);
    }
    final end = controllerContext.toolCalls.length < limit
        ? controllerContext.toolCalls.length
        : limit;
    return UnmodifiableListView(controllerContext.toolCalls.sublist(0, end));
  }

  void recordToolCall({
    required String agentId,
    required AITutorToolType tool,
    required String routeLabel,
  }) {
    final targetContext = _contexts[agentId];
    if (targetContext == null) {
      return;
    }

    final now = DateTime.now();
    final record = AIToolCallRecord(
      tool: tool,
      routeLabel: routeLabel,
      triggeredAt: now,
    );

    targetContext.toolCalls.insert(0, record);
    targetContext.updatedAt = now;
    _appendAgentNote(targetContext, '调用 ${tool.label} -> $routeLabel');

    final controllerContext = _contexts[controllerAgentId];
    final agentName = _agentName(agentId);
    if (controllerContext != null) {
      controllerContext.toolCalls.insert(0, record);
      controllerContext.updatedAt = now;
      _appendAgentNote(controllerContext, '$agentName 分派 ${tool.label}');
    }

    notifyListeners();
  }

  void _appendAgentNote(AITutorAgentContext context, String note) {
    context.notes.insert(0, note);
    const maxNotes = 12;
    if (context.notes.length > maxNotes) {
      context.notes.removeRange(maxNotes, context.notes.length);
    }

    const maxRecords = 20;
    if (context.toolCalls.length > maxRecords) {
      context.toolCalls.removeRange(maxRecords, context.toolCalls.length);
    }
  }

  String _agentName(String agentId) {
    for (final agent in _agents) {
      if (agent.id == agentId) {
        return agent.name;
      }
    }
    return agentId;
  }
}
