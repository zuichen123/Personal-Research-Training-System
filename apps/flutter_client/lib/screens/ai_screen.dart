import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  // ---- AI学习计划（独立控制器） ----
  final _learnModeController = TextEditingController(text: 'unit_learning');
  final _learnSubjectController = TextEditingController(text: 'math');
  final _learnUnitController = TextEditingController(text: '函数');
  final _learnGoalsController = TextEditingController(text: '掌握核心概念,完成5道题');

  // ---- AI出题（独立控制器） ----
  final _genTopicController = TextEditingController(text: '函数单调性');
  final _genSubjectController = TextEditingController(text: 'math');
  final _genCountController = TextEditingController(text: '3');
  final _genDifficultyController = TextEditingController(text: '3');
  bool _persist = false;

  // ---- AI搜题（独立控制器） ----
  final _searchTopicController = TextEditingController(text: '函数单调性');
  final _searchSubjectController = TextEditingController(text: 'math');
  final _searchCountController = TextEditingController(text: '5');

  // ---- AI评分（独立控制器） ----
  final _scoreTopicController = TextEditingController(text: '函数');
  final _accuracyController = TextEditingController(text: '80');
  final _stabilityController = TextEditingController(text: '70');
  final _speedController = TextEditingController(text: '75');

  // ---- AI批阅（独立控制器） ----
  final _gradeQuestionIdController = TextEditingController();
  final _gradeAnswerController = TextEditingController();

  // ---- AI评估（独立控制器） ----
  final _evaluateModeController = TextEditingController(text: 'comprehensive');
  final _evaluateQuestionIdController = TextEditingController();
  final _evaluateAnswerController = TextEditingController();
  final _evaluateContextController = TextEditingController(text: '错题复盘');

  // ---- 折叠状态 ----
  final Map<String, bool> _expanded = {};

  @override
  void dispose() {
    _learnModeController.dispose();
    _learnSubjectController.dispose();
    _learnUnitController.dispose();
    _learnGoalsController.dispose();
    _genTopicController.dispose();
    _genSubjectController.dispose();
    _genCountController.dispose();
    _genDifficultyController.dispose();
    _searchTopicController.dispose();
    _searchSubjectController.dispose();
    _searchCountController.dispose();
    _scoreTopicController.dispose();
    _accuracyController.dispose();
    _stabilityController.dispose();
    _speedController.dispose();
    _gradeQuestionIdController.dispose();
    _gradeAnswerController.dispose();
    _evaluateModeController.dispose();
    _evaluateQuestionIdController.dispose();
    _evaluateAnswerController.dispose();
    _evaluateContextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 能力')),
      body: _aiBody(context),
    );
  }

  Widget _aiBody(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section(
          title: 'AI学习计划',
          icon: Icons.school_outlined,
          child: Column(
            children: [
              _input(_learnModeController, '模式（如 unit_learning / unit_review）'),
              _input(_learnSubjectController, '科目'),
              _input(_learnUnitController, '单元'),
              _input(_learnGoalsController, '目标（逗号分隔）'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () async {
                  await _runProviderAction(() {
                    return provider.buildLearningPlan({
                      'mode': _learnModeController.text.trim(),
                      'subject': _learnSubjectController.text.trim(),
                      'unit': _learnUnitController.text.trim(),
                      'current_stage': 'pending',
                      'goals': _learnGoalsController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                    });
                  });
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('生成计划'),
              ),
              if (provider.aiLearningPlan != null)
                _jsonBox('learn', provider.aiLearningPlan!),
            ],
          ),
        ),
        _section(
          title: 'AI出题',
          icon: Icons.quiz_outlined,
          child: Column(
            children: [
              _input(_genTopicController, '主题'),
              _input(_genSubjectController, '科目'),
              _input(_genCountController, '数量'),
              _input(_genDifficultyController, '难度(1-5)'),
              SwitchListTile(
                value: _persist,
                title: const Text('同时写入题库'),
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _persist = v),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await _runProviderAction(() {
                    return provider.generateAIQuestions({
                      'topic': _genTopicController.text.trim(),
                      'subject': _genSubjectController.text.trim(),
                      'scope': 'unit',
                      'count':
                          int.tryParse(_genCountController.text.trim()) ?? 3,
                      'difficulty':
                          int.tryParse(_genDifficultyController.text.trim()) ??
                          3,
                    }, persist: _persist);
                  });
                },
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('开始出题'),
              ),
              const SizedBox(height: 8),
              Text('生成题目数量：${provider.aiGeneratedQuestions.length}'),
            ],
          ),
        ),
        _section(
          title: 'AI搜题',
          icon: Icons.travel_explore,
          child: Column(
            children: [
              _input(_searchTopicController, '主题'),
              _input(_searchSubjectController, '科目'),
              _input(_searchCountController, '数量'),
              FilledButton.icon(
                onPressed: () async {
                  await _runProviderAction(() {
                    return provider.searchAIQuestions(
                      topic: _searchTopicController.text.trim(),
                      subject: _searchSubjectController.text.trim(),
                      count:
                          int.tryParse(_searchCountController.text.trim()) ?? 5,
                    );
                  });
                },
                icon: const Icon(Icons.search),
                label: const Text('联网搜题'),
              ),
              const SizedBox(height: 8),
              Text('搜索结果数量：${provider.aiSearchQuestions.length}'),
            ],
          ),
        ),
        _section(
          title: 'AI评分',
          icon: Icons.analytics_outlined,
          child: Column(
            children: [
              _input(_scoreTopicController, '主题'),
              _input(_accuracyController, '准确率(0-100)'),
              _input(_stabilityController, '稳定度(0-100)'),
              _input(_speedController, '速度(0-100)'),
              FilledButton.icon(
                onPressed: () async {
                  await _runProviderAction(() {
                    return provider.scoreWithAI({
                      'topic': _scoreTopicController.text.trim(),
                      'accuracy':
                          double.tryParse(_accuracyController.text.trim()) ?? 0,
                      'stability':
                          double.tryParse(_stabilityController.text.trim()) ??
                          0,
                      'speed':
                          double.tryParse(_speedController.text.trim()) ?? 0,
                    });
                  });
                },
                icon: const Icon(Icons.calculate),
                label: const Text('计算评分'),
              ),
              if (provider.aiScoreResult != null)
                _jsonBox('score', provider.aiScoreResult!),
            ],
          ),
        ),
        _section(
          title: 'AI批阅',
          icon: Icons.grading,
          child: Column(
            children: [
              _input(_gradeQuestionIdController, '题目ID'),
              _input(_gradeAnswerController, '作答内容(逗号分隔)'),
              FilledButton.icon(
                onPressed: () async {
                  final questionPayload = _questionPayloadById(
                    provider,
                    _gradeQuestionIdController.text.trim(),
                  );
                  if (questionPayload == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请先输入存在的题目ID')),
                      );
                    }
                    return;
                  }
                  await _runProviderAction(() {
                    return provider.gradeWithAI({
                      'question': questionPayload,
                      'user_answer': _gradeAnswerController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                    });
                  });
                },
                icon: const Icon(Icons.rate_review),
                label: const Text('执行批阅'),
              ),
              if (provider.aiGradeResult != null)
                _jsonBox('grade', provider.aiGradeResult!),
            ],
          ),
        ),
        _section(
          title: 'AI评估',
          icon: Icons.assessment_outlined,
          child: Column(
            children: [
              _input(_evaluateModeController, '评估模式'),
              _input(_evaluateQuestionIdController, '题目ID'),
              _input(_evaluateAnswerController, '作答内容(逗号分隔)'),
              _input(_evaluateContextController, '评估上下文'),
              FilledButton.icon(
                onPressed: () async {
                  final questionPayload = _questionPayloadById(
                    provider,
                    _evaluateQuestionIdController.text.trim(),
                  );
                  await _runProviderAction(() {
                    return provider.evaluateWithAI({
                      'mode': _evaluateModeController.text.trim(),
                      'question': questionPayload ?? <String, dynamic>{},
                      'user_answer': _evaluateAnswerController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      'context': _evaluateContextController.text.trim(),
                    });
                  });
                },
                icon: const Icon(Icons.fact_check),
                label: const Text('执行评估'),
              ),
              if (provider.aiEvaluateResult != null)
                _jsonBox('evaluate', provider.aiEvaluateResult!),
            ],
          ),
        ),
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '错误：${provider.errorMessage}',
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  // ---- helpers ----

  Widget _section({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _jsonBox(String key, Map<String, dynamic> map) {
    final isExpanded = _expanded[key] ?? true;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(map);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded[key] = !isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '返回结果',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.copy, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: SelectableText(
                jsonStr,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _runProviderAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // AppProvider already records and exposes errorMessage.
    }
  }

  Map<String, dynamic>? _questionPayloadById(AppProvider provider, String id) {
    if (id.isEmpty) return null;
    for (final q in provider.questions) {
      if (q.id != id) continue;
      return {
        'id': q.id,
        'title': q.title,
        'stem': q.stem,
        'type': q.type,
        'subject': q.subject,
        'source': q.source,
        'options': q.options.map((e) => e.toJson()).toList(),
        'answer_key': q.answerKey,
        'tags': q.tags,
        'difficulty': q.difficulty,
        'mastery_level': q.masteryLevel,
      };
    }
    return null;
  }
}
