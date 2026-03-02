import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final _modeController = TextEditingController(text: 'unit_learning');
  final _subjectController = TextEditingController(text: 'math');
  final _unitController = TextEditingController(text: '函数');
  final _goalsController = TextEditingController(text: '掌握核心概念,完成5道题');
  final _topicController = TextEditingController(text: '函数单调性');
  final _countController = TextEditingController(text: '3');
  final _difficultyController = TextEditingController(text: '3');
  final _scoreTopicController = TextEditingController(text: '函数');
  final _accuracyController = TextEditingController(text: '80');
  final _stabilityController = TextEditingController(text: '70');
  final _speedController = TextEditingController(text: '75');
  final _gradeQuestionIdController = TextEditingController();
  final _gradeAnswerController = TextEditingController();
  final _evaluateModeController = TextEditingController(text: 'comprehensive');
  final _evaluateContextController = TextEditingController(text: '错题复盘');
  bool _persist = false;

  @override
  void dispose() {
    _modeController.dispose();
    _subjectController.dispose();
    _unitController.dispose();
    _goalsController.dispose();
    _topicController.dispose();
    _countController.dispose();
    _difficultyController.dispose();
    _scoreTopicController.dispose();
    _accuracyController.dispose();
    _stabilityController.dispose();
    _speedController.dispose();
    _gradeQuestionIdController.dispose();
    _gradeAnswerController.dispose();
    _evaluateModeController.dispose();
    _evaluateContextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final status = provider.aiProviderStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI能力'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchAIProviderStatus(force: true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            title: '模型服务状态',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('服务商: ${status['provider'] ?? '-'}'),
                Text('模型: ${status['model'] ?? '-'}'),
                Text('可用: ${status['ready'] ?? false}'),
                Text('降级到Mock: ${status['fallback'] ?? false}'),
              ],
            ),
          ),
          _section(
            title: 'AI学习计划',
            child: Column(
              children: [
                _input(_modeController, '模式（如 unit_learning / unit_review）'),
                _input(_subjectController, '科目'),
                _input(_unitController, '单元'),
                _input(_goalsController, '目标（逗号分隔）'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    await provider.buildLearningPlan({
                      'mode': _modeController.text.trim(),
                      'subject': _subjectController.text.trim(),
                      'unit': _unitController.text.trim(),
                      'current_stage': 'pending',
                      'goals': _goalsController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                    });
                  },
                  child: const Text('生成计划'),
                ),
                if (provider.aiLearningPlan != null)
                  _jsonBox(provider.aiLearningPlan!),
              ],
            ),
          ),
          _section(
            title: 'AI出题',
            child: Column(
              children: [
                _input(_topicController, '主题'),
                _input(_subjectController, '科目'),
                _input(_countController, '数量'),
                _input(_difficultyController, '难度(1-5)'),
                SwitchListTile(
                  value: _persist,
                  title: const Text('同时写入题库'),
                  onChanged: (v) => setState(() => _persist = v),
                ),
                FilledButton(
                  onPressed: () async {
                    await provider.generateAIQuestions({
                      'topic': _topicController.text.trim(),
                      'subject': _subjectController.text.trim(),
                      'scope': 'unit',
                      'count': int.tryParse(_countController.text.trim()) ?? 3,
                      'difficulty':
                          int.tryParse(_difficultyController.text.trim()) ?? 3,
                    }, persist: _persist);
                  },
                  child: const Text('开始出题'),
                ),
                const SizedBox(height: 8),
                Text('生成题目数量：${provider.aiGeneratedQuestions.length}'),
              ],
            ),
          ),
          _section(
            title: 'AI搜题',
            child: Column(
              children: [
                _input(_topicController, '主题'),
                _input(_subjectController, '科目'),
                _input(_countController, '数量'),
                FilledButton(
                  onPressed: () async {
                    await provider.searchAIQuestions(
                      topic: _topicController.text.trim(),
                      subject: _subjectController.text.trim(),
                      count: int.tryParse(_countController.text.trim()) ?? 5,
                    );
                  },
                  child: const Text('联网搜题'),
                ),
                const SizedBox(height: 8),
                Text('搜索结果数量：${provider.aiSearchQuestions.length}'),
              ],
            ),
          ),
          _section(
            title: 'AI评分',
            child: Column(
              children: [
                _input(_scoreTopicController, '主题'),
                _input(_accuracyController, '准确率(0-100)'),
                _input(_stabilityController, '稳定度(0-100)'),
                _input(_speedController, '速度(0-100)'),
                FilledButton(
                  onPressed: () async {
                    await provider.scoreWithAI({
                      'topic': _scoreTopicController.text.trim(),
                      'accuracy':
                          double.tryParse(_accuracyController.text.trim()) ?? 0,
                      'stability':
                          double.tryParse(_stabilityController.text.trim()) ??
                          0,
                      'speed':
                          double.tryParse(_speedController.text.trim()) ?? 0,
                    });
                  },
                  child: const Text('计算评分'),
                ),
                if (provider.aiScoreResult != null)
                  _jsonBox(provider.aiScoreResult!),
              ],
            ),
          ),
          _section(
            title: 'AI批阅',
            child: Column(
              children: [
                _input(_gradeQuestionIdController, '题目ID'),
                _input(_gradeAnswerController, '作答内容(逗号分隔)'),
                FilledButton(
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
                    await provider.gradeWithAI({
                      'question': questionPayload,
                      'user_answer': _gradeAnswerController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                    });
                  },
                  child: const Text('执行批阅'),
                ),
                if (provider.aiGradeResult != null)
                  _jsonBox(provider.aiGradeResult!),
              ],
            ),
          ),
          _section(
            title: 'AI评估',
            child: Column(
              children: [
                _input(_evaluateModeController, '评估模式'),
                _input(_gradeQuestionIdController, '题目ID'),
                _input(_gradeAnswerController, '作答内容(逗号分隔)'),
                _input(_evaluateContextController, '评估上下文'),
                FilledButton(
                  onPressed: () async {
                    final questionPayload = _questionPayloadById(
                      provider,
                      _gradeQuestionIdController.text.trim(),
                    );
                    await provider.evaluateWithAI({
                      'mode': _evaluateModeController.text.trim(),
                      'question': questionPayload ?? <String, dynamic>{},
                      'user_answer': _gradeAnswerController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      'context': _evaluateContextController.text.trim(),
                    });
                  },
                  child: const Text('执行评估'),
                ),
                if (provider.aiEvaluateResult != null)
                  _jsonBox(provider.aiEvaluateResult!),
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
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
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

  Widget _jsonBox(Map<String, dynamic> map) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(const JsonEncoder.withIndent('  ').convert(map)),
    );
  }

  Map<String, dynamic>? _questionPayloadById(AppProvider provider, String id) {
    if (id.isEmpty) {
      return null;
    }
    for (final q in provider.questions) {
      if (q.id == id) {
        return q.toJson();
      }
    }
    return null;
  }
}
