import 'package:flutter_test/flutter_test.dart';

import 'package:prts_client/controllers/ai_tutor_team_controller.dart';
import 'package:prts_client/models/ai_tutor_team.dart';

void main() {
  group('AITutorTeamController', () {
    test('dispatches tool call and records into isolated contexts', () {
      DateTime now = DateTime(2026, 3, 1, 10, 0, 0);
      final controller = AITutorTeamController(clock: () => now);

      final decision = controller.dispatchToolCall(
        tool: AITutorToolType.questionGeneration,
        defaultAgentId: 'math_agent',
        routeLabel: 'AI 出题工作台',
      );

      expect(decision.assignedAgentId, 'math_agent');

      final mathContext = controller.contextOf('math_agent');
      final reviewContext = controller.contextOf('review_agent');
      final ctrlContext = controller.contextOf(
        AITutorTeamController.controllerAgentId,
      );

      expect(mathContext.toolCalls.length, 1);
      expect(mathContext.toolCalls.first.agentId, 'math_agent');
      expect(reviewContext.toolCalls, isEmpty);
      expect(ctrlContext.toolCalls.length, 1);
      expect(ctrlContext.toolCalls.first.agentId, 'math_agent');
    });

    test('gives switch suggestion when preferred agent context is stale', () {
      DateTime now = DateTime(2026, 3, 1, 10, 0, 0);
      final controller = AITutorTeamController(clock: () => now);

      controller.debugSetContextState(
        agentId: 'review_agent',
        tokenEstimate: 120000,
        updatedAt: now.subtract(const Duration(days: 10)),
      );
      controller.debugSetContextState(
        agentId: 'planner_agent',
        tokenEstimate: 95000,
        updatedAt: now.subtract(const Duration(days: 9)),
      );
      controller.debugSetContextState(
        agentId: 'focus_agent',
        tokenEstimate: 95000,
        updatedAt: now.subtract(const Duration(days: 9)),
      );
      controller.debugSetContextState(
        agentId: 'math_agent',
        tokenEstimate: 5000,
        updatedAt: now.subtract(const Duration(hours: 1)),
      );

      final hint = controller.scheduleHint(
        tool: AITutorToolType.grading,
        defaultAgentId: 'review_agent',
      );

      expect(hint.hasSuggestion, isTrue);
      expect(hint.suggestedAgentId, 'math_agent');
      expect(hint.reason, contains('建议切换'));
    });

    test('keeps contexts independent between subject agents', () {
      final controller = AITutorTeamController();

      controller.recordToolCall(
        agentId: 'planner_agent',
        tool: AITutorToolType.scheduleCreation,
        routeLabel: '计划管理页',
      );

      final plannerContext = controller.contextOf('planner_agent');
      final focusContext = controller.contextOf('focus_agent');

      expect(plannerContext.toolCalls.length, 1);
      expect(focusContext.toolCalls, isEmpty);
    });

    test('auto compresses when token estimate is over 100k', () {
      DateTime now = DateTime(2026, 3, 1, 10, 0, 0);
      final controller = AITutorTeamController(clock: () => now);

      controller.debugSetContextState(
        agentId: 'math_agent',
        tokenEstimate: aiTutorContextCompressTokenThreshold + 500,
      );

      controller.recordToolCall(
        agentId: 'math_agent',
        tool: AITutorToolType.questionGeneration,
        routeLabel: 'AI 出题工作台',
      );

      final context = controller.contextOf('math_agent');
      expect(context.compressionCount, greaterThan(0));
      expect(context.lastCompressedAt, isNotNull);
      expect(context.tokenEstimate, lessThan(aiTutorContextCompressTokenThreshold));
      expect(context.compressedSummaries.first, contains('token>'));
    });

    test('auto compresses when context age is over 7 days', () {
      DateTime now = DateTime(2026, 3, 1, 10, 0, 0);
      final controller = AITutorTeamController(clock: () => now);

      controller.debugSetContextState(
        agentId: 'planner_agent',
        tokenEstimate: 16000,
        updatedAt: now.subtract(const Duration(days: 8)),
      );

      controller.recordToolCall(
        agentId: 'planner_agent',
        tool: AITutorToolType.scheduleCreation,
        routeLabel: '计划管理页',
      );

      final context = controller.contextOf('planner_agent');
      expect(context.compressionCount, greaterThan(0));
      expect(context.compressedSummaries.first, contains('age>7d'));
    });
  });
}
