import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'debug_log_screen.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ---- 模型连接配置 ----
  final _modelController = TextEditingController();
  final _modelFocusNode = FocusNode();
  final _openAIBaseURLController = TextEditingController();
  final _openAIBaseURLFocusNode = FocusNode();
  final _apiKeyController = TextEditingController();
  String _selectedProvider = 'mock';
  bool _showApiKey = false;

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
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _modelController.dispose();
    _modelFocusNode.dispose();
    _openAIBaseURLController.dispose();
    _openAIBaseURLFocusNode.dispose();
    _apiKeyController.dispose();
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
      appBar: AppBar(
        title: const Text('AI 能力'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.psychology), text: 'AI功能'),
            Tab(icon: Icon(Icons.bug_report), text: '调试日志'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<AppProvider>().fetchAIProviderStatus(force: true),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _aiBody(context),
          const DebugLogScreen(embedded: true),
        ],
      ),
    );
  }

  Widget _aiBody(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final status = provider.aiProviderStatus;
    _syncProviderConfig(status);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section(
          title: '模型服务状态',
          icon: Icons.cloud_done_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statusRow('当前生效服务商', status['provider']),
              _statusRow('已配置服务商', status['configured_provider']),
              _statusRow('模型', status['model']),
              _statusRow('可用', '${status['ready'] ?? false}'),
              _statusRow('降级到Mock', '${status['fallback'] ?? false}'),
              _statusRow('密钥状态',
                  (status['has_api_key'] ?? false) ? '已配置' : '未配置'),
              _statusRow('OpenAI Base URL', status['openai_base_url']),
            ],
          ),
        ),
        _section(
          title: '模型连接配置',
          icon: Icons.settings_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedProvider,
                decoration: const InputDecoration(
                  labelText: '供应商',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'mock', child: Text('mock')),
                  DropdownMenuItem(value: 'openai', child: Text('openai')),
                  DropdownMenuItem(value: 'gemini', child: Text('gemini')),
                  DropdownMenuItem(value: 'claude', child: Text('claude')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedProvider = value);
                },
              ),
              const SizedBox(height: 8),
              _input(_modelController, '模型名称（可选）',
                  focusNode: _modelFocusNode),
              if (_selectedProvider == 'openai')
                _input(
                    _openAIBaseURLController, 'OpenAI 兼容 API 地址（可选）',
                    focusNode: _openAIBaseURLFocusNode),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _apiKeyController,
                  obscureText: !_showApiKey,
                  decoration: InputDecoration(
                    labelText: 'API Token（可选，输入则覆盖当前）',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(_showApiKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _showApiKey = !_showApiKey),
                    ),
                  ),
                ),
              ),
              const Text('提示：token 不会在状态接口中回显。',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _saveProviderConfig(context, provider),
                icon: const Icon(Icons.save),
                label: const Text('保存配置'),
              ),
            ],
          ),
        ),
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
                  await provider.buildLearningPlan({
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
                  await provider.generateAIQuestions({
                    'topic': _genTopicController.text.trim(),
                    'subject': _genSubjectController.text.trim(),
                    'scope': 'unit',
                    'count':
                        int.tryParse(_genCountController.text.trim()) ?? 3,
                    'difficulty':
                        int.tryParse(_genDifficultyController.text.trim()) ??
                            3,
                  }, persist: _persist);
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
                  await provider.searchAIQuestions(
                    topic: _searchTopicController.text.trim(),
                    subject: _searchSubjectController.text.trim(),
                    count:
                        int.tryParse(_searchCountController.text.trim()) ?? 5,
                  );
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
                  await provider.scoreWithAI({
                    'topic': _scoreTopicController.text.trim(),
                    'accuracy':
                        double.tryParse(_accuracyController.text.trim()) ?? 0,
                    'stability':
                        double.tryParse(_stabilityController.text.trim()) ?? 0,
                    'speed':
                        double.tryParse(_speedController.text.trim()) ?? 0,
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
                  await provider.gradeWithAI({
                    'question': questionPayload,
                    'user_answer': _gradeAnswerController.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
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
                  await provider.evaluateWithAI({
                    'mode': _evaluateModeController.text.trim(),
                    'question': questionPayload ?? <String, dynamic>{},
                    'user_answer': _evaluateAnswerController.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                    'context': _evaluateContextController.text.trim(),
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

  Widget _statusRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          Expanded(
            child: Text('${value ?? '-'}',
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

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
                  Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    FocusNode? focusNode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        focusNode: focusNode,
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  const Text('返回结果',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制到剪贴板')),
                      );
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

  Future<void> _saveProviderConfig(
      BuildContext context, AppProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final token = _apiKeyController.text.trim();
    final model = _modelController.text.trim();
    final baseURL = _openAIBaseURLController.text.trim();
    try {
      await provider.updateAIProviderConfig(
        provider: _selectedProvider,
        apiKey: token.isEmpty ? null : token,
        model: model.isEmpty ? null : model,
        openAIBaseURL: _selectedProvider == 'openai'
            ? (baseURL.isEmpty ? null : baseURL)
            : null,
      );
      _apiKeyController.clear();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('模型配置已更新')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? '更新失败')),
      );
    }
  }

  void _syncProviderConfig(Map<String, dynamic> status) {
    final configuredProvider =
        (status['configured_provider'] ?? status['provider'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (configuredProvider.isNotEmpty &&
        configuredProvider != _selectedProvider &&
        (configuredProvider == 'mock' ||
            configuredProvider == 'openai' ||
            configuredProvider == 'gemini' ||
            configuredProvider == 'claude')) {
      _selectedProvider = configuredProvider;
    }
    if (!_modelFocusNode.hasFocus) {
      final model = (status['model'] ?? '').toString().trim();
      if (model.isNotEmpty && _modelController.text.trim() != model) {
        _modelController.text = model;
      }
    }
    if (_openAIBaseURLFocusNode.hasFocus) return;
    final baseURL = (status['openai_base_url'] ?? '').toString().trim();
    if (baseURL.isEmpty || _openAIBaseURLController.text.trim() == baseURL) {
      return;
    }
    _openAIBaseURLController.text = baseURL;
  }

  Map<String, dynamic>? _questionPayloadById(AppProvider provider, String id) {
    if (id.isEmpty) return null;
    for (final q in provider.questions) {
      if (q.id == id) return q.toJson();
    }
    return null;
  }
}
