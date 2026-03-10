import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ai_agent_chat.dart';
import '../../providers/ai_agent_provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/ai_formula_text.dart';
import '../../widgets/ai_multimodal_message_input.dart';

class CourseLessonSessionScreen extends StatefulWidget {
  const CourseLessonSessionScreen({
    super.key,
    required this.lessonTitle,
    required this.lessonTopic,
    required this.agentId,
    required this.sessionId,
    required this.sessionTitle,
  });

  final String lessonTitle;
  final String lessonTopic;
  final String agentId;
  final String sessionId;
  final String sessionTitle;

  @override
  State<CourseLessonSessionScreen> createState() =>
      _CourseLessonSessionScreenState();
}

class _CourseLessonSessionScreenState extends State<CourseLessonSessionScreen> {
  static const String _autoOpeningPrompt =
      '请作为本节课智能助教先发起课堂开场白，先说明本节课主题、学习目标和上课流程，然后邀请学生开始。';

  final ScrollController _scrollController = ScrollController();
  bool _preparing = true;
  bool _sending = false;
  bool _autoOpeningTriggered = false;
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareSession();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _prepareSession() async {
    final provider = context.read<AIAgentProvider>();
    try {
      await provider.selectAgent(widget.agentId);
      await provider.selectSession(widget.sessionId);
      await _ensureAutoOpeningMessage(provider);
    } catch (_) {
      // keep provider error state
    } finally {
      if (mounted) {
        setState(() => _preparing = false);
      }
    }
  }

  Future<void> _ensureAutoOpeningMessage(AIAgentProvider provider) async {
    if (_autoOpeningTriggered) {
      return;
    }
    final messages = provider.messagesOf(widget.sessionId);
    final hasAssistant = messages.any(
      (item) => item.role.trim().toLowerCase() == 'assistant',
    );
    if (hasAssistant) {
      _autoOpeningTriggered = true;
      return;
    }
    final hasKickoffUser = messages.any(
      (item) =>
          item.role.trim().toLowerCase() == 'user' &&
          item.content.trim() == _autoOpeningPrompt,
    );
    if (hasKickoffUser) {
      _autoOpeningTriggered = true;
      return;
    }
    _autoOpeningTriggered = true;
    await provider.sendMessage(_autoOpeningPrompt);
    _scrollToBottom();
  }

  Future<void> _send(
    String text,
    List<AIChatAttachmentPayload> attachments,
  ) async {
    final normalizedText = text.trim();
    if ((normalizedText.isEmpty && attachments.isEmpty) || _sending) {
      return;
    }
    setState(() => _sending = true);
    final provider = context.read<AIAgentProvider>();
    try {
      await provider.selectAgent(widget.agentId);
      await provider.selectSession(widget.sessionId);
      await provider.sendMessage(
        normalizedText,
        attachments: attachments.map((item) => item.toJson()).toList(),
      );
      _scrollToBottom();
    } catch (_) {
      // keep provider error message
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _endClass() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('结束上课'),
        content: const Text('确认结束本节课并生成家庭作业？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final appProvider = context.read<AppProvider>();
    try {
      await appProvider.generateAIQuestions({
        'topic': widget.lessonTopic,
        'subject': 'general',
        'scope': 'unit',
        'count': 3,
        'difficulty': 3,
      }, persist: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('家庭作业已生成')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$e')),
      );
    }
  }

  String _formatElapsed(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AIAgentProvider>();
    final messages = provider
        .messagesOf(widget.sessionId)
        .where(
          (item) =>
              !(item.role.trim().toLowerCase() == 'user' &&
                  item.content.trim() == _autoOpeningPrompt),
        )
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.lessonTitle} · 已上课 ${_formatElapsed(_elapsedSeconds)}'),
        actions: [
          IconButton(
            onPressed: _prepareSession,
            tooltip: '刷新会话',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _endClass,
            tooltip: '结束上课',
            icon: const Icon(Icons.exit_to_app),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '主题：${widget.lessonTopic}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                provider.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_preparing && messages.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final item = messages[index];
                  return _MessageBubble(message: item);
                },
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: AIMultimodalMessageInput(
                sending: _sending || provider.sending,
                hintText: '输入要发送给上课助教的内容...',
                sendLabel: '发送',
                onSend: _send,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AIAgentMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role.trim().toLowerCase() == 'user';
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: isUser
              ? cs.primaryContainer.withValues(alpha: 0.7)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AIFormulaText(message.content, selectable: true),
      ),
    );
  }
}
