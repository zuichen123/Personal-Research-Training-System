import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_agent_chat.dart';
import '../providers/ai_agent_provider.dart';
import '../providers/app_provider.dart';
import '../widgets/ai_formula_text.dart';
import '../widgets/ai_multimodal_message_input.dart';
import 'ai_screen.dart';

class AgentChatHubScreen extends StatefulWidget {
  const AgentChatHubScreen({super.key});

  @override
  State<AgentChatHubScreen> createState() => _AgentChatHubScreenState();
}

class _AgentChatHubScreenState extends State<AgentChatHubScreen> {
  final Map<String, Set<int>> _questionSelections = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AIAgentProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AIAgentProvider>();
    final agents = provider.agents;

    if (provider.loading && agents.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (agents.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('多智能体对话'),
          actions: [
            IconButton(
              tooltip: '旧版 AI 工具台',
              icon: const Icon(Icons.build_circle_outlined),
              onPressed: _openLegacyAIScreen,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.psychology_outlined, size: 42),
                const SizedBox(height: 8),
                const Text('暂无已配置智能体'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _showCreateAgentDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('新建智能体'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedAgentIndex = _selectedAgentIndex(provider, agents);
    return DefaultTabController(
      key: ValueKey('${agents.length}_${provider.selectedAgentId}'),
      length: agents.length,
      initialIndex: selectedAgentIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('多智能体对话'),
          actions: [
            IconButton(
              tooltip: '新建智能体',
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateAgentDialog(context),
            ),
            IconButton(
              tooltip: '旧版 AI 工具台',
              icon: const Icon(Icons.build_circle_outlined),
              onPressed: _openLegacyAIScreen,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            onTap: (index) {
              context.read<AIAgentProvider>().selectAgent(agents[index].id);
            },
            tabs: agents
                .map(
                  (agent) => Tab(
                    text: agent.name,
                    icon: Icon(
                      agent.enabled ? Icons.smart_toy_outlined : Icons.block,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        body: Column(
          children: [
            if (provider.errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: agents
                    .map(
                      (agent) => _AgentTabPanel(
                        key: ValueKey('panel_${agent.id}'),
                        agent: agent,
                        questionSelections: _questionSelections,
                        onImportQuestions: _importQuestions,
                        onImportPlan: _importPlan,
                        onCompressSession: _compressCurrentSession,
                        onDeleteAgent: () => _deleteAgent(agent),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _selectedAgentIndex(
    AIAgentProvider provider,
    List<AIAgentSummary> agents,
  ) {
    final idx = agents.indexWhere(
      (item) => item.id == provider.selectedAgentId,
    );
    if (idx >= 0) {
      return idx;
    }
    return 0;
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

  void _openLegacyAIScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AIScreen()));
  }

  Future<void> _showCreateAgentDialog(BuildContext context) async {
    final agentProvider = context.read<AIAgentProvider>();
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
    final draft = agentProvider.createAgentDraft;
    final template = _preferredAgentTemplate(agentProvider);
    final defaultPrimary =
        (defaultAgentProvider['primary'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final defaultProtocol = (defaultAgentProvider['protocol'] ?? '')
        .toString()
        .trim();
    final defaultModel = (defaultPrimary['model'] ?? '').toString().trim();
    final defaultBaseUrl = (defaultPrimary['base_url'] ?? '').toString().trim();
    final defaultApiKey = (defaultPrimary['api_key'] ?? '').toString().trim();

    final initialProtocol = _firstNonEmpty([
      defaultProtocol,
      (draft['protocol'] ?? '').toString(),
      template?.protocol ?? '',
    ], fallback: 'openai_compatible');
    final initialPrimaryModel = _firstNonEmpty([
      defaultModel,
      (draft['primary_model'] ?? '').toString(),
      template?.primary.model ?? '',
    ], fallback: 'gpt-4o-mini');
    final initialPrimaryBaseUrl = _firstNonEmpty([
      defaultBaseUrl,
      (draft['primary_base_url'] ?? '').toString(),
      template?.primary.baseUrl ?? '',
    ], fallback: 'https://api.openai.com/v1');
    final initialPrimaryApiKey = _firstNonEmpty([
      defaultApiKey,
      (draft['primary_api_key'] ?? '').toString(),
      template?.primary.apiKey ?? '',
    ]);
    final initialFallbackModel = _firstNonEmpty([
      (draft['fallback_model'] ?? '').toString(),
      template?.fallback.model ?? '',
    ]);
    final initialFallbackApiKey = _firstNonEmpty([
      (draft['fallback_api_key'] ?? '').toString(),
      template?.fallback.apiKey ?? '',
    ]);
    final initialFallbackBaseUrl = _firstNonEmpty([
      (draft['fallback_base_url'] ?? '').toString(),
      template?.fallback.baseUrl ?? '',
    ]);
    final initialPrompt = _firstNonEmpty([
      (draft['system_prompt'] ?? '').toString(),
      template?.systemPrompt ?? '',
    ]);
    final initialEnabled = _asBool(
      draft['enabled'],
      fallback: template?.enabled ?? true,
    );

    final nameController = TextEditingController();
    final primaryModelController = TextEditingController(
      text: initialPrimaryModel,
    );
    final primaryApiKeyController = TextEditingController(
      text: initialPrimaryApiKey,
    );
    final primaryBaseUrlController = TextEditingController(
      text: initialPrimaryBaseUrl,
    );
    final fallbackModelController = TextEditingController(
      text: initialFallbackModel,
    );
    final fallbackApiKeyController = TextEditingController(
      text: initialFallbackApiKey,
    );
    final fallbackBaseUrlController = TextEditingController(
      text: initialFallbackBaseUrl,
    );
    final promptController = TextEditingController(text: initialPrompt);
    var protocol = initialProtocol;
    var enabled = initialEnabled;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('新建智能体'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogInput(nameController, '智能体名称'),
                  DropdownButtonFormField<String>(
                    value: protocol,
                    decoration: const InputDecoration(
                      labelText: '协议',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'openai_compatible',
                        child: Text('OpenAI 兼容'),
                      ),
                      DropdownMenuItem(value: 'mock', child: Text('Mock（本地）')),
                      DropdownMenuItem(
                        value: 'gemini_native',
                        child: Text('Gemini 原生'),
                      ),
                      DropdownMenuItem(
                        value: 'claude_native',
                        child: Text('Claude 原生'),
                      ),
                    ],
                    onChanged: (value) {
                      protocol = value ?? 'openai_compatible';
                    },
                  ),
                  const SizedBox(height: 8),
                  _dialogInput(primaryModelController, '主模型'),
                  _dialogInput(primaryApiKeyController, '主 API Key'),
                  _dialogInput(primaryBaseUrlController, '主 Base URL'),
                  const SizedBox(height: 8),
                  _dialogInput(fallbackModelController, '备模型（可选）'),
                  _dialogInput(fallbackApiKeyController, '备 API Key（可选）'),
                  _dialogInput(fallbackBaseUrlController, '备 Base URL（可选）'),
                  const SizedBox(height: 8),
                  _dialogInput(promptController, '系统提示词', maxLines: 3),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: enabled,
                    title: const Text('启用'),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) {
                      enabled = v;
                      (ctx as Element).markNeedsBuild();
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
                try {
                  await context.read<AIAgentProvider>().createAgent(
                    name: nameController.text.trim(),
                    protocol: protocol,
                    primaryBaseUrl: primaryBaseUrlController.text.trim(),
                    primaryApiKey: primaryApiKeyController.text.trim(),
                    primaryModel: primaryModelController.text.trim(),
                    fallbackBaseUrl: fallbackBaseUrlController.text.trim(),
                    fallbackApiKey: fallbackApiKeyController.text.trim(),
                    fallbackModel: fallbackModelController.text.trim(),
                    systemPrompt: promptController.text.trim(),
                    enabled: enabled,
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                } catch (_) {
                  if (!ctx.mounted) return;
                  final msg =
                      context.read<AIAgentProvider>().errorMessage ?? '创建智能体失败';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAgent(AIAgentSummary agent) async {
    final provider = context.read<AIAgentProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('删除智能体'),
          content: Text('确认删除智能体 "${agent.name}"？'),
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
        );
      },
    );
    if (confirmed != true) return;
    await provider.deleteAgent(agent.id);
  }

  Future<void> _importQuestions(
    AIAgentArtifact artifact,
    List<int> selectedIndexes,
  ) async {
    final provider = context.read<AIAgentProvider>();
    final appProvider = context.read<AppProvider>();
    final result = await provider.importArtifactQuestions(
      artifact.id,
      selectedIndexes: selectedIndexes,
    );
    await appProvider.fetchQuestions(force: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导入 ${result['imported_count'] ?? 0} 道题目')),
    );
  }

  Future<void> _importPlan(AIAgentArtifact artifact) async {
    final provider = context.read<AIAgentProvider>();
    final appProvider = context.read<AppProvider>();
    final result = await provider.importArtifactPlan(artifact.id);
    await appProvider.fetchPlans(force: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导入 ${result['imported_count'] ?? 0} 条计划')),
    );
  }

  Future<void> _compressCurrentSession() async {
    final provider = context.read<AIAgentProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await provider.compressCurrentSession(trigger: 'manual');
      if (!mounted) return;
      final status = (result['status'] ?? 'skipped').toString();
      final summarized = (result['summarized_count'] ?? 0).toString();
      final updatedAt = (result['summary_updated_at'] ?? '').toString();
      final text = status == 'compressed'
          ? '已压缩 $summarized 条消息${updatedAt.isEmpty ? '' : '（$updatedAt）'}'
          : '本次无需压缩';
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } catch (_) {
      if (!mounted) return;
      final msg = provider.errorMessage ?? '压缩失败';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Widget _dialogInput(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

class _AgentTabPanel extends StatefulWidget {
  const _AgentTabPanel({
    super.key,
    required this.agent,
    required this.questionSelections,
    required this.onImportQuestions,
    required this.onImportPlan,
    required this.onCompressSession,
    required this.onDeleteAgent,
  });

  final AIAgentSummary agent;
  final Map<String, Set<int>> questionSelections;
  final Future<void> Function(
    AIAgentArtifact artifact,
    List<int> selectedIndexes,
  )
  onImportQuestions;
  final Future<void> Function(AIAgentArtifact artifact) onImportPlan;
  final Future<void> Function() onCompressSession;
  final VoidCallback onDeleteAgent;

  @override
  State<_AgentTabPanel> createState() => _AgentTabPanelState();
}

class _AgentTabPanelState extends State<_AgentTabPanel> {
  final TextEditingController _scheduleThemeController =
      TextEditingController();
  String _scheduleMode = 'auto';
  bool _scheduleAutoEnabled = true;
  Set<String> _scheduleManualPlanIds = <String>{};
  String _scheduleSessionId = '';
  bool _scheduleSaving = false;

  @override
  void dispose() {
    _scheduleThemeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AIAgentProvider>();
    final appProvider = context.watch<AppProvider>();
    final sessions = provider.sessionsOf(widget.agent.id);
    final selectedSessionId = provider.selectedSessionIdOf(widget.agent.id);
    final selectedBinding = selectedSessionId.trim().isEmpty
        ? const <String, dynamic>{}
        : provider.scheduleBindingOf(selectedSessionId);
    _syncScheduleBindingState(selectedSessionId, selectedBinding);

    if (selectedSessionId.trim().isNotEmpty &&
        !appProvider.isSectionLoaded(DataSection.plans) &&
        !appProvider.isSectionLoading(DataSection.plans)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<AppProvider>().ensurePlansLoaded();
      });
    }

    final messages = provider.messagesOf(selectedSessionId);
    final artifacts = provider.artifactsOf(selectedSessionId);
    final artifactsByMessage = <String, AIAgentArtifact>{};
    for (final item in artifacts) {
      artifactsByMessage[item.messageId] = item;
    }

    final isWide = MediaQuery.sizeOf(context).width >= 960;
    final sessionList = _buildSessionPanel(
      context,
      provider,
      appProvider,
      sessions,
      selectedSessionId,
    );
    final chatPanel = _buildChatPanel(
      context,
      provider,
      messages,
      artifactsByMessage,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: isWide
          ? Row(
              children: [
                SizedBox(width: 300, child: sessionList),
                const SizedBox(width: 10),
                Expanded(child: chatPanel),
              ],
            )
          : Column(
              children: [
                sessionList,
                const SizedBox(height: 10),
                Expanded(child: chatPanel),
              ],
            ),
    );
  }

  Widget _buildSessionPanel(
    BuildContext context,
    AIAgentProvider provider,
    AppProvider appProvider,
    List<AIAgentSession> sessions,
    String selectedSessionId,
  ) {
    AIAgentSession? selectedSession;
    for (final session in sessions) {
      if (session.id == selectedSessionId) {
        selectedSession = session;
        break;
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.agent.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: '删除智能体',
                  onPressed: widget.onDeleteAgent,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(
              '协议: ${widget.agent.protocol}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () {
                provider.createSession(
                  title: '会话 ${DateTime.now().toIso8601String()}',
                );
              },
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('新建会话'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: provider.sending || selectedSession == null
                  ? null
                  : widget.onCompressSession,
              icon: const Icon(Icons.compress_outlined),
              label: const Text('压缩当前会话'),
            ),
            if (selectedSession != null) ...[
              const SizedBox(height: 10),
              _buildScheduleBindingPanel(
                context,
                provider,
                appProvider,
                selectedSession,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      '摘要消息 ${selectedSession.summaryMessageCount}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      selectedSession.summaryUpdatedAt == null
                          ? '摘要未生成'
                          : '摘要更新时间 ${selectedSession.summaryUpdatedAt!.toLocal()}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('暂无会话'),
              )
            else
              ...sessions.map(
                (session) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  selected: session.id == selectedSessionId,
                  title: Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    session.updatedAt.toLocal().toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: '删除会话',
                    onPressed: () => provider.deleteSession(session.id),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                  onTap: () => provider.selectSession(session.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleBindingPanel(
    BuildContext context,
    AIAgentProvider provider,
    AppProvider appProvider,
    AIAgentSession session,
  ) {
    final plans = appProvider.plans;
    final matchedPlans = provider.matchedPlansOf(session.id);
    final isManual = _scheduleMode == 'manual';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当前日程绑定',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _scheduleMode,
            decoration: const InputDecoration(
              labelText: '模式',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('自动')),
              DropdownMenuItem(value: 'manual', child: Text('手动')),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _scheduleMode = value);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _scheduleThemeController,
            decoration: const InputDecoration(
              labelText: '主题（可选）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            value: _scheduleAutoEnabled,
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('启用自动主题匹配'),
            onChanged: (value) {
              setState(() => _scheduleAutoEnabled = value);
            },
          ),
          if (isManual) ...[
            const SizedBox(height: 4),
            if (plans.isEmpty)
              const Text(
                '暂无可选计划，请先在计划管理中创建计划。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: plans
                    .map((item) {
                      final selected = _scheduleManualPlanIds.contains(item.id);
                      final title = item.title.trim().isEmpty
                          ? item.id
                          : item.title.trim();
                      return FilterChip(
                        selected: selected,
                        label: Text(title, overflow: TextOverflow.ellipsis),
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _scheduleManualPlanIds.add(item.id);
                            } else {
                              _scheduleManualPlanIds.remove(item.id);
                            }
                          });
                        },
                      );
                    })
                    .toList(growable: false),
              ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _scheduleSaving
                    ? null
                    : () => _saveScheduleBinding(context, provider, session.id),
                icon: _scheduleSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('保存绑定'),
              ),
              const SizedBox(width: 8),
              if (!appProvider.isSectionLoaded(DataSection.plans))
                OutlinedButton.icon(
                  onPressed: appProvider.isSectionLoading(DataSection.plans)
                      ? null
                      : () =>
                            context.read<AppProvider>().fetchPlans(force: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('加载计划'),
                ),
            ],
          ),
          if (matchedPlans.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '匹配计划 (${matchedPlans.length})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ...matchedPlans.take(5).map((item) {
              final title = (item['title'] ?? '').toString().trim();
              final date = (item['target_date'] ?? '').toString().trim();
              final status = (item['status'] ?? '').toString().trim();
              final note = <String>[
                if (date.isNotEmpty) date,
                if (status.isNotEmpty) status,
              ].join(' | ');
              return Text(
                '- ${title.isEmpty ? (item['id'] ?? '').toString() : title}'
                '${note.isEmpty ? '' : ' ($note)'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _saveScheduleBinding(
    BuildContext context,
    AIAgentProvider provider,
    String sessionId,
  ) async {
    if (sessionId.trim().isEmpty) {
      return;
    }
    setState(() => _scheduleSaving = true);
    try {
      await provider.updateSessionScheduleBinding(
        sessionId: sessionId,
        mode: _scheduleMode,
        theme: _scheduleThemeController.text.trim(),
        manualPlanIds: _scheduleManualPlanIds.toList(growable: false),
        autoEnabled: _scheduleAutoEnabled,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('会话日程绑定已保存')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      final msg = provider.errorMessage ?? '保存会话日程绑定失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (!mounted) {
        return;
      }
      setState(() => _scheduleSaving = false);
    }
  }

  void _syncScheduleBindingState(
    String selectedSessionId,
    Map<String, dynamic> binding,
  ) {
    final normalizedSessionId = selectedSessionId.trim();
    if (normalizedSessionId.isEmpty) {
      _scheduleSessionId = '';
      _scheduleMode = 'auto';
      _scheduleAutoEnabled = true;
      _scheduleManualPlanIds = <String>{};
      if (_scheduleThemeController.text.isNotEmpty) {
        _scheduleThemeController.text = '';
      }
      return;
    }
    if (_scheduleSessionId == normalizedSessionId) {
      return;
    }
    _scheduleSessionId = normalizedSessionId;
    final mode = (binding['mode'] ?? '').toString().trim().toLowerCase();
    _scheduleMode = mode == 'manual' ? 'manual' : 'auto';
    _scheduleAutoEnabled = _asLocalBool(binding['auto_enabled'], true);
    _scheduleThemeController.text = (binding['theme'] ?? '').toString().trim();
    final rawManual =
        (binding['manual_plan_ids'] as List?) ?? const <dynamic>[];
    _scheduleManualPlanIds = rawManual
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  bool _asLocalBool(dynamic value, bool fallback) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
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

  Widget _buildChatPanel(
    BuildContext context,
    AIAgentProvider provider,
    List<AIAgentMessage> messages,
    Map<String, AIAgentArtifact> artifactsByMessage,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    return Card(
      child: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('暂无消息'))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final artifact = artifactsByMessage[message.id];
                      return _messageTile(context, provider, message, artifact);
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: AIMultimodalMessageInput(
              sending: provider.sending,
              hintText: '输入消息...',
              sendLabel: '发送',
              onSend: (text, attachments) async {
                try {
                  await provider.sendMessage(
                    text,
                    attachments: attachments
                        .map((item) => item.toJson())
                        .toList(growable: false),
                  );
                } catch (_) {
                  if (!mounted) return;
                  final msg = provider.errorMessage ?? '发送失败';
                  messenger.showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageTile(
    BuildContext context,
    AIAgentProvider provider,
    AIAgentMessage message,
    AIAgentArtifact? artifact,
  ) {
    final isUser = message.role == 'user';
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final messenger = ScaffoldMessenger.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AIFormulaText(message.content, selectable: true),
                if (!isUser &&
                    (message.providerUsed.isNotEmpty ||
                        message.modelUsed.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '服务商=${message.providerUsed} 模型=${message.modelUsed}${message.fallbackUsed ? '（备份）' : ''}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          if (!isUser &&
              message.pendingConfirmation != null &&
              message.pendingConfirmation!.action.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FilledButton.tonalIcon(
                onPressed: provider.sending
                    ? null
                    : () async {
                        try {
                          await provider.confirmAction(
                            messageId: message.id,
                            action: message.pendingConfirmation!.action,
                            params: message.pendingConfirmation!.params,
                          );
                        } catch (_) {
                          if (!mounted) return;
                          final msg = provider.errorMessage ?? '确认失败';
                          messenger.showSnackBar(SnackBar(content: Text(msg)));
                        }
                      },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('确认执行'),
              ),
            ),
          if (!isUser && artifact != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _artifactCard(context, artifact),
            ),
        ],
      ),
    );
  }

  Widget _artifactCard(BuildContext context, AIAgentArtifact artifact) {
    if (artifact.type == 'question_set') {
      final items = (artifact.payload['items'] as List?) ?? const <dynamic>[];
      final selected =
          widget.questionSelections[artifact.id] ??
          Set<int>.from(List<int>.generate(items.length, (i) => i));
      widget.questionSelections[artifact.id] = selected;

      return Container(
        constraints: const BoxConstraints(maxWidth: 760),
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
            Text(
              '题目产物（${items.length}）',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...List.generate(items.length, (index) {
              final map = (items[index] as Map?)?.cast<dynamic, dynamic>();
              final title = (map?['title'] ?? map?['stem'] ?? '题目').toString();
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: selected.contains(index),
                title: AIFormulaText(
                  '${index + 1}. $title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      selected.add(index);
                    } else {
                      selected.remove(index);
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      await widget.onImportQuestions(
                        artifact,
                        selected.toList()..sort(),
                      );
                    },
              icon: const Icon(Icons.download_done_outlined),
              label: const Text('导入选中题目'),
            ),
          ],
        ),
      );
    }

    if (artifact.type == 'learning_plan') {
      final plan =
          (artifact.payload['plan'] as Map?)?.cast<dynamic, dynamic>() ??
          artifact.payload;
      final finalGoal = (plan['final_goal'] ?? '-').toString();
      final startDate = (plan['plan_start_date'] ?? '-').toString();
      final endDate = (plan['plan_end_date'] ?? '-').toString();
      return Container(
        constraints: const BoxConstraints(maxWidth: 760),
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
            const Text('学习计划产物', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            AIFormulaText('目标：$finalGoal', selectable: true),
            Text('周期：$startDate ~ $endDate'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => widget.onImportPlan(artifact),
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              label: const Text('导入计划条目'),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 760),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('产物类型：${artifact.type}'),
    );
  }
}
