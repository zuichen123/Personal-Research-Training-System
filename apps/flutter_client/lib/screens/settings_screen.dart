import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_agent_chat.dart';
import '../models/user_profile.dart';
import '../providers/ai_agent_provider.dart';
import '../providers/app_provider.dart';
import 'debug_log_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _modelController = TextEditingController();
  final _modelFocusNode = FocusNode();
  final _openAIBaseURLController = TextEditingController();
  final _openAIBaseURLFocusNode = FocusNode();
  final _apiKeyController = TextEditingController();
  String _selectedProvider = 'mock';
  bool _providerDirty = false;
  bool _showApiKey = false;

  final _nicknameController = TextEditingController();
  final _ageController = TextEditingController();
  final _academicStatusController = TextEditingController();
  final _goalsController = TextEditingController();
  final _goalTargetDateController = TextEditingController();
  final _dailyStudyMinutesController = TextEditingController();
  final _weakSubjectsController = TextEditingController();
  final _targetDestinationController = TextEditingController();
  final _notesController = TextEditingController();

  final _outputPromptController = TextEditingController();
  final _outputPromptFocusNode = FocusNode();
  final Map<String, TextEditingController> _segmentPromptControllers = {};

  bool _profileDirty = false;
  bool _syncingProfileForm = false;
  String _selectedAcademicPreset = _customAcademicStatus;

  String? _selectedPromptKey;
  bool _promptDirty = false;
  bool _syncingPromptForm = false;
  bool _promptAdvancedExpanded = false;

  bool? _backendHealthy;
  bool _checkingHealth = false;
  int? _healthLatencyMs;
  DateTime? _lastHealthCheck;

  static const String _customAcademicStatus = '自定义';
  static const List<String> _academicStatusPresets = [
    '初中',
    '高中',
    '中专',
    '大专',
    '本科',
    '硕士',
    '博士',
    '在职学习',
    '备考',
    _customAcademicStatus,
  ];

  static const List<String> _editablePromptSegmentKeys = [
    'persona',
    'identity',
    'user_background',
    'ai_memo',
    'user_profile',
    'scoring_criteria',
    'tool_instructions',
    'current_schedule',
    'learning_progress',
    'rules',
    'reserved_slot_1',
    'reserved_slot_2',
    'reserved_slot_3',
    'reserved_slot_4',
    'reserved_slot_5',
    'task_prompt',
  ];

  static const List<String> _primaryPromptSegmentKeys = [
    'task_prompt',
    'tool_instructions',
    'rules',
  ];

  static const Set<String> _optionalPromptSegments = {
    'ai_memo',
    'user_profile',
  };

  static const Map<String, String> _promptSegmentLabels = {
    'persona': '人格设定 (persona)',
    'identity': '身份设定 (identity)',
    'user_background': '用户背景 (user_background)',
    'ai_memo': 'AI备忘 (ai_memo)',
    'user_profile': '用户画像 (user_profile)',
    'scoring_criteria': '评分标准 (scoring_criteria)',
    'tool_instructions': '工具说明 (tool_instructions)',
    'current_schedule': '当前日程 (current_schedule)',
    'learning_progress': '学习进度 (learning_progress)',
    'rules': '遵守规则 (rules)',
    'reserved_slot_1': '预留拼接位1 (reserved_slot_1)',
    'reserved_slot_2': '预留拼接位2 (reserved_slot_2)',
    'reserved_slot_3': '预留拼接位3 (reserved_slot_3)',
    'reserved_slot_4': '预留拼接位4 (reserved_slot_4)',
    'reserved_slot_5': '预留拼接位5 (reserved_slot_5)',
    'task_prompt': '任务指令 (task_prompt)',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _bindProfileDirtyListener(_nicknameController);
    _bindProfileDirtyListener(_ageController);
    _bindProfileDirtyListener(_academicStatusController);
    _bindProfileDirtyListener(_goalsController);
    _bindProfileDirtyListener(_goalTargetDateController);
    _bindProfileDirtyListener(_dailyStudyMinutesController);
    _bindProfileDirtyListener(_weakSubjectsController);
    _bindProfileDirtyListener(_targetDestinationController);
    _bindProfileDirtyListener(_notesController);

    for (final key in _editablePromptSegmentKeys) {
      final controller = TextEditingController();
      _segmentPromptControllers[key] = controller;
      _bindPromptDirtyListener(controller);
    }
    _bindPromptDirtyListener(_outputPromptController);

    _checkBackendHealth();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AIAgentProvider>().refreshAgents();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();

    _modelController.dispose();
    _modelFocusNode.dispose();
    _openAIBaseURLController.dispose();
    _openAIBaseURLFocusNode.dispose();
    _apiKeyController.dispose();

    _nicknameController.dispose();
    _ageController.dispose();
    _academicStatusController.dispose();
    _goalsController.dispose();
    _goalTargetDateController.dispose();
    _dailyStudyMinutesController.dispose();
    _weakSubjectsController.dispose();
    _targetDestinationController.dispose();
    _notesController.dispose();

    _outputPromptController.dispose();
    _outputPromptFocusNode.dispose();
    for (final controller in _segmentPromptControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _checkBackendHealth() async {
    if (_checkingHealth) return;
    setState(() => _checkingHealth = true);
    final stopwatch = Stopwatch()..start();
    try {
      final provider = context.read<AppProvider>();
      final healthy = await provider.apiService.checkHealth();
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _backendHealthy = healthy;
          _healthLatencyMs = stopwatch.elapsedMilliseconds;
          _lastHealthCheck = DateTime.now();
        });
      }
    } catch (_) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _backendHealthy = false;
          _healthLatencyMs = stopwatch.elapsedMilliseconds;
          _lastHealthCheck = DateTime.now();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _checkingHealth = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline), text: '用户信息'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'AI设置'),
            Tab(icon: Icon(Icons.bug_report_outlined), text: '调试日志'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () async {
              final app = context.read<AppProvider>();
              final agentProvider = context.read<AIAgentProvider>();
              await app.fetchUserProfile(force: true);
              await app.fetchAIProviderStatus(force: true);
              await agentProvider.refreshAgents();
              if (!mounted) return;
              _syncPromptTemplate(app.aiPromptTemplates);
              setState(() {});
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _profileSettingsBody(context),
          _aiSettingsBody(context),
          const DebugLogScreen(embedded: true),
        ],
      ),
    );
  }

  Widget _profileSettingsBody(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final profile = provider.userProfile;
    _syncProfileForm(profile);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (provider.isSectionLoading(DataSection.profile) && profile == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        _section(
          title: '基础信息',
          icon: Icons.badge_outlined,
          child: Column(
            children: [
              _input(_nicknameController, '昵称（可选）'),
              _input(
                _ageController,
                '年龄（必填）',
                keyboardType: TextInputType.number,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<String>(
                  value: _selectedAcademicPreset,
                  decoration: const InputDecoration(
                    labelText: '学业状态（快捷选择）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _academicStatusPresets
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedAcademicPreset = value;
                      if (value != _customAcademicStatus) {
                        _academicStatusController.text = value;
                      }
                      _profileDirty = true;
                    });
                  },
                ),
              ),
              _input(_academicStatusController, '学业状态（可手动填写）'),
            ],
          ),
        ),
        _section(
          title: '目标与补充信息',
          icon: Icons.flag_outlined,
          child: Column(
            children: [
              _input(_goalsController, '目标（必填，每行一个）', maxLines: 3, minLines: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _goalTargetDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: '目标日期（可选）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '选择日期',
                      onPressed: _pickGoalTargetDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                    IconButton(
                      tooltip: '清空日期',
                      onPressed: () {
                        _goalTargetDateController.clear();
                        _profileDirty = true;
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ],
                ),
              ),
              _input(
                _dailyStudyMinutesController,
                '每日学习时长（分钟，可填0）',
                keyboardType: TextInputType.number,
              ),
              _input(
                _weakSubjectsController,
                '薄弱科目（每行一个）',
                maxLines: 3,
                minLines: 2,
              ),
              _input(_targetDestinationController, '目标院校 / 证书'),
              _input(_notesController, '备注', maxLines: 3, minLines: 2),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _saveUserProfile(context, provider, profile),
                  icon: const Icon(Icons.save),
                  label: const Text('保存用户信息'),
                ),
              ),
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

  Widget _aiSettingsBody(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final agentProvider = context.watch<AIAgentProvider>();
    final status = provider.aiProviderStatus;
    final templates = provider.aiPromptTemplates;

    _syncProviderConfig(status);
    _syncPromptTemplate(templates);

    final selectedPrompt = _currentPromptConfig(templates);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _healthCard(context),
        _section(
          title: '模型服务状态',
          icon: Icons.cloud_done_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statusRow('当前生效服务商', status['provider']),
              _statusRow('已配置服务商', status['configured_provider']),
              _statusRow('当前生效模型', status['model']),
              _statusRow('已配置模型', status['configured_model']),
              _statusRow('可用', '${status['ready'] ?? false}'),
              _statusRow('是否降级Mock', '${status['fallback'] ?? false}'),
              _statusRow(
                '密钥状态',
                (status['has_api_key'] ?? false) ? '已配置' : '未配置',
              ),
              _statusRow('OpenAI Base URL', status['openai_base_url']),
            ],
          ),
        ),
        _section(
          title: '模型连接配置',
          icon: Icons.tune,
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
                  setState(() {
                    _selectedProvider = value;
                    _providerDirty = true;
                  });
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  focusNode: _modelFocusNode,
                  controller: _modelController,
                  decoration: InputDecoration(
                    labelText: '模型名称（自动获取 / 手动填写）',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      tooltip: '自动获取当前模型',
                      onPressed: () => _autoFetchModel(context, provider),
                      icon: const Icon(Icons.download_outlined),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _autoFetchModel(context, provider),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('自动获取当前模型'),
                ),
              ),
              _input(
                _openAIBaseURLController,
                'OpenAI 兼容 Base URL（可选）',
                focusNode: _openAIBaseURLFocusNode,
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '提示：Base URL 仅在 provider=openai 时生效。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
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
                      icon: Icon(
                        _showApiKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => _showApiKey = !_showApiKey);
                      },
                    ),
                  ),
                ),
              ),
              const Text(
                '提示：Token 不会在状态接口中回显。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _saveProviderConfig(context, provider),
                icon: const Icon(Icons.save),
                label: const Text('保存配置'),
              ),
            ],
          ),
        ),
        _agentConfigSection(context, agentProvider),
        _section(
          title: '高级功能：Prompt 模板配置',
          icon: Icons.auto_awesome,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '构建规则：定制Prompt/预置Prompt + 输出格式说明Prompt + 用户输入',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              if (templates.isEmpty)
                const Text('暂无模板，请先点击右上角刷新。')
              else ...[
                DropdownButtonFormField<String>(
                  value: _selectedPromptKey,
                  decoration: const InputDecoration(
                    labelText: 'AI功能项',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: templates
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: (item['key'] ?? '').toString(),
                          child: Text(
                            '${item['name'] ?? item['key'] ?? ''} (${item['key'] ?? ''})',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedPromptKey = value;
                      _promptDirty = false;
                      _applyPromptForm(_currentPromptConfig(templates));
                    });
                  },
                ),
                const SizedBox(height: 8),
                _readonlyMultiline(
                  label: '预置 Prompt（保底）',
                  value: (selectedPrompt?['preset_prompt'] ?? '').toString(),
                ),
                _readonlyMultiline(
                  label: '预置输出格式说明 Prompt（保底）',
                  value: (selectedPrompt?['preset_output_format_prompt'] ?? '')
                      .toString(),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '以下分段均可手动编辑。留空将回退到默认值；ai_memo / user_profile 允许为空。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                ..._buildPromptSegmentInputs(keys: _primaryPromptSegmentKeys),
                _input(
                  _outputPromptController,
                  '输出格式 (output_format，留空则使用预置)',
                  focusNode: _outputPromptFocusNode,
                  maxLines: 6,
                  minLines: 4,
                ),
                ExpansionTile(
                  key: ValueKey('prompt-advanced-${_selectedPromptKey ?? ''}'),
                  initiallyExpanded: _promptAdvancedExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _promptAdvancedExpanded = expanded;
                    });
                  },
                  title: const Text('高级分段编辑（可选）'),
                  subtitle: const Text('展开后可编辑其余分段'),
                  childrenPadding: const EdgeInsets.only(top: 8),
                  children: [
                    ..._buildPromptSegmentInputs(
                      keys: _editablePromptSegmentKeys
                          .where((key) => !_primaryPromptSegmentKeys.contains(key))
                          .toList(growable: false),
                    ),
                  ],
                ),
                _readonlyMultiline(
                  label: '用户输入 (user_input)',
                  value: '运行时注入，不持久化保存。',
                ),
                _readonlyMultiline(
                  label: '当前生效 Prompt',
                  value: (selectedPrompt?['effective_prompt'] ?? '').toString(),
                ),
                _readonlyMultiline(
                  label: '当前生效输出格式 Prompt',
                  value:
                      (selectedPrompt?['effective_output_format_prompt'] ?? '')
                          .toString(),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _savePromptTemplate(context, provider),
                      icon: const Icon(Icons.save),
                      label: const Text('保存并热更新'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          for (final controller
                              in _segmentPromptControllers.values) {
                            controller.clear();
                          }
                          _outputPromptController.clear();
                          _promptDirty = true;
                        });
                      },
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('清空为预置'),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _reloadPromptTemplates(context, provider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('从数据库重载'),
                    ),
                  ],
                ),
              ],
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

  Widget _agentConfigSection(
    BuildContext context,
    AIAgentProvider agentProvider,
  ) {
    final agents = agentProvider.agents;
    return _section(
      title: 'Agent 配置',
      icon: Icons.smart_toy_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () => agentProvider.refreshAgents(),
                icon: const Icon(Icons.refresh),
                label: const Text('刷新 Agent'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showAgentDialog(context, agentProvider),
                icon: const Icon(Icons.add),
                label: const Text('新增 Agent'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (agentProvider.loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),
          if (agents.isEmpty)
            const Text(
              '暂无 Agent，请先新增一个 OpenAI 兼容 Agent。',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...agents.map(
              (agent) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${agent.name} (${agent.protocol})'),
                subtitle: Text(
                  'primary=${agent.primary.model} fallback=${agent.fallback.model} enabled=${agent.enabled}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: '编辑 Agent',
                      onPressed: () => _showAgentDialog(
                        context,
                        agentProvider,
                        agent: agent,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: '删除 Agent',
                      onPressed: () =>
                          _confirmDeleteAgent(context, agentProvider, agent),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          if (agentProvider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Agent 错误：${agentProvider.errorMessage}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAgentDialog(
    BuildContext context,
    AIAgentProvider provider, {
    AIAgentSummary? agent,
  }) async {
    final isEdit = agent != null;
    final appProvider = context.read<AppProvider>();
    if (!context.mounted) {
      return;
    }
    var defaultAgentProvider = <String, dynamic>{};
    try {
      defaultAgentProvider = await appProvider.apiService
          .getAIDefaultAgentProvider();
    } catch (_) {
      defaultAgentProvider = <String, dynamic>{};
    }
    final draft = provider.createAgentDraft;
    final template = _preferredAgentTemplate(provider);
    final defaultPrimary =
        (defaultAgentProvider['primary'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final defaultProtocol = (defaultAgentProvider['protocol'] ?? '')
        .toString()
        .trim();
    final defaultModel = (defaultPrimary['model'] ?? '').toString().trim();
    final defaultBaseUrl = (defaultPrimary['base_url'] ?? '').toString().trim();
    final defaultApiKey = (defaultPrimary['api_key'] ?? '').toString().trim();

    final initialProtocol = isEdit
        ? agent.protocol
        : _firstNonEmpty([
            defaultProtocol,
            (draft['protocol'] ?? '').toString(),
            template?.protocol ?? '',
          ], fallback: 'openai_compatible');
    final initialPrimaryModel = isEdit
        ? (agent.primary.model.isNotEmpty ? agent.primary.model : 'gpt-4o-mini')
        : _firstNonEmpty([
            defaultModel,
            (draft['primary_model'] ?? '').toString(),
            template?.primary.model ?? '',
          ], fallback: 'gpt-4o-mini');
    final initialPrimaryBaseUrl = isEdit
        ? agent.primary.baseUrl
        : _firstNonEmpty([
            defaultBaseUrl,
            (draft['primary_base_url'] ?? '').toString(),
            template?.primary.baseUrl ?? '',
          ], fallback: 'https://api.openai.com/v1');
    final initialPrimaryApiKey = isEdit
        ? ''
        : _firstNonEmpty([
            defaultApiKey,
            (draft['primary_api_key'] ?? '').toString(),
            template?.primary.apiKey ?? '',
          ]);
    final initialFallbackBaseUrl = isEdit
        ? agent.fallback.baseUrl
        : _firstNonEmpty([
            (draft['fallback_base_url'] ?? '').toString(),
            template?.fallback.baseUrl ?? '',
          ]);
    final initialFallbackApiKey = isEdit
        ? ''
        : _firstNonEmpty([
            (draft['fallback_api_key'] ?? '').toString(),
            template?.fallback.apiKey ?? '',
          ]);
    final initialFallbackModel = isEdit
        ? agent.fallback.model
        : _firstNonEmpty([
            (draft['fallback_model'] ?? '').toString(),
            template?.fallback.model ?? '',
          ]);
    final initialSystemPrompt = isEdit
        ? agent.systemPrompt
        : _firstNonEmpty([
            (draft['system_prompt'] ?? '').toString(),
            template?.systemPrompt ?? '',
          ]);
    final initialSystemPromptSections = _splitAgentSystemPrompt(
      initialSystemPrompt,
    );
    final initialEnabled = isEdit
        ? agent.enabled
        : _asBool(draft['enabled'], fallback: template?.enabled ?? true);

    final nameController = TextEditingController(text: agent?.name ?? '');
    final protocolController = ValueNotifier<String>(initialProtocol);
    final primaryBaseUrlController = TextEditingController(
      text: initialPrimaryBaseUrl,
    );
    final primaryApiKeyController = TextEditingController(
      text: initialPrimaryApiKey,
    );
    final primaryModelController = TextEditingController(
      text: initialPrimaryModel,
    );
    final fallbackBaseUrlController = TextEditingController(
      text: initialFallbackBaseUrl,
    );
    final fallbackApiKeyController = TextEditingController(
      text: initialFallbackApiKey,
    );
    final fallbackModelController = TextEditingController(
      text: initialFallbackModel,
    );
    final systemPromptRoleController = TextEditingController(
      text: initialSystemPromptSections['role'] ?? '',
    );
    final systemPromptTaskController = TextEditingController(
      text: initialSystemPromptSections['task_prompt'] ?? '',
    );
    final systemPromptToolController = TextEditingController(
      text: initialSystemPromptSections['tool_instructions'] ?? '',
    );
    final systemPromptRulesController = TextEditingController(
      text: initialSystemPromptSections['rules'] ?? '',
    );
    final systemPromptExtraController = TextEditingController(
      text: initialSystemPromptSections['extra'] ?? '',
    );
    var enabled = initialEnabled;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(isEdit ? '编辑 Agent' : '新增 Agent'),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _input(nameController, 'Agent 名称'),
                      ValueListenableBuilder<String>(
                        valueListenable: protocolController,
                        builder: (context, protocol, _) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: DropdownButtonFormField<String>(
                              value: protocol,
                              decoration: const InputDecoration(
                                labelText: '协议',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'openai_compatible',
                                  child: Text('OpenAI 兼容'),
                                ),
                                DropdownMenuItem(
                                  value: 'gemini_native',
                                  child: Text('Gemini 原生'),
                                ),
                                DropdownMenuItem(
                                  value: 'claude_native',
                                  child: Text('Claude 原生'),
                                ),
                                DropdownMenuItem(
                                  value: 'mock',
                                  child: Text('Mock（本地）'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                protocolController.value = value;
                              },
                            ),
                          );
                        },
                      ),
                      _input(primaryModelController, '主模型'),
                      _input(primaryBaseUrlController, '主 Base URL'),
                      _input(
                        primaryApiKeyController,
                        isEdit ? '主 API Key（留空=保持不变）' : '主 API Key',
                      ),
                      _input(fallbackModelController, '备模型（可选）'),
                      _input(fallbackBaseUrlController, '备 Base URL（可选）'),
                      _input(
                        fallbackApiKeyController,
                        isEdit ? '备 API Key（留空=保持不变）' : '备 API Key（可选）',
                      ),
                      _input(
                        systemPromptRoleController,
                        'System Prompt - role/persona',
                        maxLines: 3,
                        minLines: 2,
                      ),
                      _input(
                        systemPromptTaskController,
                        'System Prompt - task_prompt',
                        maxLines: 6,
                        minLines: 3,
                      ),
                      _input(
                        systemPromptToolController,
                        'System Prompt - tool_instructions',
                        maxLines: 4,
                        minLines: 2,
                      ),
                      _input(
                        systemPromptRulesController,
                        'System Prompt - rules',
                        maxLines: 4,
                        minLines: 2,
                      ),
                      _input(
                        systemPromptExtraController,
                        'System Prompt - extra (optional)',
                        maxLines: 4,
                        minLines: 2,
                      ),
                      SwitchListTile(
                        value: enabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用'),
                        onChanged: (v) {
                          setState(() => enabled = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final protocol = protocolController.value.trim();
                    final primaryModel = primaryModelController.text.trim();
                    final primaryBaseUrl = primaryBaseUrlController.text.trim();
                    final primaryApiKey = primaryApiKeyController.text.trim();
                    final composedSystemPrompt = _composeAgentSystemPrompt(
                      role: systemPromptRoleController.text,
                      taskPrompt: systemPromptTaskController.text,
                      toolInstructions: systemPromptToolController.text,
                      rules: systemPromptRulesController.text,
                      extra: systemPromptExtraController.text,
                    );
                    if (name.isEmpty || primaryModel.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('名称和主模型不能为空')),
                      );
                      return;
                    }

                    try {
                      if (isEdit) {
                        await provider.updateAgent(
                          id: agent.id,
                          name: name,
                          protocol: protocol,
                          primaryBaseUrl: primaryBaseUrl,
                          primaryApiKey: primaryApiKey,
                          primaryModel: primaryModel,
                          fallbackBaseUrl: fallbackBaseUrlController.text
                              .trim(),
                          fallbackApiKey: fallbackApiKeyController.text.trim(),
                          fallbackModel: fallbackModelController.text.trim(),
                          systemPrompt: composedSystemPrompt,
                          enabled: enabled,
                        );
                      } else {
                        await provider.createAgent(
                          name: name,
                          protocol: protocol,
                          primaryBaseUrl: primaryBaseUrl,
                          primaryApiKey: primaryApiKey,
                          primaryModel: primaryModel,
                          fallbackBaseUrl: fallbackBaseUrlController.text
                              .trim(),
                          fallbackApiKey: fallbackApiKeyController.text.trim(),
                          fallbackModel: fallbackModelController.text.trim(),
                          systemPrompt: composedSystemPrompt,
                          enabled: enabled,
                        );
                      }
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                    } catch (_) {
                      if (!ctx.mounted) return;
                      final msg = provider.errorMessage ?? '保存 Agent 失败';
                      messenger.showSnackBar(SnackBar(content: Text(msg)));
                    }
                  },
                  child: Text(isEdit ? '保存' : '创建'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    protocolController.dispose();
    primaryBaseUrlController.dispose();
    primaryApiKeyController.dispose();
    primaryModelController.dispose();
    fallbackBaseUrlController.dispose();
    fallbackApiKeyController.dispose();
    fallbackModelController.dispose();
    systemPromptRoleController.dispose();
    systemPromptTaskController.dispose();
    systemPromptToolController.dispose();
    systemPromptRulesController.dispose();
    systemPromptExtraController.dispose();
  }

  Map<String, String> _splitAgentSystemPrompt(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const <String, String>{};
    }
    final hasHeaders = RegExp(r'^##\s+', multiLine: true).hasMatch(text);
    if (!hasHeaders) {
      return <String, String>{'task_prompt': text};
    }

    final buckets = <String, List<String>>{};
    String currentKey = 'extra';
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trimRight();
      final match = RegExp(r'^##\s+(.+)$').firstMatch(line.trim());
      if (match != null) {
        final normalized = _normalizeAgentPromptSectionKey(match.group(1) ?? '');
        currentKey = normalized.isEmpty ? 'extra' : normalized;
        buckets.putIfAbsent(currentKey, () => <String>[]);
        continue;
      }
      buckets.putIfAbsent(currentKey, () => <String>[]).add(line);
    }

    final out = <String, String>{};
    buckets.forEach((key, lines) {
      final value = lines.join('\n').trim();
      if (value.isNotEmpty) {
        out[key] = value;
      }
    });
    return out;
  }

  String _normalizeAgentPromptSectionKey(String raw) {
    final key = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9 _-]'), '')
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    switch (key) {
      case 'role':
      case 'persona':
      case 'identity':
        return 'role';
      case 'task_prompt':
      case 'task':
      case 'instructions':
      case 'instruction':
        return 'task_prompt';
      case 'tool_instructions':
      case 'tools':
      case 'tool':
        return 'tool_instructions';
      case 'rules':
      case 'rule':
        return 'rules';
      case 'extra':
        return 'extra';
      default:
        return '';
    }
  }

  String _composeAgentSystemPrompt({
    required String role,
    required String taskPrompt,
    required String toolInstructions,
    required String rules,
    required String extra,
  }) {
    final blocks = <String>[];
    final roleText = role.trim();
    final taskText = taskPrompt.trim();
    final toolText = toolInstructions.trim();
    final rulesText = rules.trim();
    final extraText = extra.trim();

    if (roleText.isNotEmpty) {
      blocks.add('## role\n$roleText');
    }
    if (taskText.isNotEmpty) {
      blocks.add('## task_prompt\n$taskText');
    }
    if (toolText.isNotEmpty) {
      blocks.add('## tool_instructions\n$toolText');
    }
    if (rulesText.isNotEmpty) {
      blocks.add('## rules\n$rulesText');
    }
    if (extraText.isNotEmpty) {
      blocks.add(extraText);
    }
    return blocks.join('\n\n').trim();
  }

  AIAgentSummary? _preferredAgentTemplate(AIAgentProvider provider) {
    if (provider.agents.isEmpty) {
      return null;
    }
    final selected = provider.selectedAgentId.trim();
    if (selected.isNotEmpty) {
      for (final item in provider.agents) {
        if (item.id == selected) {
          return item;
        }
      }
    }
    return provider.agents.first;
  }

  String _firstNonEmpty(List<String> values, {String fallback = ''}) {
    for (final item in values) {
      final text = item.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  bool _asBool(dynamic value, {bool fallback = true}) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return fallback;
  }

  Future<void> _confirmDeleteAgent(
    BuildContext context,
    AIAgentProvider provider,
    AIAgentSummary agent,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除 Agent'),
        content: Text('确认删除 Agent "${agent.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) {
      return;
    }
    try {
      await provider.deleteAgent(agent.id);
    } catch (_) {
      final msg = provider.errorMessage ?? '删除 Agent 失败';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Widget _readonlyMultiline({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: SelectableText(value.isEmpty ? '-' : value),
      ),
    );
  }

  Widget _statusRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              '${value ?? '-'}',
              style: const TextStyle(fontSize: 13),
            ),
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

  Widget _input(
    TextEditingController controller,
    String label, {
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    int? maxLines,
    int? minLines,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        focusNode: focusNode,
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
        minLines: minLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  List<Widget> _buildPromptSegmentInputs({List<String>? keys}) {
    final targetKeys = keys ?? _editablePromptSegmentKeys;
    final widgets = <Widget>[];
    for (final key in targetKeys) {
      final controller = _segmentPromptControllers[key];
      if (controller == null) {
        continue;
      }
      final label = _promptSegmentLabels[key] ?? key;
      final isOptional = _optionalPromptSegments.contains(key);
      final isTaskPrompt = key == 'task_prompt';
      widgets.add(
        _input(
          controller,
          isOptional ? '$label（可空）' : '$label（留空回退默认）',
          maxLines: isTaskPrompt ? 6 : 4,
          minLines: isTaskPrompt ? 3 : 2,
        ),
      );
    }
    return widgets;
  }

  Map<String, String> _asStringMap(dynamic value) {
    if (value is! Map) {
      return <String, String>{};
    }
    final out = <String, String>{};
    value.forEach((key, raw) {
      final normalizedKey = key.toString().trim();
      if (normalizedKey.isEmpty) {
        return;
      }
      out[normalizedKey] = raw?.toString() ?? '';
    });
    return out;
  }

  void _bindProfileDirtyListener(TextEditingController controller) {
    controller.addListener(() {
      if (_syncingProfileForm) return;
      _profileDirty = true;
    });
  }

  void _bindPromptDirtyListener(TextEditingController controller) {
    controller.addListener(() {
      if (_syncingPromptForm) return;
      _promptDirty = true;
    });
  }

  void _syncProfileForm(UserProfile? profile) {
    if (profile == null || _profileDirty) {
      return;
    }
    _syncingProfileForm = true;
    _nicknameController.text = profile.nickname;
    _ageController.text = profile.age <= 0 ? '' : '${profile.age}';
    _academicStatusController.text = profile.academicStatus;
    _goalsController.text = profile.goals.join('\n');
    _goalTargetDateController.text = profile.goalTargetDate;
    _dailyStudyMinutesController.text = '${profile.dailyStudyMinutes}';
    _weakSubjectsController.text = profile.weakSubjects.join('\n');
    _targetDestinationController.text = profile.targetDestination;
    _notesController.text = profile.notes;
    _selectedAcademicPreset =
        _academicStatusPresets.contains(profile.academicStatus)
        ? profile.academicStatus
        : _customAcademicStatus;
    _syncingProfileForm = false;
  }

  void _syncPromptTemplate(List<Map<String, dynamic>> templates) {
    if (templates.isEmpty) {
      _selectedPromptKey = null;
      _applyPromptForm(null);
      return;
    }

    final keyExists = templates.any(
      (item) => (item['key'] ?? '').toString() == _selectedPromptKey,
    );
    if (_selectedPromptKey == null || !keyExists) {
      _selectedPromptKey = (templates.first['key'] ?? '').toString();
      _promptDirty = false;
    }

    if (_promptDirty) return;
    if (_outputPromptFocusNode.hasFocus) {
      return;
    }
    _applyPromptForm(_currentPromptConfig(templates));
  }

  Map<String, dynamic>? _currentPromptConfig(
    List<Map<String, dynamic>> templates,
  ) {
    final key = _selectedPromptKey;
    if (key == null || key.isEmpty) {
      return null;
    }
    for (final item in templates) {
      if ((item['key'] ?? '').toString() == key) {
        return item;
      }
    }
    return null;
  }

  void _applyPromptForm(Map<String, dynamic>? config) {
    _syncingPromptForm = true;
    final overrides = _asStringMap(config?['segment_overrides']);
    final customPrompt = (config?['custom_prompt'] ?? '').toString().trim();
    if ((overrides['task_prompt'] ?? '').trim().isEmpty &&
        customPrompt.isNotEmpty) {
      overrides['task_prompt'] = customPrompt;
    }
    for (final key in _editablePromptSegmentKeys) {
      final controller = _segmentPromptControllers[key];
      if (controller == null) {
        continue;
      }
      controller.text = (overrides[key] ?? '').toString();
    }
    _outputPromptController.text = (config?['output_format_prompt'] ?? '')
        .toString();
    _syncingPromptForm = false;
  }

  List<String> _splitLines(String raw) {
    return raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _pickGoalTargetDate() async {
    final existingRaw = _goalTargetDateController.text.trim();
    DateTime initialDate = DateTime.now();
    if (existingRaw.isNotEmpty) {
      initialDate = DateTime.tryParse(existingRaw) ?? initialDate;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    final yyyy = picked.year.toString().padLeft(4, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    _goalTargetDateController.text = '$yyyy-$mm-$dd';
    _profileDirty = true;
  }

  Future<void> _saveUserProfile(
    BuildContext context,
    AppProvider provider,
    UserProfile? current,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    final dailyStudyMinutes =
        int.tryParse(_dailyStudyMinutesController.text.trim()) ?? 0;
    final goals = _splitLines(_goalsController.text);
    final weakSubjects = _splitLines(_weakSubjectsController.text);
    try {
      await provider.updateUserProfile(
        userId: current?.userId ?? 'default',
        nickname: _nicknameController.text.trim(),
        age: age,
        academicStatus: _academicStatusController.text.trim(),
        goals: goals,
        goalTargetDate: _goalTargetDateController.text.trim(),
        dailyStudyMinutes: dailyStudyMinutes,
        weakSubjects: weakSubjects,
        targetDestination: _targetDestinationController.text.trim(),
        notes: _notesController.text.trim(),
      );
      _profileDirty = false;
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('用户信息已保存')));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? '保存失败')),
      );
    }
  }

  Future<void> _saveProviderConfig(
    BuildContext context,
    AppProvider provider,
  ) async {
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
      _providerDirty = false;
      _apiKeyController.clear();
      if (!mounted) return;

      final updated = provider.aiProviderStatus;
      final activeProvider = (updated['provider'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final configuredProvider = (updated['configured_provider'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final fallback = updated['fallback'] == true;

      if (configuredProvider.isNotEmpty &&
          activeProvider.isNotEmpty &&
          configuredProvider != activeProvider) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '配置已保存（$configuredProvider），但当前生效是 $activeProvider；请检查 API Key/模型是否可用',
            ),
          ),
        );
      } else if (fallback) {
        messenger.showSnackBar(
          const SnackBar(content: Text('配置已保存，但当前处于 fallback 模式')),
        );
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('模型配置已更新')));
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? '更新失败')),
      );
    }
  }

  Future<void> _savePromptTemplate(
    BuildContext context,
    AppProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final key = _selectedPromptKey;
    if (key == null || key.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('请先选择AI功能项')));
      return;
    }
    try {
      final segmentUpdates = <String, String>{};
      for (final key in _editablePromptSegmentKeys) {
        final value = _segmentPromptControllers[key]?.text.trim() ?? '';
        if (value.isNotEmpty) {
          segmentUpdates[key] = value;
        }
      }
      await provider.updateAIPromptTemplate(
        key: key,
        outputFormatPrompt: _outputPromptController.text,
        segmentUpdates: segmentUpdates,
        replaceSegments: true,
      );
      _promptDirty = false;
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Prompt已保存并热更新')));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? '保存失败')),
      );
    }
  }

  Future<void> _reloadPromptTemplates(
    BuildContext context,
    AppProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.reloadAIPromptTemplates();
      if (!mounted) return;
      _promptDirty = false;
      _syncPromptTemplate(provider.aiPromptTemplates);
      setState(() {});
      messenger.showSnackBar(const SnackBar(content: Text('Prompt模板已从数据库重载')));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? '重载失败')),
      );
    }
  }

  Future<void> _autoFetchModel(
    BuildContext context,
    AppProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await provider.fetchAIProviderStatus(force: true);
    if (!mounted) return;

    final errorMessage = provider.errorMessage;
    if (errorMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    final status = provider.aiProviderStatus;
    final configuredProvider = (status['configured_provider'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final activeProvider = (status['provider'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final configuredModel = (status['configured_model'] ?? '')
        .toString()
        .trim();
    final activeModel = (status['model'] ?? '').toString().trim();
    final model = configuredModel.isNotEmpty ? configuredModel : activeModel;

    if (model.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('未获取到模型名称，请手动填写')));
      return;
    }

    if (model == 'mock-v1' &&
        configuredProvider.isNotEmpty &&
        configuredProvider != 'mock') {
      messenger.showSnackBar(
        const SnackBar(content: Text('当前处于mock回退，无法自动获取目标供应商模型，请手动填写')),
      );
      return;
    }

    _modelController.text = model;
    if (configuredProvider.isNotEmpty &&
        activeProvider.isNotEmpty &&
        configuredProvider != activeProvider) {
      messenger.showSnackBar(
        SnackBar(content: Text('已读取已配置模型：$model（当前生效供应商：$activeProvider）')),
      );
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text('已自动获取模型：$model')));
  }

  void _syncProviderConfig(Map<String, dynamic> status) {
    final configuredProvider =
        (status['configured_provider'] ?? status['provider'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (configuredProvider.isNotEmpty &&
        configuredProvider != _selectedProvider &&
        !_providerDirty &&
        (configuredProvider == 'mock' ||
            configuredProvider == 'openai' ||
            configuredProvider == 'gemini' ||
            configuredProvider == 'claude')) {
      _selectedProvider = configuredProvider;
    }
    if (!_modelFocusNode.hasFocus) {
      final model = (status['configured_model'] ?? status['model'] ?? '')
          .toString()
          .trim();
      if (model.isNotEmpty && _modelController.text.trim().isEmpty) {
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

  Widget _healthCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color color;
    final IconData icon;
    final String label;

    if (_checkingHealth) {
      color = Colors.grey;
      icon = Icons.sync;
      label = '检查中...';
    } else if (_backendHealthy == true) {
      color = Colors.green;
      icon = Icons.cloud_done;
      label = '后端连接正常';
    } else if (_backendHealthy == false) {
      color = Colors.red;
      icon = Icons.cloud_off;
      label = '后端连接失败';
    } else {
      color = Colors.grey;
      icon = Icons.cloud_queue;
      label = '未检测';
    }

    String? subtitle;
    if (_healthLatencyMs != null && _lastHealthCheck != null) {
      final time = _lastHealthCheck!;
      final hh = time.hour.toString().padLeft(2, '0');
      final mm = time.minute.toString().padLeft(2, '0');
      final ss = time.second.toString().padLeft(2, '0');
      subtitle = '延迟 ${_healthLatencyMs}ms · 上次检查 $hh:$mm:$ss';
    }

    return Card(
      color: color.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(fontSize: 12, color: cs.outline))
            : null,
        trailing: IconButton(
          icon: Icon(Icons.refresh, color: cs.outline),
          tooltip: '重新检测',
          onPressed: _checkBackendHealth,
        ),
      ),
    );
  }
}
