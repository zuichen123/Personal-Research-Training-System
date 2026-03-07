import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../providers/app_provider.dart';
import '../widgets/ai_formula_text.dart';

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

  Timer? _ticker;
  bool _loading = true;
  bool _submitting = false;
  bool _autoNextEnabled = true;
  bool _currentSubmitted = false;
  PracticeOrderMode _orderMode = PracticeOrderMode.sequential;

  List<Question> _pendingQuestions = <Question>[];
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    return Scaffold(
      appBar: AppBar(
        title: const Text('练习会话'),
        actions: [
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
        Card(
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
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AIFormulaText(
                  question.title.trim().isEmpty ? '题目' : question.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                AIFormulaText(question.stem),
                if (question.options.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...question.options.map((option) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: AIFormulaText('${option.key}. ${option.text}'),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _answerController,
          minLines: 3,
          maxLines: 6,
          enabled: !_submitting && !_currentSubmitted,
          decoration: const InputDecoration(
            labelText: '你的答案',
            hintText: '多答案可用逗号或换行分隔',
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

    final answers = _parseAnswers(_answerController.text);
    if (answers.isEmpty) {
      _showSnack('请先输入答案');
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
        _answerController.clear();
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

  List<String> _parseAnswers(String raw) {
    return raw
        .split(RegExp(r'[\\n,;]+'))
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
