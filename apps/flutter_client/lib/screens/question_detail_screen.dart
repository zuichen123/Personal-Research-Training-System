import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../models/question.dart';
import '../providers/app_provider.dart';

enum _AnswerMode { text, math, photo, handwriting }

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

class _QuestionDetailScreenState extends State<QuestionDetailScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  // Text answer
  final TextEditingController _textController = TextEditingController();

  // Math answer
  final TextEditingController _mathController = TextEditingController();

  // Photo answer
  XFile? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  // Handwriting answer
  late final SignatureController _signatureController;

  // State
  bool _submitting = false;
  bool _hasResult = false;
  Map<String, dynamic>? _gradeResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black87,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _mathController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${widget.questionNumber}  ${q.subject}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _sourceZh(q.source),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          Chip(
            label: Text(
              '难度 ${q.difficulty}',
              style: TextStyle(
                fontSize: 11,
                color: _difficultyColor(q.difficulty),
              ),
            ),
            side: BorderSide(color: _difficultyColor(q.difficulty)),
            backgroundColor: _difficultyColor(q.difficulty).withValues(alpha: 0.08),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Stem ──────────────────────────────────────────────
          _StemCard(question: q),

          // ── Answer tabs ───────────────────────────────────────
          _AnswerTabBar(controller: _tabController),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _TextAnswerPanel(controller: _textController),
                _MathAnswerPanel(controller: _mathController),
                _PhotoAnswerPanel(
                  pickedImage: _pickedImage,
                  onPick: _pickImage,
                  onRemove: () => setState(() => _pickedImage = null),
                ),
                _HandwritingPanel(controller: _signatureController),
              ],
            ),
          ),

          // ── Result area ───────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _hasResult && _gradeResult != null
                ? _GradeResultCard(result: _gradeResult!)
                : const SizedBox.shrink(),
          ),

          // ── Submit button ─────────────────────────────────────
          _SubmitBar(
            submitting: _submitting,
            hasResult: _hasResult,
            onSubmit: _submit,
            onReset: _reset,
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────

  Future<void> _pickImage({required bool fromCamera}) async {
    final file = fromCamera
        ? await _picker.pickImage(source: ImageSource.camera, imageQuality: 85)
        : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) {
      setState(() => _pickedImage = file);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    // Capture context-derived objects before any async gap
    final provider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);

    void showMsg(String msg) =>
        messenger.showSnackBar(SnackBar(content: Text(msg)));

    final mode = _AnswerMode.values[_tabController.index];
    String answerText = '';

    switch (mode) {
      case _AnswerMode.text:
        answerText = _textController.text.trim();
        if (answerText.isEmpty) {
          showMsg('请输入文字答�?);
          return;
        }
      case _AnswerMode.math:
        answerText = _mathController.text.trim();
        if (answerText.isEmpty) {
          showMsg('请输入数学公式或答案');
          return;
        }
      case _AnswerMode.photo:
        if (_pickedImage == null) {
          showMsg('请先拍照或选择图片');
          return;
        }
        answerText = '[图片答案]';
      case _AnswerMode.handwriting:
        if (_signatureController.isEmpty) {
          showMsg('请先书写答案');
          return;
        }
        answerText = '[手写答案]';
    }

    setState(() => _submitting = true);

    try {
      final gradeInput = <String, dynamic>{
        'question': _toAIQuestionPayload(widget.question),
        'user_answer': [answerText],
      };

      await provider.gradeWithAI(gradeInput);

      // Also record as practice attempt
      await provider.submitPractice(
        widget.question.id,
        [answerText],
      );

      if (mounted) {
        setState(() {
          _hasResult = true;
          _gradeResult = provider.aiGradeResult;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showMsg('提交失败�?e');
      }
    }
  }

  void _reset() {
    setState(() {
      _hasResult = false;
      _gradeResult = null;
      _textController.clear();
      _mathController.clear();
      _pickedImage = null;
      _signatureController.clear();
    });
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
  Color _difficultyColor(int d) {
    if (d <= 1) return Colors.green;
    if (d == 2) return Colors.lightGreen;
    if (d == 3) return Colors.orange;
    if (d == 4) return Colors.deepOrange;
    return Colors.red;
  }

  String _sourceZh(String raw) {
    const m = {
      'wrong_book': '错题�?,
      'past_exam': '历年真题',
      'paper': '试卷',
      'unit_test': '单元测试',
      'ai_generated': 'AI生成',
    };
    return m[raw] ?? raw;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StemCard extends StatelessWidget {
  const _StemCard({required this.question});
  final Question question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = question.title.isNotEmpty ? question.title : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '题干',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _typeZh(question.type),
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
          ],
          SelectableText(
            question.stem,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          if (question.options.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...question.options.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        o.key.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(o.text, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _typeZh(String t) {
    const m = {
      'single_choice': '单选题',
      'multi_choice': '多选题',
      'short_answer': '简答题',
    };
    return m[t] ?? t;
  }
}

class _AnswerTabBar extends StatelessWidget {
  const _AnswerTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.primary,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
        labelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(icon: Icon(Icons.text_fields, size: 18), text: '文本'),
          Tab(icon: Icon(Icons.functions, size: 18), text: '数学'),
          Tab(icon: Icon(Icons.camera_alt, size: 18), text: '拍照'),
          Tab(icon: Icon(Icons.draw, size: 18), text: '手写'),
        ],
      ),
    );
  }
}

// ── Text panel ───────────────────────────────────────────────────────────────

class _TextAnswerPanel extends StatelessWidget {
  const _TextAnswerPanel({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          hintText: '在此输入你的答案�?,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.all(14),
        ),
        style: const TextStyle(fontSize: 15, height: 1.6),
      ),
    );
  }
}

// ── Math panel ───────────────────────────────────────────────────────────────

class _MathAnswerPanel extends StatelessWidget {
  const _MathAnswerPanel({required this.controller});
  final TextEditingController controller;

  static const _symbols = [
    ('π', 'π'), ('�?, '�?'), ('�?, '�?), ('²', '²'), ('³', '³'),
    ('½', '1/2'), ('�?, '1/3'), ('¼', '1/4'),
    ('×', '×'), ('÷', '÷'), ('±', '±'), ('�?, '�?),
    ('�?, '�?), ('�?, '�?), ('�?, '�?), ('�?, '�?),
    ('�?, 'Σ'), ('�?, '�?), ('�?, '�?), ('�?, 'Δ'),
    ('sin', 'sin('), ('cos', 'cos('), ('tan', 'tan('), ('log', 'log('),
    ('ln', 'ln('), ('lim', 'lim'), ('�?, '�?), ('^', '^'),
  ];

  void _insert(String text) {
    final sel = controller.selection;
    final cur = controller.text;
    final start = sel.start < 0 ? cur.length : sel.start;
    final end = sel.end < 0 ? cur.length : sel.end;
    final newText = cur.substring(0, start) + text + cur.substring(end);
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '在此输入数学答案（可插入符号�?,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(14),
            ),
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _symbols.map((pair) {
              return InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _insert(pair.$2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    pair.$1,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Photo panel ──────────────────────────────────────────────────────────────

class _PhotoAnswerPanel extends StatelessWidget {
  const _PhotoAnswerPanel({
    required this.pickedImage,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? pickedImage;
  final Future<void> Function({required bool fromCamera}) onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: pickedImage == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 64,
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => onPick(fromCamera: true),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('拍照'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => onPick(fromCamera: false),
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('从相册选择'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '拍摄或上传你的答题纸，AI 将识别并批阅',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(pickedImage!.path),
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.white),
                      onPressed: onRemove,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: FilledButton.icon(
                    onPressed: () => onPick(fromCamera: true),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('重新拍照'),
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Handwriting panel ────────────────────────────────────────────────────────

class _HandwritingPanel extends StatelessWidget {
  const _HandwritingPanel({required this.controller});
  final SignatureController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Signature(
                controller: controller,
                backgroundColor: theme.brightness == Brightness.dark
                    ? Colors.grey.shade900
                    : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '用手指或触控笔书写你的答�?,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              TextButton.icon(
                onPressed: controller.clear,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清除', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Grade result card ────────────────────────────────────────────────────────

class _GradeResultCard extends StatelessWidget {
  const _GradeResultCard({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Try to parse common fields from the AI result
    final score = result['score'] ?? result['Score'];
    final correct = result['correct'] ?? result['is_correct'];
    final feedback =
        result['feedback'] ?? result['suggestion'] ?? result['advice'] ?? '';
    final isCorrect = correct == true || correct == 1 || correct == 'true';

    final accentColor = isCorrect ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.info_outline,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                isCorrect ? '答对了！' : 'AI 批阅结果',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const Spacer(),
              if (score != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '得分�?score',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (feedback.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              feedback.toString(),
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Submit bar ───────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.submitting,
    required this.hasResult,
    required this.onSubmit,
    required this.onReset,
  });

  final bool submitting;
  final bool hasResult;
  final VoidCallback onSubmit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      child: Row(
        children: [
          if (hasResult) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.replay),
                label: const Text('重新作答'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: hasResult ? null : (submitting ? null : onSubmit),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      hasResult ? '已提�? : '提交答案',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}


