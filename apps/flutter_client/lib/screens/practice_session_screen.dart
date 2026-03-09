import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../models/question.dart';
import '../providers/app_provider.dart';
import '../utils/signature_canvas_utils.dart';
import '../widgets/ai_formula_text.dart';
import '../widgets/ai_multimodal_message_input.dart'
    show AIChatAttachmentPayload;
import '../widgets/practice_multimodal_answer_input.dart';

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
  final SignatureController _boardController = SignatureController(
    disabled: true,
    penColor: Colors.black,
    penStrokeWidth: 2.4,
    exportBackgroundColor: Colors.white,
  );

  Timer? _ticker;
  bool _loading = true;
  bool _submitting = false;
  bool _autoNextEnabled = true;
  bool _currentSubmitted = false;
  bool _boardMode = false;
  bool _boardFullScreen = false;
  bool _boardEraserMode = false;
  int? _boardPointerId;
  Offset _boardOffset = const Offset(24, 120);
  String _boardReferenceKey = 'question';
  PracticeOrderMode _orderMode = PracticeOrderMode.sequential;

  List<Question> _pendingQuestions = <Question>[];
  final Set<String> _selectedOptions = <String>{};
  final List<AIChatAttachmentPayload> _attachments =
      <AIChatAttachmentPayload>[];
  int _currentIndex = 0;
  int _elapsedSeconds = 0;
  int _answeredCount = 0;
  int _draftResetToken = 0;

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
                  : () => setState(() {
                      _boardMode = true;
                      _boardFullScreen = false;
                    }),
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
          : _buildSessionBody(question),
    );
  }

  Widget _buildSessionBody(Question question) {
    if (!_boardMode) {
      return _buildSessionView(question);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = _boardPanelSize(constraints, _boardFullScreen);
        final boardOffset = _clampBoardOffset(
          _boardOffset,
          constraints,
          boardSize,
        );
        if (boardOffset != _boardOffset) {
          _boardOffset = boardOffset;
        }
        return Stack(
          children: [
            _buildSessionView(question),
            _buildBoardOverlay(
              question,
              constraints,
              boardSize: boardSize,
              boardOffset: boardOffset,
            ),
          ],
        );
      },
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
        const SizedBox(height: 12),
        PracticeMultimodalAnswerInput(
          key: ValueKey('practice-answer-${question.id}'),
          controller: _answerController,
          attachments: _attachments,
          onAttachmentsChanged: (next) =>
              setState(() => _replaceAttachments(next)),
          enabled: !_submitting && !_currentSubmitted,
          labelText: '你的答案',
          hintText: '多答案可用逗号或换行分隔（选择题可直接点选后提交）',
          showCameraButton: true,
          resetKey: _draftResetToken,
          onChanged: (_) {
            if (_boardMode && _boardReferenceKey == 'typed') {
              setState(() {});
            }
          },
          extraToolActions: _boardMode
              ? const <Widget>[]
              : <Widget>[
                  OutlinedButton.icon(
                    onPressed: _submitting || _currentSubmitted
                        ? null
                        : () => setState(() {
                            _boardMode = true;
                            _boardFullScreen = false;
                          }),
                    icon: const Icon(Icons.draw_outlined),
                    label: const Text('打开画板模式'),
                  ),
                ],
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

  // ignore: unused_element
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
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _handleBoardPointerDown,
                      onPointerMove: _handleBoardPointerMove,
                      onPointerUp: _handleBoardPointerEnd,
                      onPointerCancel: _handleBoardPointerEnd,
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

  Widget _buildBoardOverlay(
    Question question,
    BoxConstraints constraints, {
    required Size boardSize,
    required Offset boardOffset,
  }) {
    final panel = _buildBoardPanel(
      question,
      constraints,
      boardSize: boardSize,
      boardOffset: boardOffset,
    );
    if (_boardFullScreen) {
      return Positioned.fill(
        child: ColoredBox(
          color: Colors.black26,
          child: SafeArea(
            child: Padding(padding: const EdgeInsets.all(8), child: panel),
          ),
        ),
      );
    }
    return Positioned(
      left: boardOffset.dx,
      top: boardOffset.dy,
      child: SizedBox(
        width: boardSize.width,
        height: boardSize.height,
        child: panel,
      ),
    );
  }

  Widget _buildBoardPanel(
    Question question,
    BoxConstraints constraints, {
    required Size boardSize,
    required Offset boardOffset,
  }) {
    final referenceText = _resolveBoardReferenceText(
      question,
      _boardReferenceKey,
    );
    final borderRadius = BorderRadius.circular(_boardFullScreen ? 12 : 16);
    final draggableEnabled =
        !_boardFullScreen && !_submitting && !_currentSubmitted;
    return Material(
      elevation: _boardFullScreen ? 0 : 12,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: borderRadius,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: draggableEnabled
                  ? (details) {
                      setState(() {
                        _boardOffset = _clampBoardOffset(
                          _boardOffset + details.delta,
                          constraints,
                          boardSize,
                        );
                      });
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    Icon(
                      draggableEnabled
                          ? Icons.drag_indicator
                          : Icons.fullscreen,
                      size: 18,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '画板模式',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _buildBoardReferencePicker()),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: _boardFullScreen ? '退出全屏' : '全屏',
                      onPressed: _submitting || _currentSubmitted
                          ? null
                          : () {
                              setState(() {
                                final nextFullScreen = !_boardFullScreen;
                                _boardFullScreen = nextFullScreen;
                                if (nextFullScreen) {
                                  _boardOffset = const Offset(0, 0);
                                } else {
                                  final floatingSize = _boardPanelSize(
                                    constraints,
                                    false,
                                  );
                                  _boardOffset = _clampBoardOffset(
                                    boardOffset,
                                    constraints,
                                    floatingSize,
                                  );
                                }
                              });
                            },
                      icon: Icon(
                        _boardFullScreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭画板',
                      onPressed: _submitting || _currentSubmitted
                          ? null
                          : () => setState(() {
                              _boardMode = false;
                              _boardFullScreen = false;
                            }),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _boardFullScreen
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 10,
                            child: _buildBoardReferencePanel(
                              referenceText,
                              fullScreen: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(flex: 18, child: _buildBoardCanvas()),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        if (referenceText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: _buildBoardReferencePanel(
                              referenceText,
                              fullScreen: false,
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: _buildBoardCanvas(),
                          ),
                        ),
                      ],
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardReferencePanel(
    String referenceText, {
    required bool fullScreen,
  }) {
    final theme = Theme.of(context);
    final displayText = referenceText.trim();
    final hasContent = displayText.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '参考内容',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (fullScreen)
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    hasContent
                        ? displayText
                        : '当前参考为空，可切换题干、选项、输入内容、已选答案或附件摘要。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: hasContent ? null : theme.colorScheme.outline,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 110),
                child: SingleChildScrollView(
                  child: SelectableText(
                    displayText,
                    style: const TextStyle(fontSize: 12, height: 1.35),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardCanvas() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: InteractiveViewer(
          constrained: false,
          minScale: 0.5,
          maxScale: 6,
          child: SizedBox(
            width: 2400,
            height: 1600,
            child: ColoredBox(
              color: Colors.white,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _handleBoardPointerDown,
                onPointerMove: _handleBoardPointerMove,
                onPointerUp: _handleBoardPointerEnd,
                onPointerCancel: _handleBoardPointerEnd,
                child: Signature(
                  controller: _boardController,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardReferencePicker() {
    return DropdownButtonHideUnderline(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButton<String>(
            isExpanded: true,
            value: _boardReferenceKey,
            onChanged: _submitting || _currentSubmitted
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _boardReferenceKey = value);
                  },
            items: _boardReferenceItems(),
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _boardReferenceItems() {
    const labels = <String, String>{
      'question': '参考：题干',
      'options': '参考：选项',
      'typed': '参考：输入内容',
      'selected': '参考：已选答案',
      'attachments': '参考：附件摘要',
    };
    return labels.entries
        .map(
          (entry) => DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false);
  }

  String _resolveBoardReferenceText(Question question, String key) {
    switch (key) {
      case 'question':
        final title = question.title.trim();
        final stem = question.stem.trim();
        return [
          if (title.isNotEmpty) title,
          stem,
        ].where((item) => item.isNotEmpty).join('\n');
      case 'options':
        if (question.options.isEmpty) {
          return '';
        }
        return question.options
            .map((item) => '${item.key}. ${item.text}')
            .join('\n');
      case 'typed':
        return _answerController.text.trim();
      case 'selected':
        if (_selectedOptions.isEmpty) {
          return '';
        }
        return _selectedOptions.toList(growable: false).join(', ');
      case 'attachments':
        if (_attachments.isEmpty) {
          return '';
        }
        return _attachments
            .map((item) => '[${item.source}] ${item.name}')
            .join('\n');
      default:
        return '';
    }
  }

  Size _boardPanelSize(BoxConstraints constraints, bool fullScreen) {
    if (fullScreen) {
      return Size(constraints.maxWidth, constraints.maxHeight);
    }
    final width = (constraints.maxWidth * 0.88).clamp(340.0, 980.0).toDouble();
    final height = (constraints.maxHeight * 0.78)
        .clamp(380.0, 860.0)
        .toDouble();
    return Size(width, height);
  }

  Offset _clampBoardOffset(
    Offset candidate,
    BoxConstraints constraints,
    Size boardSize,
  ) {
    final maxX = max(0.0, constraints.maxWidth - boardSize.width);
    final maxY = max(0.0, constraints.maxHeight - boardSize.height);
    return Offset(
      candidate.dx.clamp(0.0, maxX).toDouble(),
      candidate.dy.clamp(0.0, maxY).toDouble(),
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

  void _replaceAttachments(List<AIChatAttachmentPayload> next) {
    _attachments
      ..clear()
      ..addAll(next);
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
                  : () => setState(() {
                      final next = [..._attachments]..removeAt(entry.key);
                      _replaceAttachments(next);
                    }),
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> _submitCurrentAnswer() async {
    final provider = context.read<AppProvider>();
    final question = _currentQuestion;
    if (question == null) {
      return;
    }

    final answers = _collectAnswers(question);
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
    final combined = <String>[];
    if (_isChoiceQuestion(question)) {
      final optionOrder = question.options
          .map((item) => item.key)
          .where(_selectedOptions.contains)
          .toList(growable: false);
      if (optionOrder.isNotEmpty) {
        _appendAnswersUnique(combined, optionOrder);
      } else if (_selectedOptions.isNotEmpty) {
        final fallback = _selectedOptions.toList(growable: true)..sort();
        _appendAnswersUnique(combined, fallback);
      }
    }
    _appendAnswersUnique(combined, _parseAnswers(_answerController.text));
    _appendAnswersUnique(
      combined,
      _attachments.map((item) => '[${item.source}] ${item.name}'),
    );
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
    if (_attachments.length >= 6) {
      _showSnack('最多添加 6 个附件');
      return;
    }
    setState(() {
      _replaceAttachments([
        ..._attachments,
        AIChatAttachmentPayload(
          name: 'handwriting_${DateTime.now().millisecondsSinceEpoch}.png',
          source: 'handwriting',
          mimeType: 'image/png',
          dataUrl: _toDataUrl('image/png', bytes),
        ),
      ]);
    });
    _showSnack('画板内容已加入附件');
  }

  void _setBoardEraserMode(bool eraserMode) {
    if (_boardEraserMode == eraserMode) {
      return;
    }
    setState(() {
      _boardEraserMode = eraserMode;
    });
  }

  void _handleBoardPointerDown(PointerDownEvent event) {
    if (_submitting ||
        _currentSubmitted ||
        !_isPrimaryButtonPressed(event.buttons)) {
      _boardPointerId = null;
      return;
    }
    _boardPointerId = event.pointer;
    if (_boardEraserMode) {
      SignatureCanvasUtils.eraseAt(_boardController, event.localPosition);
      return;
    }
    SignatureCanvasUtils.addPoint(
      _boardController,
      event.localPosition,
      PointType.tap,
      pressure: _normalizedPressure(event.pressure),
    );
  }

  void _handleBoardPointerMove(PointerMoveEvent event) {
    if (_boardPointerId != event.pointer ||
        !_isPrimaryButtonPressed(event.buttons)) {
      return;
    }
    if (_boardEraserMode) {
      SignatureCanvasUtils.eraseAt(_boardController, event.localPosition);
      return;
    }
    SignatureCanvasUtils.addPoint(
      _boardController,
      event.localPosition,
      PointType.move,
      pressure: _normalizedPressure(event.pressure),
    );
  }

  void _handleBoardPointerEnd(PointerEvent event) {
    if (_boardPointerId == event.pointer) {
      _boardPointerId = null;
    }
  }

  bool _isPrimaryButtonPressed(int buttons) => (buttons & kPrimaryButton) != 0;

  double _normalizedPressure(double pressure) => pressure > 0 ? pressure : 1.0;

  void _clearBoard() {
    _boardController.clear();
  }

  void _resetQuestionDraft() {
    _answerController.clear();
    _selectedOptions.clear();
    _attachments.clear();
    _draftResetToken += 1;
    _boardMode = false;
    _boardFullScreen = false;
    _boardEraserMode = false;
    _boardReferenceKey = 'question';
    _clearBoard();
  }

  String _toDataUrl(String mimeType, Uint8List bytes) {
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
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
