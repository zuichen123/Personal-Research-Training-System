import 'package:flutter/material.dart';

import '../controllers/ai_tutor_team_controller.dart';
import '../models/ai_tutor_team.dart';
import 'ai_screen.dart';
import 'plans_screen.dart';
import 'pomodoro_screen.dart';

class AITutorTeamScreen extends StatefulWidget {
  const AITutorTeamScreen({super.key});

  @override
  State<AITutorTeamScreen> createState() => _AITutorTeamScreenState();
}

class _AITutorTeamScreenState extends State<AITutorTeamScreen> {
  late final AITutorTeamController _teamController;
  late final List<_ToolCardSpec> _toolSpecs;

  @override
  void initState() {
    super.initState();
    _teamController = AITutorTeamController();
    _toolSpecs = [
      _ToolCardSpec(
        tool: AITutorToolType.questionGeneration,
        agentId: 'math_agent',
        targetLabel: 'AI 出题工作台',
        icon: Icons.auto_fix_high_outlined,
        destinationBuilder: (_) =>
            const AIScreen(focusSection: AIScreenFocusSection.generate),
      ),
      _ToolCardSpec(
        tool: AITutorToolType.grading,
        agentId: 'review_agent',
        targetLabel: 'AI 批阅工作台',
        icon: Icons.rate_review_outlined,
        destinationBuilder: (_) =>
            const AIScreen(focusSection: AIScreenFocusSection.grade),
      ),
      _ToolCardSpec(
        tool: AITutorToolType.scheduleCreation,
        agentId: 'planner_agent',
        targetLabel: '计划管理页',
        icon: Icons.event_note_outlined,
        destinationBuilder: (_) => const PlansScreen(),
      ),
      _ToolCardSpec(
        tool: AITutorToolType.pomodoro,
        agentId: 'focus_agent',
        targetLabel: '专注计时页',
        icon: Icons.timer_outlined,
        destinationBuilder: (_) => const PomodoroScreen(),
      ),
    ];
  }

  @override
  void dispose() {
    _teamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _teamController,
      builder: (context, _) {
        final controllerAgent = _teamController.controllerAgent;
        final controllerContext = _teamController.contextOf(controllerAgent.id);
        return Scaffold(
          appBar: AppBar(title: const Text('AI Tutor Team')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _teamOverviewCard(controllerAgent, controllerContext),
              const SizedBox(height: 10),
              _controllerSchedulingCard(),
              const SizedBox(height: 10),
              _subjectAgentsCard(),
              const SizedBox(height: 10),
              _toolCallCard(),
              const SizedBox(height: 10),
              _controllerHistoryCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _teamOverviewCard(
    AITutorAgent controllerAgent,
    AITutorAgentContext controllerContext,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hub_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  controllerAgent.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(controllerAgent.mission),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text('总工具调用 ${_teamController.totalToolCalls}'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text('Controller tokens ${controllerContext.tokenEstimate}'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text('压缩次数 ${controllerContext.compressionCount}'),
                  visualDensity: VisualDensity.compact,
                ),
                const Chip(
                  label: Text('自动压缩 >100k tokens 或 >7天'),
                  visualDensity: VisualDensity.compact,
                ),
                const Chip(
                  label: Text('学科 Agent 上下文独立'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _controllerSchedulingCard() {
    final decisions = _teamController.latestScheduleDecisions(limit: 6);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Controller Scheduling',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (decisions.isEmpty)
              ..._toolSpecs.map((spec) {
                final hint = _teamController.scheduleHint(
                  tool: spec.tool,
                  defaultAgentId: spec.agentId,
                );
                final base = '${spec.tool.label} -> ${hint.assignedAgentName}';
                final msg = hint.hasSuggestion
                    ? '$base（建议切换到 ${hint.suggestedAgentName}）'
                    : base;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(msg, style: const TextStyle(fontSize: 12)),
                );
              })
            else
              ...decisions.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${_formatTime(item.scheduledAt)} · ${item.tool.label} -> ${item.assignedAgentName} · ${item.reason}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _subjectAgentsCard() {
    final agents = _teamController.subjectAgents;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subject Agents',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ...agents.map((agent) => _subjectAgentTile(agent)),
          ],
        ),
      ),
    );
  }

  Widget _subjectAgentTile(AITutorAgent agent) {
    final contextData = _teamController.contextOf(agent.id);
    final latestNote = contextData.notes.isNotEmpty
        ? contextData.notes.first
        : '暂无上下文';
    final compressedAt = contextData.lastCompressedAt == null
        ? '未压缩'
        : _formatDateTime(contextData.lastCompressedAt!);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            child: Text(agent.subject.isEmpty ? '-' : agent.subject.substring(0, 1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${agent.name} · ${agent.role}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(agent.mission, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '最近上下文: $latestNote',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(
                      label: Text(
                        '调用 ${_teamController.toolCallCount(agent.id)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Chip(
                      label: Text(
                        'tokens ${contextData.tokenEstimate}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Chip(
                      label: Text(
                        '压缩 ${contextData.compressionCount}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Chip(
                      label: Text(
                        '最近压缩 $compressedAt',
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolCallCard() {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tool Calls',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              itemCount: _toolSpecs.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: wide ? 2 : 1,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: wide ? 3.0 : 3.3,
              ),
              itemBuilder: (context, index) {
                final spec = _toolSpecs[index];
                return _toolTile(spec);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolTile(_ToolCardSpec spec) {
    final hint = _teamController.scheduleHint(
      tool: spec.tool,
      defaultAgentId: spec.agentId,
    );
    final assignedAgent = _agentByID(hint.assignedAgentId);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _triggerToolCall(spec),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              child: Icon(spec.icon, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.tool.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.tool.description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '分派: ${assignedAgent.name}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (hint.hasSuggestion)
                    Text(
                      '建议切换 -> ${hint.suggestedAgentName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _controllerHistoryCard() {
    final records = _teamController.latestControllerRecords(limit: 6);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Controller Dispatch Log',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (records.isEmpty)
              const Text('暂无分派记录')
            else
              ...records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${_formatTime(record.triggeredAt)} · ${record.tool.label} -> ${record.routeLabel} · ${record.agentName}${record.switchedByController ? ' · switched' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerToolCall(_ToolCardSpec spec) async {
    final decision = _teamController.dispatchToolCall(
      tool: spec.tool,
      defaultAgentId: spec.agentId,
      routeLabel: spec.targetLabel,
    );
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: spec.destinationBuilder));
    if (!mounted) {
      return;
    }

    final message = decision.autoSwitched
        ? 'Controller 已自动切换到 ${decision.assignedAgentName}'
        : decision.hasSuggestion
            ? '建议切换到 ${decision.suggestedAgentName}'
            : '已返回 Team 页面';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  AITutorAgent _agentByID(String agentId) {
    return _teamController.subjectAgents.firstWhere(
      (agent) => agent.id == agentId,
      orElse: () => const AITutorAgent(
        id: 'unknown',
        name: 'Unknown Agent',
        role: '未分配',
        subject: '-',
        mission: '-',
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _formatDateTime(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}

class _ToolCardSpec {
  const _ToolCardSpec({
    required this.tool,
    required this.agentId,
    required this.targetLabel,
    required this.icon,
    required this.destinationBuilder,
  });

  final AITutorToolType tool;
  final String agentId;
  final String targetLabel;
  final IconData icon;
  final WidgetBuilder destinationBuilder;
}
