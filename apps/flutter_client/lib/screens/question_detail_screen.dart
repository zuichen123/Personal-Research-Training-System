import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../providers/app_provider.dart';

class QuestionDetailScreen extends StatefulWidget {
  const QuestionDetailScreen({
    super.key,
    required this.question,
    required this.questionNumber,
  });

  final Question question;
  final int questionNumber;

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  final TextEditingController _answerController = TextEditingController();
  bool _submitting = false;
  Map<String, dynamic>? _gradeResult;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('#${widget.questionNumber} ${q.subject}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            q.title.isEmpty ? '题目' : q.title,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(q.stem, style: theme.textTheme.bodyLarge),
          if (q.options.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...q.options.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${o.key}. ${o.text}'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _answerController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '你的答案',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_submitting ? '提交中...' : '提交批阅'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () {
                        _answerController.clear();
                        setState(() => _gradeResult = null);
                      },
                child: const Text('清空'),
              ),
            ],
          ),
          if (_gradeResult != null) ...[
            const SizedBox(height: 16),
            _resultCard(context, _gradeResult!),
          ],
        ],
      ),
    );
  }

  Widget _resultCard(BuildContext context, Map<String, dynamic> result) {
    final score = result['score'];
    final feedback = result['feedback']?.toString() ?? '';
    final wrongReason = result['wrong_reason']?.toString() ?? '';
    final pretty = const JsonEncoder.withIndent('  ').convert(result);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('批阅结果', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('得分: ${score ?? '-'}'),
            if (feedback.isNotEmpty) Text('反馈: $feedback'),
            if (wrongReason.isNotEmpty) Text('问题: $wrongReason'),
            const SizedBox(height: 8),
            SelectableText(
              pretty,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      _showSnack('请先输入答案');
      return;
    }

    setState(() => _submitting = true);
    final provider = context.read<AppProvider>();

    try {
      final payload = <String, dynamic>{
        'question': _toAIQuestionPayload(widget.question),
        'user_answer': [answer],
      };
      await provider.gradeWithAI(payload);
      await provider.submitPractice(widget.question.id, [answer]);
      if (!mounted) return;
      setState(() {
        _gradeResult = provider.aiGradeResult;
      });
    } catch (_) {
      if (!mounted) return;
      _showSnack(provider.errorMessage ?? '提交失败');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Map<String, dynamic> _toAIQuestionPayload(Question q) {
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

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
