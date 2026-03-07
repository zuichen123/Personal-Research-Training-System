import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ai_agent_chat.dart';
import '../../providers/ai_agent_provider.dart';
import '../../widgets/ai_formula_text.dart';

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
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _preparing = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareSession();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _prepareSession() async {
    final provider = context.read<AIAgentProvider>();
    try {
      await provider.selectAgent(widget.agentId);
      await provider.selectSession(widget.sessionId);
    } catch (_) {
      // keep provider error state
    } finally {
      if (mounted) {
        setState(() => _preparing = false);
      }
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    final provider = context.read<AIAgentProvider>();
    try {
      await provider.selectAgent(widget.agentId);
      await provider.selectSession(widget.sessionId);
      await provider.sendMessage(text);
      _inputController.clear();
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AIAgentProvider>();
    final messages = provider.messagesOf(widget.sessionId);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.lessonTitle} · 上课会话'),
        actions: [
          IconButton(
            onPressed: _prepareSession,
            tooltip: '刷新会话',
            icon: const Icon(Icons.refresh),
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '输入要发送给上课助教的内容',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: (_sending || provider.sending) ? null : _send,
                    icon: (_sending || provider.sending)
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('发送'),
                  ),
                ],
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
