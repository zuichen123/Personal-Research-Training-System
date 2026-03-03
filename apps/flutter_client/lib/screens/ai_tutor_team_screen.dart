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
                  label: Text('Controller 记录 ${controllerContext.toolCalls.length}'),
                  visualDensity: VisualDensity.compact,
                ),
                const Chip(
                  label: Text('学科 Agent 上下文隔离'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
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
    final context = _teamController.contextOf(agent.id);
    final latestNote = context.notes.isNotEmpty ? context.notes.first : '暂无上下文';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          child: Text(agent.subject.isEmpty ? '-' : agent.subject.substring(0, 1)),
        ),
        title: Text('${agent.name} · ${agent.role}'),
        subtitle: Text(
          '${agent.mission}\n最近上下文: $latestNote',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Chip(
          label: Text('调用 ${_teamController.toolCallCount(agent.id)}'),
          visualDensity: VisualDensity.compact,
        ),
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
                childAspectRatio: wide ? 3.4 : 3.6,
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
    final assignedAgent = _teamController.subjectAgents.firstWhere(
      (agent) => agent.id == spec.agentId,
      orElse: () => const AITutorAgent(
        id: 'unknown',
        name: 'Unknown Agent',
        role: '未分配',
        subject: '-',
        mission: '-',
      ),
    );
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
                    'Agent: ${assignedAgent.name}',
                    style: const TextStyle(fontSize: 11),
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
                    '${_formatTime(record.triggeredAt)} · ${record.tool.label} -> ${record.routeLabel}',
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
    _teamController.recordToolCall(
      agentId: spec.agentId,
      tool: spec.tool,
      routeLabel: spec.targetLabel,
    );
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: spec.destinationBuilder));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已返回 Team 页面')));
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
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
