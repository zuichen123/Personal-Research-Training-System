import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../providers/app_provider.dart';
import '../widgets/ai_formula_text.dart';
import '../widgets/ai_multimodal_message_input.dart'
    show AIChatAttachmentPayload;
import '../widgets/practice_multimodal_answer_input.dart';

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
  final Set<String> _selectedOptions = <String>{};
  final List<AIChatAttachmentPayload> _attachments =
      <AIChatAttachmentPayload>[];
  bool _submitting = false;
  Map<String, dynamic>? _gradeResult;
  DateTime _answerStartedAt = DateTime.now();
  int _draftResetToken = 0;

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
                        child: AIFormulaText(
                          q.title.isEmpty ? '题目' : q.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AIFormulaText(q.stem, style: theme.textTheme.bodyLarge),
                  if (q.options.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    if (_isSingleChoice(q))
                      ...q.options.map((option) {
                        return RadioListTile<String>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: option.key,
                          groupValue: _selectedOptions.isEmpty
                              ? null
                              : _selectedOptions.first,
                          title: AIFormulaText('${option.key}. ${option.text}'),
                          onChanged: _submitting
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _selectedOptions
                                      ..clear()
                                      ..add(value);
                                  });
                                },
                        );
                      }),
                    if (_isMultiChoice(q))
                      ...q.options.map((option) {
                        final checked = _selectedOptions.contains(option.key);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: checked,
                          title: AIFormulaText('${option.key}. ${option.text}'),
                          onChanged: _submitting
                              ? null
                              : (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedOptions.add(option.key);
                                    } else {
                                      _selectedOptions.remove(option.key);
                                    }
                                  });
                                },
                        );
                      }),
                    if (!_isChoiceQuestion(q))
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
                              Expanded(child: AIFormulaText(o.text)),
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
                      _infoChip(
                        '难度 ${q.difficulty}',
                        _difficultyColor(q.difficulty),
                      ),
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
          PracticeMultimodalAnswerInput(
            key: ValueKey('question-detail-answer-${q.id}'),
            controller: _answerController,
            attachments: _attachments,
            onAttachmentsChanged: (next) =>
                setState(() => _replaceAttachments(next)),
            enabled: !_submitting,
            labelText: _isChoiceQuestion(q) ? '补充说明（可选）' : '你的答案',
            hintText: _isChoiceQuestion(q)
                ? '可补充思路、易错点或要求 AI 重点关注的地方'
                : '可直接输入答案，也可附图、语音或手写内容',
            minLines: 4,
            maxLines: 8,
            resetKey: _draftResetToken,
            showCameraButton: true,
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
                        setState(() {
                          _clearDraft();
                          _gradeResult = null;
                        });
                      },
                child: const Text('清空'),
              ),
            ],
          ),
          if (_submitting || _gradeResult != null) ...[
            const SizedBox(height: 16),
            if (_submitting)
              _aiGeneratingCard()
            else
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

  Widget _aiGeneratingCard() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AIFormulaText(
                'AI 正在生成中...',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(BuildContext context, Map<String, dynamic> result) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final score = result['score'];
    final correct = result['correct'];
    final isCorrect = correct == true;
    final analysis = _extractAnalysisText(result);
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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
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
                    backgroundColor:
                        (correct == true ? Colors.green : Colors.red)
                            .withValues(alpha: 0.1),
                    side: BorderSide.none,
                  ),
              ],
            ),

            const SizedBox(height: 12),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: isCorrect,
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '题目解析',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.primary,
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AIFormulaText(
                      analysis.isEmpty ? '暂无题目解析' : analysis,
                      selectable: true,
                    ),
                  ),
                ],
              ),
            ),

            // ── 错误原因 ──
            if (wrongReason.isNotEmpty && !isCorrect) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
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
                    AIFormulaText(wrongReason, selectable: true),
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
                            Expanded(
                              child: AIFormulaText('$s', selectable: true),
                            ),
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
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
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
    final gradeAnswers = _collectGradeAnswers(widget.question);
    if (gradeAnswers.isEmpty && _attachments.isEmpty) {
      _showSnack('请先输入答案、选择选项或添加附件');
      return;
    }

    final practiceAnswers = [...gradeAnswers];
    _appendAnswersUnique(
      practiceAnswers,
      _attachments.map((item) => '[${item.source}] ${item.name}'),
    );

    setState(() => _submitting = true);
    final provider = context.read<AppProvider>();

    try {
      final payload = <String, dynamic>{
        'question': _toAIQuestionPayload(widget.question),
        'user_answer': gradeAnswers,
        if (_attachments.isNotEmpty)
          'attachments': _attachments.map((item) => item.toJson()).toList(),
      };
      final elapsedSeconds = DateTime.now()
          .difference(_answerStartedAt)
          .inSeconds
          .clamp(0, 1 << 30);
      await provider.gradeWithAI(payload);
      await provider.submitPractice(
        widget.question.id,
        practiceAnswers,
        elapsedSeconds,
      );
      if (!mounted) return;
      setState(() {
        _gradeResult = provider.aiGradeResult;
        _answerStartedAt = DateTime.now();
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

  void _replaceAttachments(List<AIChatAttachmentPayload> next) {
    _attachments
      ..clear()
      ..addAll(next);
  }

  void _clearDraft() {
    _answerController.clear();
    _selectedOptions.clear();
    _attachments.clear();
    _draftResetToken += 1;
    _answerStartedAt = DateTime.now();
  }

  List<String> _collectGradeAnswers(Question question) {
    final combined = <String>[];
    if (_isChoiceQuestion(question)) {
      final ordered = question.options
          .map((item) => item.key)
          .where(_selectedOptions.contains)
          .toList(growable: false);
      if (ordered.isNotEmpty) {
        _appendAnswersUnique(combined, ordered);
      } else if (_selectedOptions.isNotEmpty) {
        final fallback = _selectedOptions.toList(growable: true)..sort();
        _appendAnswersUnique(combined, fallback);
      }
    }
    _appendAnswersUnique(combined, _parseAnswers(_answerController.text));
    return combined;
  }

  void _appendAnswersUnique(List<String> out, Iterable<String> source) {
    for (final item in source) {
      final normalized = item.trim();
      if (normalized.isEmpty || out.contains(normalized)) {
        continue;
      }
      out.add(normalized);
    }
  }

  List<String> _parseAnswers(String raw) {
    return raw
        .split(RegExp(r'[\n,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  bool _isChoiceQuestion(Question question) {
    return _isSingleChoice(question) || _isMultiChoice(question);
  }

  bool _isSingleChoice(Question question) {
    final raw = question.type.trim();
    final normalized = _normalizeQuestionType(raw);
    return normalized == 'singlechoice' ||
        normalized == 'single' ||
        normalized == 'radio' ||
        raw.contains('单选');
  }

  bool _isMultiChoice(Question question) {
    final raw = question.type.trim();
    final normalized = _normalizeQuestionType(raw);
    return normalized == 'multichoice' ||
        normalized == 'multiplechoice' ||
        normalized == 'multiple' ||
        normalized == 'multi' ||
        raw.contains('多选');
  }

  String _normalizeQuestionType(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
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

  String _extractAnalysisText(Map<String, dynamic> result) {
    final candidates = [result['analysis'], result['explanation']];
    for (final item in candidates) {
      final text = item?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }
}
