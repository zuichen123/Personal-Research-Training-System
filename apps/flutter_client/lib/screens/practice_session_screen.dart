import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../models/question.dart';
import '../providers/app_provider.dart';
import '../widgets/ai_formula_text.dart';
import '../widgets/ai_multimodal_message_input.dart'
    show AIChatAttachmentPayload;

enum PracticeOrderMode { sequential, random }

class PracticeSessionScreen extends StatefulWidget {
  const PracticeSessionScreen({super.key});

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  final TextEditingController _answerController = TextEditingController();
  final Random _random = Random();
  final Map<String, int> _sourceOrder = <String, int>{};
  final ImagePicker _imagePicker = ImagePicker();
  SignatureController _boardController = SignatureController(
    penColor: Colors.black,
    penStrokeWidth: 2.4,
    exportBackgroundColor: Colors.white,
  );

  Timer? _ticker;
  bool _loading = true;
  bool _submitting = false;
  bool _autoNextEnabled = true;
  bool _currentSubmitted = false;
  bool _toolsExpanded = false;
  bool _boardMode = false;
  bool _boardEraserMode = false;
  PracticeOrderMode _orderMode = PracticeOrderMode.sequential;

  List<Question> _pendingQuestions = <Question>[];
  final Set<String> _selectedOptions = <String>{};
  final List<AIChatAttachmentPayload> _attachments =
      <AIChatAttachmentPayload>[];
  int _currentIndex = 0;
  int _elapsedSeconds = 0;
  int _answeredCount = 0;

  Question? get _currentQuestion {
    if (_pendingQuestions.isEmpty) {
      return null;
    }
    if (_currentIndex < 0 || _currentIndex >= _pendingQuestions.length) {
      return _pendingQuestions.first;
    }
    return _pendingQuestions[_currentIndex];
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _stopTimer();
    _answerController.dispose();
    _boardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    return Scaffold(
      appBar: AppBar(
        title: const Text('练习会话'),
        actions: [
          if (question != null && !_boardMode)
            IconButton(
              onPressed: _submitting || _currentSubmitted
                  ? null
                  : () => setState(() => _boardMode = true),
              icon: const Icon(Icons.draw_outlined),
              tooltip: '进入画板模式',
            ),
          IconButton(
            onPressed: _loading ? null : _bootstrap,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新可练习题目',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : question == null
          ? _buildCompletedView()
          : _boardMode
          ? _buildBoardModeView(question)
          : _buildSessionView(question),
    );
  }

  Widget _buildCompletedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 64),
            const SizedBox(height: 12),
            const Text(
              '没有未作答题目了',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '本次会话已作答：$_answeredCount',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: const Text('返回练习'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionView(Question question) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProgressCard(),
        const SizedBox(height: 12),
        _buildQuestionCard(question),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildAttachmentChips(),
        ],
        const SizedBox(height: 12),
        _buildToolToggleBar(),
        if (_toolsExpanded) ...[
          const SizedBox(height: 8),
          _buildAttachmentToolPanel(),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _answerController,
          minLines: 3,
          maxLines: 6,
          enabled: !_submitting && !_currentSubmitted,
          decoration: const InputDecoration(
            labelText: '你的答案',
            hintText: '多答案可用逗号或换行分隔（选择题可直接点选后提交）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _submitting || _currentSubmitted
                    ? null
                    : _submitCurrentAnswer,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_autoNextEnabled ? '提交并下一题' : '提交'),
              ),
            ),
            if (!_autoNextEnabled) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _currentSubmitted ? _moveToNextQuestion : null,
                icon: const Icon(Icons.skip_next),
                label: const Text('下一题'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBoardModeView(Question question) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _buildProgressCard(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _buildQuestionCard(question, compact: true),
        ),
        if (_attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildAttachmentChips(),
          ),
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                constrained: false,
                minScale: 0.5,
                maxScale: 6,
                child: SizedBox(
                  width: 2400,
                  height: 1600,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Signature(
                      controller: _boardController,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _submitting || _currentSubmitted
                    ? null
                    : () => _setBoardEraserMode(false),
                icon: Icon(
                  Icons.edit,
                  color: _boardEraserMode
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
                label: const Text('画笔'),
              ),
              OutlinedButton.icon(
                onPressed: _submitting || _currentSubmitted
                    ? null
                    : () => _setBoardEraserMode(true),
                icon: Icon(
                  Icons.auto_fix_normal,
                  color: _boardEraserMode
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                label: const Text('橡皮'),
              ),
              OutlinedButton.icon(
                onPressed: _submitting || _currentSubmitted
                    ? null
                    : _clearBoard,
                icon: const Icon(Icons.layers_clear_outlined),
                label: const Text('清空画板'),
              ),
              FilledButton.tonalIcon(
                onPressed: _submitting || _currentSubmitted
                    ? null
                    : _captureBoardAttachment,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('加入附件'),
              ),
              FilledButton.icon(
                onPressed: _submitting || _currentSubmitted
                    ? null
                    : () => setState(() => _boardMode = false),
                icon: const Icon(Icons.keyboard_arrow_down),
                label: const Text('退出画板模式'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '剩余 ${_pendingQuestions.length}  已作答 $_answeredCount',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('出题顺序：'),
                const SizedBox(width: 8),
                DropdownButton<PracticeOrderMode>(
                  value: _orderMode,
                  onChanged: (mode) {
                    if (mode == null) {
                      return;
                    }
                    _onOrderModeChanged(mode);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: PracticeOrderMode.sequential,
                      child: Text('顺序'),
                    ),
                    DropdownMenuItem(
                      value: PracticeOrderMode.random,
                      child: Text('随机'),
                    ),
                  ],
                ),
                const Spacer(),
                Switch(
                  value: _autoNextEnabled,
                  onChanged: (value) {
                    setState(() {
                      _autoNextEnabled = value;
                    });
                  },
                ),
                const Text('自动下一题'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(_elapsedSeconds),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question question, {bool compact = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AIFormulaText(
              question.title.trim().isEmpty ? '题目' : question.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            AIFormulaText(question.stem),
            if (question.options.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (_isSingleChoice(question))
                ...question.options.map((option) {
                  return RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: option.key,
                    groupValue: _selectedOptions.isEmpty
                        ? null
                        : _selectedOptions.first,
                    title: AIFormulaText('${option.key}. ${option.text}'),
                    onChanged: _submitting || _currentSubmitted
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
              if (_isMultiChoice(question))
                ...question.options.map((option) {
                  final checked = _selectedOptions.contains(option.key);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: checked,
                    title: AIFormulaText('${option.key}. ${option.text}'),
                    onChanged: _submitting || _currentSubmitted
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
              if (!_isChoiceQuestion(question))
                ...question.options.map((option) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: AIFormulaText('${option.key}. ${option.text}'),
                  );
                }),
            ],
            if (!compact && _isChoiceQuestion(question))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _selectedOptions.isEmpty
                      ? '可直接点选选项后提交，无需打字。'
                      : '已选择：${_selectedOptions.join(', ')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolToggleBar() {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: _submitting || _currentSubmitted
              ? null
              : () => setState(() => _toolsExpanded = !_toolsExpanded),
          icon: Icon(_toolsExpanded ? Icons.close : Icons.add),
          tooltip: _toolsExpanded ? '收起多模态工具' : '展开多模态工具',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _toolsExpanded ? '已展开：图片 / 语音 / 画板' : '点击 + 展开多模态输入工具',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentToolPanel() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _submitting || _currentSubmitted
              ? null
              : _pickImageAttachment,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('上传图片'),
        ),
        OutlinedButton.icon(
          onPressed: _submitting || _currentSubmitted
              ? null
              : _pickAudioAttachment,
          icon: const Icon(Icons.mic_external_on_outlined),
          label: const Text('上传语音'),
        ),
        FilledButton.tonalIcon(
          onPressed: _submitting || _currentSubmitted
              ? null
              : () => setState(() => _boardMode = true),
          icon: const Icon(Icons.draw_outlined),
          label: const Text('打开画板模式'),
        ),
      ],
    );
  }

  Widget _buildAttachmentChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _attachments
          .asMap()
          .entries
          .map((entry) {
            final item = entry.value;
            final mime = item.mimeType.toLowerCase();
            final prefix = mime.startsWith('audio/') ? '语音' : '图片';
            return InputChip(
              label: Text('$prefix · ${item.name}'),
              onDeleted: _submitting || _currentSubmitted
                  ? null
                  : () => _removeAttachment(entry.key),
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> _bootstrap() async {
    _stopTimer();
    setState(() {
      _loading = true;
      _submitting = false;
      _pendingQuestions = <Question>[];
      _currentIndex = 0;
      _elapsedSeconds = 0;
      _currentSubmitted = false;
      _answeredCount = 0;
      _resetQuestionDraft();
    });

    final provider = context.read<AppProvider>();
    await provider.fetchQuestions(force: true);
    await provider.fetchAttempts(force: true);
    if (!mounted) {
      return;
    }

    _sourceOrder
      ..clear()
      ..addEntries(
        provider.questions.asMap().entries.map((entry) {
          return MapEntry(entry.value.id, entry.key);
        }),
      );

    final attemptedQuestionIDs = provider.attempts
        .map((item) => item.questionId)
        .where((id) => id.trim().isNotEmpty)
        .toSet();

    final available = provider.questions
        .where((question) {
          return !attemptedQuestionIDs.contains(question.id);
        })
        .toList(growable: true);

    final ordered = _sortedQuestions(available, _orderMode);

    setState(() {
      _pendingQuestions = ordered;
      _currentIndex = 0;
      _elapsedSeconds = 0;
      _loading = false;
    });

    if (_pendingQuestions.isNotEmpty) {
      _startTimer();
    }
  }

  List<Question> _sortedQuestions(
    List<Question> questions,
    PracticeOrderMode mode,
  ) {
    final out = questions.toList(growable: true);
    if (mode == PracticeOrderMode.sequential) {
      out.sort((a, b) {
        final ai = _sourceOrder[a.id] ?? 1 << 20;
        final bi = _sourceOrder[b.id] ?? 1 << 20;
        return ai.compareTo(bi);
      });
      return out;
    }
    out.shuffle(_random);
    return out;
  }

  void _onOrderModeChanged(PracticeOrderMode mode) {
    if (_orderMode == mode) {
      return;
    }
    final current = _currentQuestion;
    setState(() {
      _orderMode = mode;
      if (current == null || _pendingQuestions.length <= 1) {
        return;
      }
      final rest = _pendingQuestions
          .where((question) => question.id != current.id)
          .toList(growable: true);
      final reordered = _sortedQuestions(rest, mode);
      _pendingQuestions = <Question>[current, ...reordered];
      _currentIndex = 0;
    });
  }

  Future<void> _submitCurrentAnswer() async {
    final provider = context.read<AppProvider>();
    final question = _currentQuestion;
    if (question == null) {
      return;
    }

    var answers = _collectAnswers(question);
    if (answers.isEmpty && _attachments.isNotEmpty) {
      answers = _attachments
          .map((item) => '[${item.source}] ${item.name}')
          .toList(growable: false);
    }
    if (answers.isEmpty) {
      _showSnack('请先输入答案、选择选项或添加附件');
      return;
    }

    setState(() {
      _submitting = true;
    });

    final elapsed = _elapsedSeconds;
    try {
      await provider.submitPractice(question.id, answers, elapsed);
      if (!mounted) {
        return;
      }
      setState(() {
        _answeredCount += 1;
        _currentSubmitted = true;
        _resetQuestionDraft();
      });
      if (_autoNextEnabled) {
        _moveToNextQuestion();
      } else {
        _showSnack('已提交，请点击“下一题”继续。');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack(provider.errorMessage ?? '提交失败');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  List<String> _collectAnswers(Question question) {
    if (_isChoiceQuestion(question) && _selectedOptions.isNotEmpty) {
      final optionOrder = question.options
          .map((item) => item.key)
          .where(_selectedOptions.contains)
          .toList(growable: false);
      if (optionOrder.isNotEmpty) {
        return optionOrder;
      }
      final fallback = _selectedOptions.toList(growable: true)..sort();
      return fallback;
    }
    return _parseAnswers(_answerController.text);
  }

  List<String> _parseAnswers(String raw) {
    return raw
        .split(RegExp(r'[\n,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  void _moveToNextQuestion() {
    if (_pendingQuestions.isEmpty) {
      return;
    }

    _stopTimer();
    setState(() {
      _pendingQuestions.removeAt(_currentIndex);
      _currentSubmitted = false;
      _elapsedSeconds = 0;
      _resetQuestionDraft();

      if (_pendingQuestions.isEmpty) {
        _currentIndex = 0;
        return;
      }

      if (_orderMode == PracticeOrderMode.random) {
        _currentIndex = _random.nextInt(_pendingQuestions.length);
      } else if (_currentIndex >= _pendingQuestions.length) {
        _currentIndex = _pendingQuestions.length - 1;
      }
    });

    if (_pendingQuestions.isNotEmpty) {
      _startTimer();
    }
  }

  void _startTimer() {
    _stopTimer();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _elapsedSeconds += 1;
      });
    });
  }

  void _stopTimer() {
    _ticker?.cancel();
    _ticker = null;
  }

  bool _isChoiceQuestion(Question question) {
    return _isSingleChoice(question) || _isMultiChoice(question);
  }

  bool _isSingleChoice(Question question) {
    return question.type == 'single_choice';
  }

  bool _isMultiChoice(Question question) {
    return question.type == 'multi_choice';
  }

  Future<void> _pickImageAttachment() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        return;
      }
      final name = picked.name.trim().isEmpty
          ? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : picked.name;
      final mimeType = _guessMimeType(name, fallback: 'image/jpeg');
      _appendAttachment(
        AIChatAttachmentPayload(
          name: name,
          source: 'gallery',
          mimeType: mimeType,
          dataUrl: _toDataUrl(mimeType, bytes),
        ),
      );
    } catch (_) {
      _showSnack('图片添加失败，请重试');
    }
  }

  Future<void> _pickAudioAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'webm'],
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      final name = file.name.trim().isEmpty
          ? 'voice_${DateTime.now().millisecondsSinceEpoch}.wav'
          : file.name;
      final mimeType = _guessMimeType(name, fallback: 'audio/wav');
      _appendAttachment(
        AIChatAttachmentPayload(
          name: name,
          source: 'audio_upload',
          mimeType: mimeType,
          dataUrl: _toDataUrl(mimeType, bytes),
        ),
      );
    } catch (_) {
      _showSnack('语音添加失败，请重试');
    }
  }

  Future<void> _captureBoardAttachment() async {
    if (_boardController.isEmpty) {
      _showSnack('画板为空，无法加入附件');
      return;
    }
    final bytes = await _boardController.toPngBytes();
    if (bytes == null || bytes.isEmpty) {
      _showSnack('画板导出失败，请重试');
      return;
    }
    _appendAttachment(
      AIChatAttachmentPayload(
        name: 'handwriting_${DateTime.now().millisecondsSinceEpoch}.png',
        source: 'handwriting',
        mimeType: 'image/png',
        dataUrl: _toDataUrl('image/png', bytes),
      ),
    );
    _showSnack('画板内容已加入附件');
  }

  void _appendAttachment(AIChatAttachmentPayload attachment) {
    if (_attachments.length >= 6) {
      _showSnack('最多添加 6 个附件');
      return;
    }
    setState(() {
      _attachments.add(attachment);
    });
  }

  void _removeAttachment(int index) {
    if (index < 0 || index >= _attachments.length) {
      return;
    }
    setState(() {
      _attachments.removeAt(index);
    });
  }

  void _setBoardEraserMode(bool eraserMode) {
    if (_boardEraserMode == eraserMode) {
      return;
    }
    final previous = _boardController;
    final recreated = SignatureController(
      points: List<Point>.from(previous.points),
      penColor: eraserMode ? Colors.white : Colors.black,
      penStrokeWidth: eraserMode ? 14 : 2.4,
      exportBackgroundColor: Colors.white,
    );
    setState(() {
      _boardEraserMode = eraserMode;
      _boardController = recreated;
    });
    previous.dispose();
  }

  void _clearBoard() {
    _boardController.clear();
  }

  void _resetQuestionDraft() {
    _answerController.clear();
    _selectedOptions.clear();
    _attachments.clear();
    _toolsExpanded = false;
    _boardMode = false;
    _boardEraserMode = false;
    _clearBoard();
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

  String _formatDuration(int seconds) {
    final normalized = seconds < 0 ? 0 : seconds;
    final mins = (normalized ~/ 60).toString().padLeft(2, '0');
    final secs = (normalized % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _showSnack(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
