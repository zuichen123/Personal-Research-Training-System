import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../models/question.dart';
import '../providers/app_provider.dart';

enum AIScreenFocusSection { none, generate, grade }

class AIScreen extends StatefulWidget {
  const AIScreen({
    super.key,
    this.focusSection = AIScreenFocusSection.none,
  });

  final AIScreenFocusSection focusSection;

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final _learnModeController = TextEditingController(
    text: 'long_term_learning',
  );
  final _learnSubjectController = TextEditingController(text: 'math');
  final _learnUnitController = TextEditingController(text: '函数');
  final _learnGoalsController = TextEditingController(text: '夯实基础,完成阶段测试');
  final _learnFinalGoalController = TextEditingController();
  final _learnTotalHoursController = TextEditingController(text: '120');
  final _learnStartDateController = TextEditingController();
  final _learnEndDateController = TextEditingController();
  final _learnStatusController = TextEditingController(text: 'pending');
  final _learnThemesController = TextEditingController(text: '数学,英语');
  final _learnSupplementController = TextEditingController();

  final _optimizeDaysController = TextEditingController(text: '3');
  final _optimizeReasonController = TextEditingController();
  String _optimizeAction = 'postpone';

  final _genTopicController = TextEditingController(text: '函数单调性');
  final _genSubjectController = TextEditingController(text: 'math');
  final _genCountController = TextEditingController(text: '3');
  final _genDifficultyController = TextEditingController(text: '3');
  bool _persist = false;

  final _searchTopicController = TextEditingController(text: '函数单调性');
  final _searchSubjectController = TextEditingController(text: 'math');
  final _searchCountController = TextEditingController(text: '5');

  final _scoreTopicController = TextEditingController(text: '函数');
  final _accuracyController = TextEditingController(text: '80');
  final _stabilityController = TextEditingController(text: '70');
  final _speedController = TextEditingController(text: '75');

  final _gradeQuestionIdController = TextEditingController();
  final _gradeAnswerController = TextEditingController();

  final _evaluateModeController = TextEditingController(text: 'comprehensive');
  final _evaluateQuestionIdController = TextEditingController();
  final _evaluateAnswerController = TextEditingController();
  final _evaluateContextController = TextEditingController(text: '错题复盘');

  final Map<String, bool> _expanded = {};
  final Map<String, Set<String>> _generatedSelections = {};
  final Map<String, TextEditingController> _generatedSupplementControllers = {};
  final Map<String, Map<String, dynamic>> _generatedGradeResults = {};
  final Map<String, bool> _generatedSubmitting = {};
  final Map<String, SignatureController> _generatedSignatureControllers = {};
  final Map<String, bool> _generatedEraserMode = {};
  final Map<String, List<_AnswerImageAttachment>> _generatedAttachments = {};

  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _generateSectionKey = GlobalKey();
  final GlobalKey _gradeSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _learnStartDateController.text = _formatDate(now);
    _learnEndDateController.text = _formatDate(
      now.add(const Duration(days: 90)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToFocusedSection();
    });
  }

  @override
  void dispose() {
    _learnModeController.dispose();
    _learnSubjectController.dispose();
    _learnUnitController.dispose();
    _learnGoalsController.dispose();
    _learnFinalGoalController.dispose();
    _learnTotalHoursController.dispose();
    _learnStartDateController.dispose();
    _learnEndDateController.dispose();
    _learnStatusController.dispose();
    _learnThemesController.dispose();
    _learnSupplementController.dispose();
    _optimizeDaysController.dispose();
    _optimizeReasonController.dispose();
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
    _scrollController.dispose();
    _clearGeneratedPracticeState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 能力')),
      body: _aiBody(context),
    );
  }

  Widget _aiBody(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _learningSection(context, provider),
        _generateSection(provider),
        _searchSection(provider),
        _scoreSection(provider),
        _gradeSection(context, provider),
        _evaluateSection(provider),
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '错误: ${provider.errorMessage}',
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _learningSection(BuildContext context, AppProvider provider) {
    return _section(
      title: 'AI学习计划',
      icon: Icons.school_outlined,
      child: Column(
        children: [
          _input(_learnFinalGoalController, '最终目标（如：高考数学130+）'),
          _input(_learnTotalHoursController, '总投入小时（可空，AI估算）'),
          Row(
            children: [
              Expanded(
                child: _input(
                  _learnStartDateController,
                  '开始日期',
                  readOnly: true,
                ),
              ),
              IconButton(
                onPressed: () => _pickDate(_learnStartDateController),
                icon: const Icon(Icons.event),
              ),
              Expanded(
                child: _input(_learnEndDateController, '结束日期', readOnly: true),
              ),
              IconButton(
                onPressed: () => _pickDate(_learnEndDateController),
                icon: const Icon(Icons.event_available),
              ),
            ],
          ),
          _input(_learnStatusController, '当前状态（pending/in_progress）'),
          _input(_learnSubjectController, '主科目（如：math）'),
          _input(_learnThemesController, '主题（逗号分隔，如：数学,英语）'),
          _input(_learnUnitController, '当前单元'),
          _input(_learnModeController, '模式（long_term_learning/unit_review）'),
          _input(_learnGoalsController, '阶段目标（逗号分隔）'),
          _input(_learnSupplementController, '补充信息（可选）'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  await _runProviderAction(() {
                    return provider.buildLearningPlan({
                      'final_goal': _learnFinalGoalController.text.trim(),
                      'total_hours':
                          int.tryParse(
                            _learnTotalHoursController.text.trim(),
                          ) ??
                          0,
                      'start_date': _learnStartDateController.text.trim(),
                      'end_date': _learnEndDateController.text.trim(),
                      'current_status': _learnStatusController.text.trim(),
                      'mode': _learnModeController.text.trim(),
                      'subject': _learnSubjectController.text.trim(),
                      'unit': _learnUnitController.text.trim(),
                      'goals': _learnGoalsController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      'themes': _learnThemesController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      'supplement': _learnSupplementController.text.trim(),
                    });
                  });
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('生成学习计划'),
              ),
              FilledButton.tonalIcon(
                onPressed: provider.aiLearningPlan == null
                    ? null
                    : () async {
                        await _runProviderAction(() {
                          return provider.optimizeLearningPlan(
                            action: _optimizeAction,
                            days:
                                int.tryParse(
                                  _optimizeDaysController.text.trim(),
                                ) ??
                                0,
                            reason: _optimizeReasonController.text.trim(),
                            supplement: _learnSupplementController.text.trim(),
                          );
                        });
                      },
                icon: const Icon(Icons.tune),
                label: const Text('优化日程'),
              ),
              OutlinedButton.icon(
                onPressed: provider.aiLearningPlan == null
                    ? null
                    : () async {
                        try {
                          final imported = await provider
                              .importLearningPlanToPlans();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已导入 $imported 条计划')),
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          final message = provider.errorMessage ?? '导入失败';
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        }
                      },
                icon: const Icon(Icons.playlist_add_check),
                label: const Text('导入计划管理'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _optimizeAction,
                  decoration: const InputDecoration(
                    labelText: '优化动作',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'postpone', child: Text('推迟执行')),
                    DropdownMenuItem(value: 'advance', child: Text('提前执行')),
                    DropdownMenuItem(
                      value: 'complete_early',
                      child: Text('提前完成'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _optimizeAction = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _input(_optimizeDaysController, '调整天数')),
            ],
          ),
          _input(_optimizeReasonController, '调整原因（如：考试冲突）'),
          if (provider.aiLearningPlan != null) ...[
            _learningSummary(provider.aiLearningPlan!),
            _jsonBox('learn', provider.aiLearningPlan!),
          ],
        ],
      ),
    );
  }

  Widget _learningSummary(Map<String, dynamic> plan) {
    final follow = _asStringList(plan['follow_up_questions']);
    final missing = _asStringList(plan['missing_fields']);
    final hints = _asStringList(plan['optimization_hints']);
    final planItems = plan['plan_items'];
    final planItemCount = planItems is List ? planItems.length : 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('计划目标: ${plan['final_goal'] ?? '-'}'),
          Text(
            '计划周期: ${plan['plan_start_date'] ?? '-'} ~ ${plan['plan_end_date'] ?? '-'}',
          ),
          Text('计划条目: $planItemCount'),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('待补充字段: ${missing.join(', ')}'),
          ],
          if (follow.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('AI追问建议:'),
            ...follow.map((e) => Text('• $e')),
          ],
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('优化提示:'),
            ...hints.map((e) => Text('• $e')),
          ],
        ],
      ),
    );
  }

  Widget _generateSection(AppProvider provider) {
    return _section(
      key: _generateSectionKey,
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
              await _runProviderAction(() {
                return provider.generateAIQuestions({
                  'topic': _genTopicController.text.trim(),
                  'subject': _genSubjectController.text.trim(),
                  'scope': 'unit',
                  'count': int.tryParse(_genCountController.text.trim()) ?? 3,
                  'difficulty':
                      int.tryParse(_genDifficultyController.text.trim()) ?? 3,
                }, persist: _persist);
              });
              if (!mounted) return;
              setState(_clearGeneratedPracticeState);
            },
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('开始出题'),
          ),
          const SizedBox(height: 8),
          Text('生成题目数量: ${provider.aiGeneratedQuestions.length}'),
          _generatedPracticeSection(provider),
        ],
      ),
    );
  }

  Widget _generatedPracticeSection(AppProvider provider) {
    final questions = provider.aiGeneratedQuestions;
    if (questions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'AI题目实战',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ...List.generate(
          questions.length,
          (index) => _generatedQuestionCard(provider, questions[index], index),
        ),
      ],
    );
  }

  Widget _generatedQuestionCard(
    AppProvider provider,
    Question question,
    int index,
  ) {
    final qKey = _generatedQuestionKey(index);
    final selected = _generatedSelections[qKey] ?? <String>{};
    final noteController =
        _generatedSupplementControllers[qKey] ??= TextEditingController();
    final result = _generatedGradeResults[qKey];
    final submitting = _generatedSubmitting[qKey] == true;
    final attachments =
        _generatedAttachments[qKey] ?? const <_AnswerImageAttachment>[];
    final signatureController = _generatedSignatureControllers[qKey] ??=
        SignatureController(
          penStrokeWidth: 2.4,
          penColor: Colors.black,
          exportBackgroundColor: Colors.white,
        );

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ${question.title.isEmpty ? question.stem : question.title}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (question.title.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(question.stem),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Chip(
                  label: Text(
                    question.type,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '答案关键点: ${question.answerKey.join(', ')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            if (_isSingleChoice(question) || _isMultiChoice(question))
              const Padding(
                padding: EdgeInsets.only(top: 6, bottom: 2),
                child: Text(
                  '请选择答案',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            if (_isSingleChoice(question))
              ...question.options.map((option) {
                final groupValue = selected.isEmpty ? null : selected.first;
                return RadioListTile<String>(
                  dense: true,
                  value: option.key,
                  groupValue: groupValue,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${option.key}. ${option.text}'),
                  onChanged: submitting
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _generatedSelections[qKey] = {value};
                          });
                        },
                );
              }),
            if (_isMultiChoice(question))
              ...question.options.map((option) {
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selected.contains(option.key),
                  title: Text('${option.key}. ${option.text}'),
                  onChanged: submitting
                      ? null
                      : (checked) {
                          setState(() {
                            final next = <String>{...selected};
                            if (checked == true) {
                              next.add(option.key);
                            } else {
                              next.remove(option.key);
                            }
                            _generatedSelections[qKey] = next;
                          });
                        },
                );
              }),
            const SizedBox(height: 4),
            _input(
              noteController,
              _isSingleChoice(question) || _isMultiChoice(question)
                  ? '做题时遇到的问题/想法补充（可选）'
                  : '作答内容 / 问题补充',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: submitting
                      ? null
                      : () => _pickImageAttachment(qKey, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('上传图片'),
                ),
                OutlinedButton.icon(
                  onPressed: submitting
                      ? null
                      : () => _pickImageAttachment(qKey, ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('拍照'),
                ),
                OutlinedButton.icon(
                  onPressed: submitting ? null : () => _pickAudioAttachment(qKey),
                  icon: const Icon(Icons.mic_external_on_outlined),
                  label: const Text('上传语音'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _handwritingPanel(
              qKey: qKey,
              controller: signatureController,
              submitting: submitting,
            ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: attachments
                    .asMap()
                    .entries
                    .map(
                      (entry) => InputChip(
                        label: Text(_attachmentLabel(entry.value)),
                        onDeleted: submitting
                            ? null
                            : () => _removeAttachment(qKey, entry.key),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_isSingleChoice(question) || _isMultiChoice(question))
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  selected.isEmpty
                      ? '当前未选择答案'
                      : '当前已选: ${(selected.toList()..sort()).join(', ')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: submitting
                  ? null
                  : () => _submitGeneratedQuestion(provider, question, index),
              icon: submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(submitting ? '提交中..' : '提交批阅'),
            ),
            if (result != null) _jsonBox('generated-$qKey', result),
          ],
        ),
      ),
    );
  }

  Future<void> _submitGeneratedQuestion(
    AppProvider provider,
    Question question,
    int index,
  ) async {
    final qKey = _generatedQuestionKey(index);
    final selected = _generatedSelections[qKey] ?? <String>{};
    final note = _generatedSupplementControllers[qKey]?.text.trim() ?? '';
    final attachments =
        _generatedAttachments[qKey] ?? const <_AnswerImageAttachment>[];

    final userAnswers = <String>[];
    if (_isSingleChoice(question) || _isMultiChoice(question)) {
      if (selected.isEmpty) {
        _showSnack('请选择答案后再提交');
        return;
      }
      for (final option in question.options) {
        if (selected.contains(option.key)) {
          userAnswers.add(option.key);
        }
      }
      if (note.isNotEmpty) {
        userAnswers.add('note:$note');
      }
    } else {
      if (note.isNotEmpty) {
        userAnswers.add(note);
      }
      if (userAnswers.isEmpty && attachments.isEmpty) {
        _showSnack('请至少填写作答内容或上传附件');
        return;
      }
    }

    setState(() {
      _generatedSubmitting[qKey] = true;
    });
    try {
      await provider.gradeWithAI({
        'question': _questionPayloadFromQuestion(question),
        'user_answer': userAnswers,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((e) => e.toJson()).toList(),
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _generatedGradeResults[qKey] = provider.aiGradeResult ?? {};
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      final message = provider.errorMessage ?? '提交失败';
      _showSnack(message);
    } finally {
      if (mounted) {
        setState(() {
          _generatedSubmitting[qKey] = false;
        });
      }
    }
  }

  Widget _handwritingPanel({
    required String qKey,
    required SignatureController controller,
    required bool submitting,
  }) {
    final eraser = _generatedEraserMode[qKey] == true;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '手写区',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                tooltip: '画笔',
                onPressed: submitting ? null : () => _setEraserMode(qKey, false),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.edit,
                  size: 18,
                  color: eraser
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              IconButton(
                tooltip: '橡皮',
                onPressed: submitting ? null : () => _setEraserMode(qKey, true),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.auto_fix_normal,
                  size: 18,
                  color: eraser
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
              TextButton(
                onPressed: submitting ? null : () => _clearSignature(qKey),
                child: const Text('清空'),
              ),
              FilledButton.tonalIcon(
                onPressed: submitting
                    ? null
                    : () => _captureSignatureAttachment(qKey),
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('加入附件'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Signature(
                controller: controller,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '手写内容会转为图片并作为附件提交给 AI。',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageAttachment(String qKey, ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _showSnack('图片读取失败');
        return;
      }
      final name = picked.name.trim().isEmpty
          ? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : picked.name;
      final mimeType = _guessMimeType(name, fallback: 'image/jpeg');
      _appendAttachment(
        qKey,
        _AnswerImageAttachment(
          name: name,
          source: source == ImageSource.camera ? 'camera' : 'gallery',
          mimeType: mimeType,
          dataUrl: _toDataUrl(mimeType, bytes),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('上传图片失败');
    }
  }

  Future<void> _pickAudioAttachment(String qKey) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'mp3',
          'wav',
          'm4a',
          'aac',
          'ogg',
          'webm',
        ],
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showSnack('语音文件读取失败');
        return;
      }
      final name = file.name.trim().isEmpty
          ? 'voice_${DateTime.now().millisecondsSinceEpoch}.wav'
          : file.name;
      final mimeType = _guessMimeType(name, fallback: 'audio/wav');
      _appendAttachment(
        qKey,
        _AnswerImageAttachment(
          name: name,
          source: 'audio_upload',
          mimeType: mimeType,
          dataUrl: _toDataUrl(mimeType, bytes),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('上传语音失败');
    }
  }

  Future<void> _captureSignatureAttachment(String qKey) async {
    final controller = _generatedSignatureControllers[qKey];
    if (controller == null || controller.isEmpty) {
      _showSnack('请先在手写区书写内容');
      return;
    }
    final bytes = await controller.toPngBytes();
    if (bytes == null || bytes.isEmpty) {
      _showSnack('手写内容转换失败');
      return;
    }
    _appendAttachment(
      qKey,
      _AnswerImageAttachment(
        name: 'handwriting_${DateTime.now().millisecondsSinceEpoch}.png',
        source: 'handwriting',
        mimeType: 'image/png',
        dataUrl: _toDataUrl('image/png', bytes),
      ),
    );
    controller.clear();
  }

  void _appendAttachment(String qKey, _AnswerImageAttachment item) {
    final current =
        _generatedAttachments[qKey] ?? const <_AnswerImageAttachment>[];
    if (current.length >= 6) {
      _showSnack('附件最多 6 个');
      return;
    }
    setState(() {
      _generatedAttachments[qKey] = [...current, item];
    });
  }

  void _removeAttachment(String qKey, int index) {
    final current = _generatedAttachments[qKey];
    if (current == null || index < 0 || index >= current.length) {
      return;
    }
    setState(() {
      final next = [...current]..removeAt(index);
      if (next.isEmpty) {
        _generatedAttachments.remove(qKey);
      } else {
        _generatedAttachments[qKey] = next;
      }
    });
  }

  void _setEraserMode(String qKey, bool eraser) {
    final controller = _generatedSignatureControllers[qKey];
    if (controller == null) {
      return;
    }
    setState(() {
      _generatedEraserMode[qKey] = eraser;
      controller.penColor = eraser ? Colors.white : Colors.black;
      controller.penStrokeWidth = eraser ? 14 : 2.4;
    });
  }

  void _clearSignature(String qKey) {
    final controller = _generatedSignatureControllers[qKey];
    controller?.clear();
  }

  String _attachmentLabel(_AnswerImageAttachment attachment) {
    final mime = attachment.mimeType.toLowerCase();
    final prefix = mime.startsWith('audio/') ? '音频' : '图片';
    return '$prefix · ${attachment.name}';
  }

  String _toDataUrl(String mimeType, Uint8List bytes) {
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  String _guessMimeType(String fileName, {required String fallback}) {
    final normalized = fileName.toLowerCase();
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (normalized.endsWith('.webp')) return 'image/webp';
    if (normalized.endsWith('.gif')) return 'image/gif';
    if (normalized.endsWith('.heic')) return 'image/heic';
    if (normalized.endsWith('.heif')) return 'image/heif';
    if (normalized.endsWith('.bmp')) return 'image/bmp';

    if (normalized.endsWith('.wav')) return 'audio/wav';
    if (normalized.endsWith('.mp3')) return 'audio/mpeg';
    if (normalized.endsWith('.m4a')) return 'audio/mp4';
    if (normalized.endsWith('.aac')) return 'audio/aac';
    if (normalized.endsWith('.ogg')) return 'audio/ogg';
    if (normalized.endsWith('.webm')) return 'audio/webm';
    return fallback;
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _searchSection(AppProvider provider) {
    return _section(
      title: 'AI搜题',
      icon: Icons.travel_explore,
      child: Column(
        children: [
          _input(_searchTopicController, '主题'),
          _input(_searchSubjectController, '科目'),
          _input(_searchCountController, '数量'),
          FilledButton.icon(
            onPressed: () async {
              await _runProviderAction(() {
                return provider.searchAIQuestions(
                  topic: _searchTopicController.text.trim(),
                  subject: _searchSubjectController.text.trim(),
                  count: int.tryParse(_searchCountController.text.trim()) ?? 5,
                );
              });
            },
            icon: const Icon(Icons.search),
            label: const Text('联网搜题'),
          ),
          const SizedBox(height: 8),
          Text('搜索结果数量: ${provider.aiSearchQuestions.length}'),
        ],
      ),
    );
  }

  Widget _scoreSection(AppProvider provider) {
    return _section(
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
              await _runProviderAction(() {
                return provider.scoreWithAI({
                  'topic': _scoreTopicController.text.trim(),
                  'accuracy':
                      double.tryParse(_accuracyController.text.trim()) ?? 0,
                  'stability':
                      double.tryParse(_stabilityController.text.trim()) ?? 0,
                  'speed': double.tryParse(_speedController.text.trim()) ?? 0,
                });
              });
            },
            icon: const Icon(Icons.calculate),
            label: const Text('计算评分'),
          ),
          if (provider.aiScoreResult != null)
            _jsonBox('score', provider.aiScoreResult!),
        ],
      ),
    );
  }

  Widget _gradeSection(BuildContext context, AppProvider provider) {
    return _section(
      key: _gradeSectionKey,
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('请输入存在的题目ID')));
                }
                return;
              }
              await _runProviderAction(() {
                return provider.gradeWithAI({
                  'question': questionPayload,
                  'user_answer': _gradeAnswerController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                });
              });
            },
            icon: const Icon(Icons.rate_review),
            label: const Text('执行批阅'),
          ),
          if (provider.aiGradeResult != null)
            _jsonBox('grade', provider.aiGradeResult!),
        ],
      ),
    );
  }

  Widget _evaluateSection(AppProvider provider) {
    return _section(
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
              await _runProviderAction(() {
                return provider.evaluateWithAI({
                  'mode': _evaluateModeController.text.trim(),
                  'question': questionPayload ?? <String, dynamic>{},
                  'user_answer': _evaluateAnswerController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  'context': _evaluateContextController.text.trim(),
                });
              });
            },
            icon: const Icon(Icons.fact_check),
            label: const Text('执行评估'),
          ),
          if (provider.aiEvaluateResult != null)
            _jsonBox('evaluate', provider.aiEvaluateResult!),
        ],
      ),
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = _parseDate(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked != null) {
      controller.text = _formatDate(picked);
    }
  }

  DateTime? _parseDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _formatDate(DateTime dt) {
    final d = DateUtils.dateOnly(dt);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  List<String> _asStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => '$e').toList(growable: false);
  }

  Widget _section({
    Key? key,
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Card(
      key: key,
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
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '返回结果',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
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

  Future<void> _runProviderAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // AppProvider already records and exposes errorMessage.
    }
  }

  String _generatedQuestionKey(int index) => 'generated_$index';

  bool _isSingleChoice(Question question) => question.type == 'single_choice';

  bool _isMultiChoice(Question question) => question.type == 'multi_choice';

  void _jumpToFocusedSection() {
    switch (widget.focusSection) {
      case AIScreenFocusSection.none:
        return;
      case AIScreenFocusSection.generate:
        _scrollToSection(_generateSectionKey);
        return;
      case AIScreenFocusSection.grade:
        _scrollToSection(_gradeSectionKey);
        return;
    }
  }

  void _scrollToSection(GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      alignment: 0.06,
    );
  }

  void _clearGeneratedPracticeState() {
    for (final controller in _generatedSupplementControllers.values) {
      controller.dispose();
    }
    for (final controller in _generatedSignatureControllers.values) {
      controller.dispose();
    }
    _generatedSupplementControllers.clear();
    _generatedSignatureControllers.clear();
    _generatedSelections.clear();
    _generatedGradeResults.clear();
    _generatedSubmitting.clear();
    _generatedEraserMode.clear();
    _generatedAttachments.clear();
  }

  Map<String, dynamic>? _questionPayloadById(AppProvider provider, String id) {
    if (id.isEmpty) return null;
    for (final q in provider.questions) {
      if (q.id != id) continue;
      return _questionPayloadFromQuestion(q);
    }
    return null;
  }

  Map<String, dynamic> _questionPayloadFromQuestion(Question q) {
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
}

class _AnswerImageAttachment {
  const _AnswerImageAttachment({
    required this.name,
    required this.source,
    required this.mimeType,
    required this.dataUrl,
  });

  final String name;
  final String source;
  final String mimeType;
  final String dataUrl;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'source': source,
      'mime_type': mimeType,
      'data_url': dataUrl,
    };
  }
}
