import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/practice.dart';
import '../models/question.dart';
import '../providers/app_provider.dart';
import '../widgets/ai_formula_text.dart';
import 'practice_ai_paper_screen.dart';
import 'practice_attempt_detail_screen.dart';
import 'practice_session_screen.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final attempts = provider.attempts;
    final loading = provider.isSectionLoading(DataSection.attempts);
    _ensureQuestionsLoaded(context, provider, attempts);

    return Scaffold(
      appBar: AppBar(
        title: const Text('练习'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchAttempts(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchAttempts(force: true),
        child: _buildBody(context, provider, attempts, loading),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPracticeSession(context),
        label: const Text('开始练习'),
        icon: const Icon(Icons.play_arrow),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppProvider provider,
    List<PracticeAttempt> attempts,
    bool loading,
  ) {
    final latestAttempts = _latestAttemptsByQuestion(attempts);
    final attemptCountByQuestion = _attemptCountByQuestion(attempts);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
      children: [
        _buildAIPaperSection(context),
        const SizedBox(height: 10),
        _buildHomeworkSection(context),
        const SizedBox(height: 10),
        _buildUnitPracticeSection(context),
        const SizedBox(height: 14),
        Text(
          '最近作答',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ..._buildAttemptSection(
          context,
          provider,
          latestAttempts,
          attemptCountByQuestion,
          loading,
        ),
      ],
    );
  }

  Widget _buildAIPaperSection(BuildContext context) {
    const quickSubtopics = <String>['章节巩固', '错题回炉', '综合冲刺'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_fix_high,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI组卷',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('支持总卷编排 Agent + 题型 Agent 协同，按主题与子板块细分组卷。'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _openAIPaperComposer(context),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('进入 AI 组卷'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: quickSubtopics
                  .map((item) {
                    return ActionChip(
                      label: Text(item),
                      onPressed: () => _openAIPaperComposer(
                        context,
                        initialTopic: item,
                        initialSubtopics: <String>[item],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeworkSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_outlined),
                SizedBox(width: 8),
                Text(
                  '课后作业',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('进入标准练习会话，完成课后题并记录作答历史。'),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => _openPracticeSession(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始课后作业'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitPracticeSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.menu_book_outlined),
                SizedBox(width: 8),
                Text(
                  '单元练习',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('按单元设置主题后由 AI 继续细分组卷，生成更贴合当前学习阶段的练习。'),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _showUnitAIPaperDialog(context),
                  icon: const Icon(Icons.tune),
                  label: const Text('按单元组卷'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openPracticeSession(context),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('直接开练'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAttemptSection(
    BuildContext context,
    AppProvider provider,
    List<PracticeAttempt> latestAttempts,
    Map<String, int> attemptCountByQuestion,
    bool loading,
  ) {
    if (loading && latestAttempts.isEmpty) {
      return const <Widget>[
        SizedBox(height: 36),
        Center(child: CircularProgressIndicator()),
      ];
    }

    if (provider.errorMessage != null && latestAttempts.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('加载失败：${provider.errorMessage}'),
        ),
      ];
    }

    if (latestAttempts.isEmpty) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '暂无作答记录，先从上方任一板块开始。',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ];
    }

    return latestAttempts
        .map((a) {
          final question = _questionById(provider.questions, a.questionId);
          final stem = (question?.stem ?? '').trim();
          final subject = (question?.subject ?? '').trim();
          final type = _questionTypeLabel(question?.type ?? '');
          final count = attemptCountByQuestion[a.questionId] ?? 1;
          final scoreColor = a.score >= 80
              ? Colors.green
              : a.score >= 60
              ? Colors.orange
              : Colors.red;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              onTap: () async {
                Question? targetQuestion = _questionById(
                  provider.questions,
                  a.questionId,
                );
                if (targetQuestion == null && provider.questions.isEmpty) {
                  await provider.fetchQuestions(force: true);
                  if (!context.mounted) {
                    return;
                  }
                  targetQuestion = _questionById(
                    provider.questions,
                    a.questionId,
                  );
                }
                if (!context.mounted) {
                  return;
                }
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PracticeAttemptDetailScreen(
                      attempt: a,
                      question: targetQuestion,
                      allAttempts: provider.attempts,
                    ),
                  ),
                );
                if (!context.mounted) {
                  return;
                }
                await provider.fetchAttempts(force: true);
              },
              leading: CircleAvatar(
                backgroundColor: scoreColor,
                child: Text(
                  a.score.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: AIFormulaText(
                      stem.isEmpty ? '题目不存在' : stem,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      '作答$count次',
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    a.correct ? Icons.check_circle : Icons.cancel,
                    color: a.correct ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ],
              ),
              subtitle: Text(
                '学科：${subject.isEmpty ? '-' : subject}  题型：$type\n用时：${_formatDuration(a.elapsedSeconds)}  反馈：${a.feedback}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatDate(a.submittedAt),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    tooltip: '删除',
                    onPressed: () async => _deleteAttempt(context, a.id),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          );
        })
        .toList(growable: false);
  }

  Question? _questionById(List<Question> questions, String questionId) {
    for (final q in questions) {
      if (q.id == questionId) {
        return q;
      }
    }
    return null;
  }

  List<PracticeAttempt> _latestAttemptsByQuestion(
    List<PracticeAttempt> attempts,
  ) {
    final seen = <String>{};
    final result = <PracticeAttempt>[];
    for (final item in attempts) {
      if (seen.contains(item.questionId)) {
        continue;
      }
      seen.add(item.questionId);
      result.add(item);
    }
    return result;
  }

  Map<String, int> _attemptCountByQuestion(List<PracticeAttempt> attempts) {
    final counts = <String, int>{};
    for (final item in attempts) {
      counts[item.questionId] = (counts[item.questionId] ?? 0) + 1;
    }
    return counts;
  }

  void _ensureQuestionsLoaded(
    BuildContext context,
    AppProvider provider,
    List<PracticeAttempt> attempts,
  ) {
    if (attempts.isEmpty) {
      return;
    }
    if (provider.questions.isNotEmpty) {
      return;
    }
    if (provider.isSectionLoaded(DataSection.questions) ||
        provider.isSectionLoading(DataSection.questions)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        return;
      }
      context.read<AppProvider>().fetchQuestions();
    });
  }

  String _questionTypeLabel(String type) {
    switch (type) {
      case 'single_choice':
        return '单选题';
      case 'multi_choice':
        return '多选题';
      case 'short_answer':
        return '简答题';
      default:
        return type.trim().isEmpty ? '-' : type;
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDuration(int seconds) {
    final normalized = seconds < 0 ? 0 : seconds;
    final mins = (normalized ~/ 60).toString().padLeft(2, '0');
    final secs = (normalized % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _deleteAttempt(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('删除练习记录'),
          content: const Text('确认删除这条作答记录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await context.read<AppProvider>().deletePracticeAttempt(id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除练习记录')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      final message = context.read<AppProvider>().errorMessage ?? '删除失败';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openPracticeSession(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PracticeSessionScreen()));
    if (!context.mounted) {
      return;
    }
    await context.read<AppProvider>().fetchAttempts(force: true);
  }

  Future<void> _openAIPaperComposer(
    BuildContext context, {
    String initialSubject = 'math',
    String initialTopic = '函数综合',
    List<String> initialSubtopics = const <String>[],
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticeAIPaperScreen(
          initialSubject: initialSubject,
          initialTopic: initialTopic,
          initialSubtopics: initialSubtopics,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    await context.read<AppProvider>().fetchQuestions(force: true);
  }

  Future<void> _showUnitAIPaperDialog(BuildContext context) async {
    String defaultSubject = 'math';
    String defaultTopic = '';

    final provider = context.read<AppProvider>();
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final lessons = await provider.apiService.listAICourseScheduleLessons(
        date: todayStr,
      );
      if (lessons.isNotEmpty) {
        final lesson = lessons.first;
        defaultSubject = lesson['subject']?.toString() ?? defaultSubject;
        defaultTopic = lesson['topic']?.toString() ?? defaultTopic;
      }
    } catch (_) {}

    if (!context.mounted) return;

    final subjectController = TextEditingController(text: defaultSubject);
    final topicController = TextEditingController(text: defaultTopic);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('按单元组卷'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: '科目',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: topicController,
                decoration: const InputDecoration(
                  labelText: '单元/主题',
                  hintText: '例如：导数应用',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final subject = subjectController.text.trim();
                final topic = topicController.text.trim();
                if (subject.isEmpty || topic.isEmpty) {
                  return;
                }
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (!context.mounted) {
                  return;
                }
                await _openAIPaperComposer(
                  context,
                  initialSubject: subject,
                  initialTopic: topic,
                  initialSubtopics: <String>[topic],
                );
              },
              child: const Text('进入组卷'),
            ),
          ],
        );
      },
    );

    subjectController.dispose();
    topicController.dispose();
  }
}
