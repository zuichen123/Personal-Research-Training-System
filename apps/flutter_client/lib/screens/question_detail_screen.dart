import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('#${widget.questionNumber} ${q.subject}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─ 题目信息卡片 ─
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.quiz_outlined, size: 20, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          q.title.isEmpty ? '题目' : q.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(q.stem, style: theme.textTheme.bodyLarge),
                  if (q.options.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...q.options.map(
                      (o) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                o.key,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onPrimaryContainer,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(o.text)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _infoChip('难度 ${q.difficulty}', _difficultyColor(q.difficulty)),
                      _infoChip('掌握 ${q.masteryLevel}%', cs.secondary),
                      _infoChip(_typeZh(q.type), cs.tertiary),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─ 作答区 ─
          TextField(
            controller: _answerController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '你的答案',
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

  Widget _infoChip(String label, Color color) {
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide.none,
    );
  }

  Widget _resultCard(BuildContext context, Map<String, dynamic> result) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final score = result['score'];
    final correct = result['correct'];
    final feedback = result['feedback']?.toString() ?? '';
    final wrongReason = result['wrong_reason']?.toString() ?? '';
    final suggestions = result['suggestions'];
    final pretty = const JsonEncoder.withIndent('  ').convert(result);

    final scoreNum = (score is num) ? score.toDouble() : 0.0;
    final scoreColor = scoreNum >= 80
        ? Colors.green
        : scoreNum >= 60
            ? Colors.orange
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 标题行 ──
            Row(
              children: [
                Icon(Icons.grading, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  '批阅结果',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // 复制按钮
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: pretty));
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.copy, size: 16, color: cs.outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── 分数 + 正误 ──
            Row(
              children: [
                // 分数圆
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scoreColor.withValues(alpha: 0.12),
                    border: Border.all(color: scoreColor, width: 2.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    score != null ? '$score' : '-',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 判定
                if (correct != null)
                  Chip(
                    avatar: Icon(
                      correct == true ? Icons.check_circle : Icons.cancel,
                      color: correct == true ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    label: Text(correct == true ? '正确' : '错误'),
                    backgroundColor: (correct == true ? Colors.green : Colors.red)
                        .withValues(alpha: 0.1),
                    side: BorderSide.none,
                  ),
              ],
            ),

            // ── 反馈 ──
            if (feedback.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '反馈',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(feedback),
                  ],
                ),
              ),
            ],

            // ── 错误原因 ──
            if (wrongReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '错误原因',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(wrongReason),
                  ],
                ),
              ),
            ],

            // ── 建议 ──
            if (suggestions != null &&
                suggestions is List &&
                suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '改进建议',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...suggestions.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontSize: 14)),
                            Expanded(child: SelectableText('$s')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── 原始 JSON 折叠 ──
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                title: Text(
                  '查看原始数据',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      pretty,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
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

  Color _difficultyColor(int difficulty) {
    if (difficulty <= 1) return Colors.green;
    if (difficulty == 2) return Colors.lightGreen;
    if (difficulty == 3) return Colors.orange;
    if (difficulty == 4) return Colors.deepOrange;
    return Colors.red;
  }

  String _typeZh(String raw) {
    switch (raw) {
      case 'single_choice':
        return '单选题';
      case 'multi_choice':
        return '多选题';
      case 'short_answer':
        return '简答题';
      default:
        return raw;
    }
  }
}
