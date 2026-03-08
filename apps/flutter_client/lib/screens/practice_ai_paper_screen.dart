import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../providers/app_provider.dart';
import '../widgets/ai_formula_text.dart';
import 'practice_session_screen.dart';

class PracticeAIPaperScreen extends StatefulWidget {
  const PracticeAIPaperScreen({super.key});

  @override
  State<PracticeAIPaperScreen> createState() => _PracticeAIPaperScreenState();
}

class _PracticeAIPaperScreenState extends State<PracticeAIPaperScreen> {
  static const _controllerAgent = _PaperAgent(
    id: 'paper_controller',
    name: '总卷编排 Agent',
    role: '总卷编排',
    mission: '负责整套试卷结构设计，按题量拆分给题型 Agent。',
  );
  static const _objectiveAgent = _PaperAgent(
    id: 'objective_agent',
    name: '选择题 Agent',
    role: '选择题生成',
    mission: '负责生成单选/多选类题目，确保覆盖基础知识点。',
  );
  static const _applicationAgent = _PaperAgent(
    id: 'application_agent',
    name: '应用题 Agent',
    role: '应用题生成',
    mission: '负责生成综合应用题，强调建模与解题过程。',
  );

  final TextEditingController _subjectController = TextEditingController(
    text: 'math',
  );
  final TextEditingController _topicController = TextEditingController(
    text: '函数综合',
  );
  final TextEditingController _countController = TextEditingController(
    text: '6',
  );
  final TextEditingController _difficultyController = TextEditingController(
    text: '3',
  );

  bool _generating = false;
  _PaperPlan? _latestPlan;
  List<Question> _paperQuestions = const <Question>[];
  final List<_AgentRunLog> _runLogs = <_AgentRunLog>[];

  @override
  void dispose() {
    _subjectController.dispose();
    _topicController.dispose();
    _countController.dispose();
    _difficultyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI组卷')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTeamCard(),
          const SizedBox(height: 12),
          _buildConfigCard(),
          if (_latestPlan != null) ...[
            const SizedBox(height: 12),
            _buildPlanCard(_latestPlan!),
          ],
          if (_runLogs.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildLogsCard(),
          ],
          if (_paperQuestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildGeneratedCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Agent Team',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            _AgentTile(agent: _controllerAgent),
            SizedBox(height: 6),
            _AgentTile(agent: _objectiveAgent),
            SizedBox(height: 6),
            _AgentTile(agent: _applicationAgent),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '组卷参数',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: '科目',
                hintText: '如：math / physics',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: '主题',
                hintText: '如：函数综合',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '总题量',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _difficultyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '难度(1-5)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _generating ? null : _generatePaper,
              icon: _generating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(_generating ? '组卷中...' : '开始 AI 组卷'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(_PaperPlan plan) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '总卷编排结果',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('总题量 ${plan.totalCount}')),
                Chip(label: Text('选择题 ${plan.objectiveCount}')),
                Chip(label: Text('应用题 ${plan.applicationCount}')),
              ],
            ),
            if (plan.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plan.note,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agent 执行日志',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._runLogs.map((item) {
              final color = _logColor(item.status, Theme.of(context));
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${_formatTime(item.at)} · ${item.agentName} · ${item.status.label} · ${item.message}',
                  style: TextStyle(fontSize: 12, color: color),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratedCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '组卷结果',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Chip(label: Text('${_paperQuestions.length} 题')),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_paperQuestions.length, (index) {
              final q = _paperQuestions[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AIFormulaText(
                      '${index + 1}. ${q.title.trim().isEmpty ? q.stem : q.title}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (q.title.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      AIFormulaText(q.stem),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '题型: ${_questionTypeLabel(q.type)}  |  难度: ${q.difficulty}  |  来源: ${q.source}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PracticeSessionScreen(),
                ),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('进入练习会话'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePaper() async {
    final provider = context.read<AppProvider>();
    final subject = _subjectController.text.trim();
    final topic = _topicController.text.trim();
    final totalCount = int.tryParse(_countController.text.trim()) ?? 0;
    var difficulty = int.tryParse(_difficultyController.text.trim()) ?? 3;
    difficulty = difficulty.clamp(1, 5);

    if (subject.isEmpty || topic.isEmpty) {
      _showSnack('科目和主题不能为空');
      return;
    }
    if (totalCount <= 0) {
      _showSnack('总题量必须大于 0');
      return;
    }

    final plan = _PaperPlanner.plan(totalCount);
    setState(() {
      _generating = true;
      _latestPlan = plan;
      _paperQuestions = const <Question>[];
      _runLogs.clear();
    });

    _appendLog(
      agentName: _controllerAgent.name,
      status: _RunStatus.success,
      message: '完成编排：选择题 ${plan.objectiveCount}，应用题 ${plan.applicationCount}',
    );

    final objective = await _runGenerationAgent(
      provider: provider,
      agent: _objectiveAgent,
      subject: subject,
      topic: topic,
      questionType: 'single_choice',
      count: plan.objectiveCount,
      difficulty: difficulty,
      plan: plan,
    );
    final application = await _runGenerationAgent(
      provider: provider,
      agent: _applicationAgent,
      subject: subject,
      topic: topic,
      questionType: 'short_answer',
      count: plan.applicationCount,
      difficulty: difficulty,
      plan: plan,
    );

    final combined = <Question>[...objective, ...application];
    if (combined.isNotEmpty) {
      await provider.fetchQuestions(force: true);
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _generating = false;
      _paperQuestions = combined;
    });

    if (combined.isEmpty) {
      _showSnack('组卷失败：未生成可用题目');
      return;
    }
    _showSnack('组卷完成，共 ${combined.length} 题');
  }

  Future<List<Question>> _runGenerationAgent({
    required AppProvider provider,
    required _PaperAgent agent,
    required String subject,
    required String topic,
    required String questionType,
    required int count,
    required int difficulty,
    required _PaperPlan plan,
  }) async {
    if (count <= 0) {
      _appendLog(
        agentName: agent.name,
        status: _RunStatus.skipped,
        message: '本轮无需执行',
      );
      return const <Question>[];
    }

    _appendLog(
      agentName: agent.name,
      status: _RunStatus.running,
      message: '开始生成 $count 题',
    );

    try {
      final generated = await provider.apiService.generateAIQuestions({
        'topic': '$topic（${agent.role}）',
        'subject': subject,
        'scope': 'practice_paper',
        'count': count,
        'difficulty': difficulty,
        'question_type': questionType,
        'agent_role': agent.role,
        'paper_constraints': {
          'total_count': plan.totalCount,
          'objective_count': plan.objectiveCount,
          'application_count': plan.applicationCount,
        },
      }, persist: true);
      _appendLog(
        agentName: agent.name,
        status: _RunStatus.success,
        message: '生成成功 ${generated.length} 题',
      );
      return generated;
    } catch (e) {
      _appendLog(
        agentName: agent.name,
        status: _RunStatus.failed,
        message: '生成失败: $e',
      );
      return const <Question>[];
    }
  }

  void _appendLog({
    required String agentName,
    required _RunStatus status,
    required String message,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _runLogs.insert(
        0,
        _AgentRunLog(
          at: DateTime.now(),
          agentName: agentName,
          status: status,
          message: message,
        ),
      );
    });
  }

  Color _logColor(_RunStatus status, ThemeData theme) {
    switch (status) {
      case _RunStatus.success:
        return Colors.green.shade700;
      case _RunStatus.failed:
        return theme.colorScheme.error;
      case _RunStatus.running:
        return theme.colorScheme.primary;
      case _RunStatus.skipped:
        return Colors.grey.shade600;
    }
  }

  String _formatTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    final s = value.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _questionTypeLabel(String type) {
    switch (type) {
      case 'single_choice':
        return '单选题';
      case 'multi_choice':
        return '多选题';
      case 'short_answer':
        return '应用题';
      default:
        return type.trim().isEmpty ? '-' : type;
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AgentTile extends StatelessWidget {
  const _AgentTile({required this.agent});

  final _PaperAgent agent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${agent.name} · ${agent.role}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(agent.mission, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _PaperAgent {
  const _PaperAgent({
    required this.id,
    required this.name,
    required this.role,
    required this.mission,
  });

  final String id;
  final String name;
  final String role;
  final String mission;
}

class _PaperPlan {
  const _PaperPlan({
    required this.totalCount,
    required this.objectiveCount,
    required this.applicationCount,
    this.note = '',
  });

  final int totalCount;
  final int objectiveCount;
  final int applicationCount;
  final String note;
}

class _PaperPlanner {
  static _PaperPlan plan(int totalCount) {
    if (totalCount <= 1) {
      return const _PaperPlan(
        totalCount: 1,
        objectiveCount: 1,
        applicationCount: 0,
        note: '题量过小，默认由选择题 Agent 执行。',
      );
    }
    final objectiveCount = ((totalCount * 0.6).round()).clamp(
      1,
      totalCount - 1,
    );
    return _PaperPlan(
      totalCount: totalCount,
      objectiveCount: objectiveCount,
      applicationCount: totalCount - objectiveCount,
    );
  }
}

enum _RunStatus { running, success, failed, skipped }

extension on _RunStatus {
  String get label {
    switch (this) {
      case _RunStatus.running:
        return '进行中';
      case _RunStatus.success:
        return '成功';
      case _RunStatus.failed:
        return '失败';
      case _RunStatus.skipped:
        return '跳过';
    }
  }
}

class _AgentRunLog {
  const _AgentRunLog({
    required this.at,
    required this.agentName,
    required this.status,
    required this.message,
  });

  final DateTime at;
  final String agentName;
  final _RunStatus status;
  final String message;
}
