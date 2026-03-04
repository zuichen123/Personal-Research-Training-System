import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/ai_tutor_team.dart';

class AITutorTeamController extends ChangeNotifier {
  AITutorTeamController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    for (final agent in _agents) {
      _contexts[agent.id] = AITutorAgentContext(
        notes: [agent.mission],
        tokenEstimate: _seedTokenEstimate(agent),
      );
    }
    _refreshScheduleHints();
  }

  static const String controllerAgentId = 'controller';
  static const int _noteLimit = 12;
  static const int _recordLimit = 24;
  static const int _compressedSummaryLimit = 6;

  final DateTime Function() _clock;

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

  final Map<AITutorToolType, String> _toolOwners = const {
    AITutorToolType.questionGeneration: 'math_agent',
    AITutorToolType.grading: 'review_agent',
    AITutorToolType.scheduleCreation: 'planner_agent',
    AITutorToolType.pomodoro: 'focus_agent',
  };

  final Map<String, AITutorAgentContext> _contexts =
      <String, AITutorAgentContext>{};
  final List<AITutorScheduleDecision> _scheduleDecisions =
      <AITutorScheduleDecision>[];
  final Map<AITutorToolType, AITutorScheduleDecision> _scheduleHints =
      <AITutorToolType, AITutorScheduleDecision>{};

  List<AITutorAgent> get agents => List.unmodifiable(_agents);

  AITutorAgent get controllerAgent =>
      _agents.firstWhere((item) => item.id == controllerAgentId);

  List<AITutorAgent> get subjectAgents =>
      _agents.where((item) => !item.isController).toList(growable: false);

  AITutorAgentContext contextOf(String agentId) {
    final context = _contexts[agentId];
    if (context == null) {
      return AITutorAgentContext();
    }
    return AITutorAgentContext(
      notes: List<String>.from(context.notes),
      toolCalls: List<AIToolCallRecord>.from(context.toolCalls),
      compressedSummaries: List<String>.from(context.compressedSummaries),
      updatedAt: context.updatedAt,
      tokenEstimate: context.tokenEstimate,
      compressionCount: context.compressionCount,
      lastCompressedAt: context.lastCompressedAt,
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

  UnmodifiableListView<AITutorScheduleDecision> latestScheduleDecisions({
    int limit = 8,
  }) {
    final end = _scheduleDecisions.length < limit
        ? _scheduleDecisions.length
        : limit;
    return UnmodifiableListView(_scheduleDecisions.sublist(0, end));
  }

  AITutorScheduleDecision scheduleHint({
    required AITutorToolType tool,
    required String defaultAgentId,
  }) {
    final hint = _scheduleHints[tool];
    if (hint != null) {
      return hint;
    }
    return _planSchedule(
      tool: tool,
      defaultAgentId: defaultAgentId,
      allowAutoSwitch: false,
    );
  }

  UnmodifiableListView<AIToolCallRecord> latestControllerRecords({
    int limit = 8,
  }) {
    final controllerContext = _contexts[controllerAgentId];
    if (controllerContext == null || controllerContext.toolCalls.isEmpty) {
      return UnmodifiableListView(const <AIToolCallRecord>[]);
    }
    final end = controllerContext.toolCalls.length < limit
        ? controllerContext.toolCalls.length
        : limit;
    return UnmodifiableListView(controllerContext.toolCalls.sublist(0, end));
  }

  AITutorScheduleDecision dispatchToolCall({
    required AITutorToolType tool,
    required String defaultAgentId,
    required String routeLabel,
  }) {
    final decision = _planSchedule(
      tool: tool,
      defaultAgentId: defaultAgentId,
      allowAutoSwitch: true,
    );
    _recordToolCall(
      agentId: decision.assignedAgentId,
      tool: tool,
      routeLabel: routeLabel,
      switchedByController: decision.autoSwitched,
      scheduleReason: decision.reason,
      notify: false,
    );
    _scheduleDecisions.insert(0, decision);
    _trimScheduleDecisions();
    _refreshScheduleHints();
    notifyListeners();
    return decision;
  }

  void recordToolCall({
    required String agentId,
    required AITutorToolType tool,
    required String routeLabel,
  }) {
    _recordToolCall(
      agentId: agentId,
      tool: tool,
      routeLabel: routeLabel,
      switchedByController: false,
      scheduleReason: '',
      notify: true,
    );
  }

  int contextTokenEstimate(String agentId) {
    return _contexts[agentId]?.tokenEstimate ?? 0;
  }

  @visibleForTesting
  void debugSetContextState({
    required String agentId,
    int? tokenEstimate,
    DateTime? updatedAt,
    DateTime? lastCompressedAt,
    int? compressionCount,
  }) {
    final context = _contexts[agentId];
    if (context == null) {
      return;
    }
    if (tokenEstimate != null) {
      context.tokenEstimate = tokenEstimate;
    }
    if (updatedAt != null) {
      context.updatedAt = updatedAt;
    }
    if (lastCompressedAt != null) {
      context.lastCompressedAt = lastCompressedAt;
    }
    if (compressionCount != null) {
      context.compressionCount = compressionCount;
    }
    _refreshScheduleHints();
  }

  void _recordToolCall({
    required String agentId,
    required AITutorToolType tool,
    required String routeLabel,
    required bool switchedByController,
    required String scheduleReason,
    required bool notify,
  }) {
    final targetContext = _contexts[agentId];
    final controllerContext = _contexts[controllerAgentId];
    if (targetContext == null || controllerContext == null) {
      return;
    }

    final now = _clock();
    _compressContextIfNeeded(targetContext, now);
    _compressContextIfNeeded(controllerContext, now);

    final agentName = _agentName(agentId);
    final record = AIToolCallRecord(
      tool: tool,
      routeLabel: routeLabel,
      triggeredAt: now,
      agentId: agentId,
      agentName: agentName,
      switchedByController: switchedByController,
    );

    targetContext.toolCalls.insert(0, record);
    targetContext.updatedAt = now;
    targetContext.tokenEstimate += _estimateRuntimeTokenCost(
      tool: tool,
      routeLabel: routeLabel,
      scheduleReason: scheduleReason,
    );
    _appendAgentNote(
      targetContext,
      switchedByController
          ? 'Controller切换后调用 ${tool.label} -> $routeLabel'
          : '调用 ${tool.label} -> $routeLabel',
    );
    _compressContextIfNeeded(targetContext, now);

    controllerContext.toolCalls.insert(0, record);
    controllerContext.updatedAt = now;
    controllerContext.tokenEstimate += _estimateRuntimeTokenCost(
      tool: tool,
      routeLabel: routeLabel,
      scheduleReason: scheduleReason,
    );
    _appendAgentNote(
      controllerContext,
      '$agentName 分派 ${tool.label}${scheduleReason.isEmpty ? '' : ' ($scheduleReason)'}',
    );
    _compressContextIfNeeded(controllerContext, now);

    _refreshScheduleHints();
    if (notify) {
      notifyListeners();
    }
  }

  void _appendAgentNote(AITutorAgentContext context, String note) {
    context.notes.insert(0, note);
    if (context.notes.length > _noteLimit) {
      context.notes.removeRange(_noteLimit, context.notes.length);
    }

    if (context.toolCalls.length > _recordLimit) {
      context.toolCalls.removeRange(_recordLimit, context.toolCalls.length);
    }
  }

  AITutorScheduleDecision _planSchedule({
    required AITutorToolType tool,
    required String defaultAgentId,
    required bool allowAutoSwitch,
  }) {
    final now = _clock();
    final ownerAgentID = _toolOwners[tool] ?? defaultAgentId;
    final ownerAgent = _agentByID(ownerAgentID);
    final fallbackAgent = _agentByID(defaultAgentId);
    final preferred = ownerAgent ?? fallbackAgent ?? subjectAgents.first;

    final ranked = _rankAgents(preferredAgentID: preferred.id, now: now);
    final best = ranked.first;
    final preferredScore = ranked.firstWhere(
      (item) => item.agent.id == preferred.id,
      orElse: () => _ScoredAgent(agent: preferred, score: -999, reason: ''),
    );

    final canSuggest =
        best.agent.id != preferred.id && best.score >= preferredScore.score + 2;
    final autoSwitch =
        canSuggest && allowAutoSwitch && best.score >= preferredScore.score + 4;
    final assigned = autoSwitch ? best.agent : preferred;
    final reason = _buildScheduleReason(
      preferred: preferred,
      best: best,
      preferredScore: preferredScore.score,
      canSuggest: canSuggest,
      autoSwitch: autoSwitch,
    );

    return AITutorScheduleDecision(
      tool: tool,
      assignedAgentId: assigned.id,
      assignedAgentName: assigned.name,
      suggestedAgentId: canSuggest ? best.agent.id : null,
      suggestedAgentName: canSuggest ? best.agent.name : null,
      reason: reason,
      autoSwitched: autoSwitch,
      scheduledAt: now,
    );
  }

  List<_ScoredAgent> _rankAgents({
    required String preferredAgentID,
    required DateTime now,
  }) {
    final ranked = <_ScoredAgent>[];
    for (final agent in subjectAgents) {
      final context = _contexts[agent.id];
      if (context == null) {
        continue;
      }
      var score = 0;
      final reasons = <String>[];

      if (agent.id == preferredAgentID) {
        score += 4;
        reasons.add('owner');
      }

      final idleHours = now.difference(context.updatedAt).inHours;
      if (idleHours <= 24) {
        score += 2;
        reasons.add('fresh');
      } else if (idleHours <= 72) {
        score += 1;
        reasons.add('warm');
      } else {
        score -= 1;
        reasons.add('stale');
      }

      final load = context.toolCalls.length;
      if (load <= 4) {
        score += 2;
        reasons.add('low_load');
      } else if (load <= 10) {
        score += 1;
        reasons.add('mid_load');
      } else if (load > 14) {
        score -= 1;
        reasons.add('high_load');
      }

      if (context.tokenEstimate >= aiTutorContextCompressTokenThreshold) {
        score -= 2;
        reasons.add('token_pressure');
      } else if (context.tokenEstimate < 30000) {
        score += 1;
        reasons.add('light_context');
      }

      ranked.add(
        _ScoredAgent(agent: agent, score: score, reason: reasons.join('+')),
      );
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));
    return ranked;
  }

  String _buildScheduleReason({
    required AITutorAgent preferred,
    required _ScoredAgent best,
    required int preferredScore,
    required bool canSuggest,
    required bool autoSwitch,
  }) {
    if (!canSuggest) {
      return '保持默认分工';
    }
    final delta = best.score - preferredScore;
    final prefix = autoSwitch ? '自动切换' : '建议切换';
    return '$prefix: ${preferred.name} -> ${best.agent.name} (score+$delta, ${best.reason})';
  }

  void _compressContextIfNeeded(AITutorAgentContext context, DateTime now) {
    final referenceTime = context.lastCompressedAt ?? context.updatedAt;
    final overToken =
        context.tokenEstimate > aiTutorContextCompressTokenThreshold;
    final overAge =
        now.difference(referenceTime) > aiTutorContextCompressAgeThreshold;
    if (!overToken && !overAge) {
      return;
    }
    if (context.notes.isEmpty &&
        context.toolCalls.isEmpty &&
        context.tokenEstimate <= 0) {
      context.lastCompressedAt = now;
      return;
    }

    final reason = overToken
        ? 'token>$aiTutorContextCompressTokenThreshold'
        : 'age>${aiTutorContextCompressAgeThreshold.inDays}d';
    final snapshotBefore = context.tokenEstimate;
    final summary = _buildCompressionSummary(
      noteCount: context.notes.length,
      callCount: context.toolCalls.length,
      beforeTokens: snapshotBefore,
      reason: reason,
      now: now,
    );

    context.compressedSummaries.insert(0, summary);
    if (context.compressedSummaries.length > _compressedSummaryLimit) {
      context.compressedSummaries.removeRange(
        _compressedSummaryLimit,
        context.compressedSummaries.length,
      );
    }

    final preservedNotes = context.notes.take(3).toList(growable: false);
    context.notes
      ..clear()
      ..add(summary)
      ..addAll(preservedNotes);

    const keepRecords = 8;
    if (context.toolCalls.length > keepRecords) {
      context.toolCalls.removeRange(keepRecords, context.toolCalls.length);
    }

    var reduced = snapshotBefore ~/ 4;
    if (reduced < 6000) {
      reduced = 6000;
    }
    if (reduced > 90000) {
      reduced = 90000;
    }
    context.tokenEstimate = reduced + context.toolCalls.length * 240;
    context.compressionCount += 1;
    context.lastCompressedAt = now;
  }

  String _buildCompressionSummary({
    required int noteCount,
    required int callCount,
    required int beforeTokens,
    required String reason,
    required DateTime now,
  }) {
    final stamp = _formatDate(now);
    return '[compressed $stamp] $reason notes=$noteCount calls=$callCount tokens=$beforeTokens';
  }

  int _seedTokenEstimate(AITutorAgent agent) {
    return (agent.mission.length * 4).clamp(200, 4000).toInt();
  }

  int _estimateRuntimeTokenCost({
    required AITutorToolType tool,
    required String routeLabel,
    required String scheduleReason,
  }) {
    final estimate =
        220 +
        tool.label.length * 10 +
        routeLabel.length * 8 +
        scheduleReason.length * 6;
    return estimate.clamp(120, 2500).toInt();
  }

  void _refreshScheduleHints() {
    for (final entry in _toolOwners.entries) {
      _scheduleHints[entry.key] = _planSchedule(
        tool: entry.key,
        defaultAgentId: entry.value,
        allowAutoSwitch: false,
      );
    }
  }

  void _trimScheduleDecisions() {
    const limit = 20;
    if (_scheduleDecisions.length > limit) {
      _scheduleDecisions.removeRange(limit, _scheduleDecisions.length);
    }
  }

  AITutorAgent? _agentByID(String agentId) {
    for (final agent in _agents) {
      if (agent.id == agentId) {
        return agent;
      }
    }
    return null;
  }

  String _agentName(String agentId) {
    for (final agent in _agents) {
      if (agent.id == agentId) {
        return agent.name;
      }
    }
    return agentId;
  }

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _ScoredAgent {
  const _ScoredAgent({
    required this.agent,
    required this.score,
    required this.reason,
  });

  final AITutorAgent agent;
  final int score;
  final String reason;
}
