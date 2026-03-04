import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_agent_chat.dart';
import '../providers/ai_agent_provider.dart';
import '../providers/app_provider.dart';
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
  void dispose() {
    super.dispose();
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
          title: const Text('Agent Chat Hub'),
          actions: [
            IconButton(
              tooltip: 'Legacy AI Tools',
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
                const Text('No agents configured yet.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _showCreateAgentDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Agent'),
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
          title: const Text('Agent Chat Hub'),
          actions: [
            IconButton(
              tooltip: 'Create Agent',
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateAgentDialog(context),
            ),
            IconButton(
              tooltip: 'Legacy AI Tools',
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

  void _openLegacyAIScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AIScreen()));
  }

  Future<void> _showCreateAgentDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final primaryModelController = TextEditingController(text: 'gpt-4o-mini');
    final primaryApiKeyController = TextEditingController();
    final primaryBaseUrlController = TextEditingController(
      text: 'https://api.openai.com/v1',
    );
    final fallbackModelController = TextEditingController();
    final fallbackApiKeyController = TextEditingController();
    final fallbackBaseUrlController = TextEditingController();
    final promptController = TextEditingController();
    var protocol = 'openai_compatible';
    var enabled = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create Agent'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogInput(nameController, 'Agent Name'),
                  DropdownButtonFormField<String>(
                    value: protocol,
                    decoration: const InputDecoration(
                      labelText: 'Protocol',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'openai_compatible',
                        child: Text('openai_compatible'),
                      ),
                      DropdownMenuItem(value: 'mock', child: Text('mock')),
                      DropdownMenuItem(
                        value: 'gemini_native',
                        child: Text('gemini_native'),
                      ),
                      DropdownMenuItem(
                        value: 'claude_native',
                        child: Text('claude_native'),
                      ),
                    ],
                    onChanged: (value) {
                      protocol = value ?? 'openai_compatible';
                    },
                  ),
                  const SizedBox(height: 8),
                  _dialogInput(primaryModelController, 'Primary Model'),
                  _dialogInput(primaryApiKeyController, 'Primary API Key'),
                  _dialogInput(primaryBaseUrlController, 'Primary Base URL'),
                  const SizedBox(height: 8),
                  _dialogInput(fallbackModelController, 'Fallback Model'),
                  _dialogInput(fallbackApiKeyController, 'Fallback API Key'),
                  _dialogInput(fallbackBaseUrlController, 'Fallback Base URL'),
                  const SizedBox(height: 8),
                  _dialogInput(promptController, 'System Prompt', maxLines: 3),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: enabled,
                    title: const Text('Enabled'),
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
              child: const Text('Cancel'),
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
                      context.read<AIAgentProvider>().errorMessage ??
                      'Create agent failed';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: const Text('Create'),
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
          title: const Text('Delete Agent'),
          content: Text('Delete agent "${agent.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
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
      SnackBar(
        content: Text('Imported ${result['imported_count'] ?? 0} questions'),
      ),
    );
  }

  Future<void> _importPlan(AIAgentArtifact artifact) async {
    final provider = context.read<AIAgentProvider>();
    final appProvider = context.read<AppProvider>();
    final result = await provider.importArtifactPlan(artifact.id);
    await appProvider.fetchPlans(force: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imported ${result['imported_count'] ?? 0} plans'),
      ),
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
          ? 'Compressed $summarized messages${updatedAt.isEmpty ? '' : ' at $updatedAt'}'
          : 'Compression skipped';
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } catch (_) {
      if (!mounted) return;
      final msg = provider.errorMessage ?? 'Compress failed';
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
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AIAgentProvider>();
    final sessions = provider.sessionsOf(widget.agent.id);
    final selectedSessionId = provider.selectedSessionIdOf(widget.agent.id);
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
                  tooltip: 'Delete Agent',
                  onPressed: widget.onDeleteAgent,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(
              'protocol: ${widget.agent.protocol}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () {
                provider.createSession(
                  title: 'Session ${DateTime.now().toIso8601String()}',
                );
              },
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('New Session'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: provider.sending || selectedSession == null
                  ? null
                  : widget.onCompressSession,
              icon: const Icon(Icons.compress_outlined),
              label: const Text('Compress Session'),
            ),
            if (selectedSession != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      'summary ${selectedSession.summaryMessageCount}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      selectedSession.summaryUpdatedAt == null
                          ? 'summary never'
                          : 'summary ${selectedSession.summaryUpdatedAt!.toLocal().toString()}',
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
                child: Text('No sessions yet'),
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
                    tooltip: 'Delete Session',
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
                ? const Center(child: Text('No messages'))
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Send a message...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: provider.sending
                      ? null
                      : () async {
                          final text = _inputController.text.trim();
                          if (text.isEmpty) return;
                          _inputController.clear();
                          try {
                            await provider.sendMessage(text);
                          } catch (_) {
                            if (!mounted) return;
                            final msg = provider.errorMessage ?? 'Send failed';
                            messenger.showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                          }
                        },
                  icon: provider.sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Send'),
                ),
              ],
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
                Text(message.content),
                if (!isUser &&
                    (message.providerUsed.isNotEmpty ||
                        message.modelUsed.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'provider=${message.providerUsed} model=${message.modelUsed}${message.fallbackUsed ? ' (fallback)' : ''}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          if (!isUser && message.pendingConfirmation != null)
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
                          final msg = provider.errorMessage ?? 'Confirm failed';
                          messenger.showSnackBar(SnackBar(content: Text(msg)));
                        }
                      },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm Action'),
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
              'Question Artifact (${items.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...List.generate(items.length, (index) {
              final map = (items[index] as Map?)?.cast<dynamic, dynamic>();
              final title = (map?['title'] ?? map?['stem'] ?? 'Question')
                  .toString();
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: selected.contains(index),
                title: Text(
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
              label: const Text('Import Selected Questions'),
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
            const Text(
              'Learning Plan Artifact',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('Goal: $finalGoal'),
            Text('Date: $startDate ~ $endDate'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => widget.onImportPlan(artifact),
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              label: const Text('Import Plan Items'),
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
      child: Text('Artifact type: ${artifact.type}'),
    );
  }
}
