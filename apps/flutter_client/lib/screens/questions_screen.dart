import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../providers/app_provider.dart';
import 'question_detail_screen.dart';

const String _unknownUnit = '未分单元';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final loading = provider.isSectionLoading(DataSection.questions);
    final groups = _groupBySubject(provider.questions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('题库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchQuestions(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchQuestions(force: true),
        child: _buildSubjectBody(context, provider, groups, loading),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'questions-ai-create-root',
            onPressed: () => _showAICreateDialog(context),
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('AI创建题库内容'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'questions-create-root',
            onPressed: () => _showQuestionEditDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('新建题目'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectBody(
    BuildContext context,
    AppProvider provider,
    List<_SubjectGroup> groups,
    bool loading,
  ) {
    if (loading && groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && groups.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Center(child: Text('加载失败：${provider.errorMessage}')),
        ],
      );
    }

    if (groups.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 64),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.quiz_outlined,
                  size: 64,
                  color: Colors.blue.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 16),
                const Text(
                  '暂无题目',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  '先用 AI 创建科目/单元内容，或手动新建题目',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _SubjectUnitsScreen(subject: group.subject),
                ),
              );
            },
            leading: CircleAvatar(child: Text('${group.questionsCount}')),
            title: Text(
              group.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '单元 ${group.unitsCount} · 题目 ${group.questionsCount}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'ai') {
                  await _showAICreateDialog(
                    context,
                    presetSubject: group.subject,
                  );
                } else if (value == 'rename') {
                  await _renameSubject(context, group.subject);
                } else if (value == 'delete') {
                  await _deleteSubject(context, group.subject);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'ai', child: Text('AI创建内容')),
                PopupMenuItem(value: 'rename', child: Text('重命名科目')),
                PopupMenuItem(value: 'delete', child: Text('删除科目全部题目')),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_SubjectGroup> _groupBySubject(List<Question> questions) {
    final map = <String, Map<String, List<Question>>>{};
    for (final q in questions) {
      final subject = _normalizeSubject(q.subject);
      final unit = _extractUnit(q);
      final unitMap = map.putIfAbsent(
        subject,
        () => <String, List<Question>>{},
      );
      final items = unitMap.putIfAbsent(unit, () => <Question>[]);
      items.add(q);
    }

    final result = map.entries.map((entry) {
      final unitEntries = entry.value.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return _SubjectGroup(
        subject: entry.key,
        units: {
          for (final unitEntry in unitEntries) unitEntry.key: unitEntry.value,
        },
      );
    }).toList()..sort((a, b) => a.subject.compareTo(b.subject));

    return result;
  }
}

class _SubjectUnitsScreen extends StatelessWidget {
  const _SubjectUnitsScreen({required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final loading = provider.isSectionLoading(DataSection.questions);
    final subjectQuestions = provider.questions
        .where((q) => _sameText(_normalizeSubject(q.subject), subject))
        .toList(growable: false);
    final units = _groupByUnit(subjectQuestions);

    return Scaffold(
      appBar: AppBar(
        title: Text(subject),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<AppProvider>().fetchQuestions(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            context.read<AppProvider>().fetchQuestions(force: true),
        child: _buildBody(context, provider, units, loading),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'subject-ai-$subject',
            onPressed: () =>
                _showAICreateDialog(context, presetSubject: subject),
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('AI创建单元题目'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'subject-create-$subject',
            onPressed: () =>
                _showQuestionEditDialog(context, presetSubject: subject),
            icon: const Icon(Icons.add),
            label: const Text('新建题目'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppProvider provider,
    Map<String, List<Question>> units,
    bool loading,
  ) {
    if (loading && units.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && units.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Center(child: Text('加载失败：${provider.errorMessage}')),
        ],
      );
    }

    if (units.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 64),
          Center(child: Text('当前科目下暂无单元')),
        ],
      );
    }

    final entries = units.entries.toList();
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final unit = entries[index].key;
        final questions = entries[index].value;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      _UnitQuestionsScreen(subject: subject, unit: unit),
                ),
              );
            },
            leading: const CircleAvatar(child: Icon(Icons.book_outlined)),
            title: Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('题目 ${questions.length}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'ai') {
                  await _showAICreateDialog(
                    context,
                    presetSubject: subject,
                    presetUnit: unit == _unknownUnit ? '' : unit,
                  );
                } else if (value == 'rename') {
                  await _renameUnit(context, subject, unit);
                } else if (value == 'delete') {
                  await _deleteUnit(context, subject, unit);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'ai', child: Text('AI创建题目')),
                PopupMenuItem(value: 'rename', child: Text('重命名单元')),
                PopupMenuItem(value: 'delete', child: Text('删除单元全部题目')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UnitQuestionsScreen extends StatelessWidget {
  const _UnitQuestionsScreen({required this.subject, required this.unit});

  final String subject;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final loading = provider.isSectionLoading(DataSection.questions);
    final questions = provider.questions
        .where((q) => _sameText(_normalizeSubject(q.subject), subject))
        .where((q) => _sameText(_extractUnit(q), unit))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('$subject / $unit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<AppProvider>().fetchQuestions(force: true),
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'AI创建题目',
            onPressed: () => _showAICreateDialog(
              context,
              presetSubject: subject,
              presetUnit: unit == _unknownUnit ? '' : unit,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            context.read<AppProvider>().fetchQuestions(force: true),
        child: _buildBody(context, provider, questions, loading),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'unit-create-$subject-$unit',
        onPressed: () => _showQuestionEditDialog(
          context,
          presetSubject: subject,
          presetUnit: unit == _unknownUnit ? '' : unit,
        ),
        icon: const Icon(Icons.add),
        label: const Text('新建题目'),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppProvider provider,
    List<Question> questions,
    bool loading,
  ) {
    if (loading && questions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && questions.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Center(child: Text('加载失败：${provider.errorMessage}')),
        ],
      );
    }

    if (questions.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 64),
          Center(child: Text('当前单元暂无题目')),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final q = questions[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QuestionDetailScreen(
                    question: q,
                    questionNumber: index + 1,
                  ),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: _difficultyColor(q.difficulty),
              radius: 18,
              child: Text(
                '${q.difficulty}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            title: Text(
              q.title.isNotEmpty ? q.title : q.stem,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(
                    _sourceZh(q.source),
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Chip(
                  label: Text(
                    _typeZh(q.type),
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(
                  '掌握:${q.masteryLevel}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await _showQuestionEditDialog(context, question: q);
                } else if (value == 'delete') {
                  await _deleteSingleQuestion(context, q);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SubjectGroup {
  const _SubjectGroup({required this.subject, required this.units});

  final String subject;
  final Map<String, List<Question>> units;

  int get unitsCount => units.length;

  int get questionsCount =>
      units.values.fold(0, (total, items) => total + items.length);
}

Future<void> _showQuestionEditDialog(
  BuildContext context, {
  Question? question,
  String presetSubject = '',
  String presetUnit = '',
}) async {
  final provider = context.read<AppProvider>();
  final isEdit = question != null;
  final titleController = TextEditingController(text: question?.title ?? '');
  final stemController = TextEditingController(text: question?.stem ?? '');
  final subjectController = TextEditingController(
    text: isEdit ? _normalizeSubject(question.subject) : presetSubject,
  );
  final unitController = TextEditingController(
    text: isEdit ? _unitForEdit(question) : presetUnit,
  );
  final sourceController = TextEditingController(
    text: question?.source ?? 'unit_test',
  );
  final typeController = TextEditingController(
    text: question?.type ?? 'short_answer',
  );
  final answerKeyController = TextEditingController(
    text: question?.answerKey.join(',') ?? '',
  );
  final tagsController = TextEditingController(
    text: isEdit ? _nonUnitTags(question).join(',') : '',
  );
  final difficultyController = TextEditingController(
    text: '${question?.difficulty ?? 3}',
  );
  final masteryController = TextEditingController(
    text: '${question?.masteryLevel ?? 0}',
  );

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(isEdit ? '编辑题目' : '新建题目'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogInput(titleController, '标题'),
              _dialogInput(stemController, '题干', maxLines: 3),
              _dialogInput(typeController, '题型'),
              _dialogInput(subjectController, '科目'),
              _dialogInput(unitController, '单元'),
              _dialogInput(sourceController, '来源'),
              _dialogInput(answerKeyController, '答案关键点(逗号分隔)'),
              _dialogInput(tagsController, '标签(逗号分隔)'),
              _dialogInput(difficultyController, '难度(1-5)'),
              _dialogInput(masteryController, '掌握度(0-100)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final subject = _normalizeSubject(subjectController.text);
              final unit = unitController.text.trim();
              final tags = _mergeUnitTag(_parseCsv(tagsController.text), unit);
              final input = <String, dynamic>{
                'title': titleController.text.trim(),
                'stem': stemController.text.trim(),
                'type': typeController.text.trim(),
                'subject': subject,
                'source': sourceController.text.trim(),
                'options':
                    question?.options.map((e) => e.toJson()).toList() ??
                    <Map<String, dynamic>>[],
                'answer_key': _parseCsv(answerKeyController.text),
                'tags': tags,
                'difficulty':
                    int.tryParse(difficultyController.text.trim()) ?? 3,
                'mastery_level':
                    int.tryParse(masteryController.text.trim()) ?? 0,
              };

              try {
                if (isEdit) {
                  await provider.updateQuestion(question.id, input);
                } else {
                  await provider.createQuestion(input);
                }
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
                }
              }
            },
            child: Text(isEdit ? '保存' : '创建'),
          ),
        ],
      );
    },
  );
}

Future<void> _showAICreateDialog(
  BuildContext context, {
  String presetSubject = '',
  String presetUnit = '',
}) async {
  final provider = context.read<AppProvider>();
  final subjectController = TextEditingController(text: presetSubject);
  final unitController = TextEditingController(text: presetUnit);
  final topicController = TextEditingController(text: presetUnit);
  final countController = TextEditingController(text: '3');
  final difficultyController = TextEditingController(text: '3');
  var generating = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('AI创建题库内容'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogInput(subjectController, '科目'),
                  _dialogInput(unitController, '单元（可选）'),
                  _dialogInput(topicController, '主题（可选，默认取单元）'),
                  _dialogInput(countController, '题目数量'),
                  _dialogInput(difficultyController, '难度(1-5)'),
                  if (generating)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Theme.of(
                          ctx,
                        ).colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Expanded(child: Text('AI 正在生成中...')),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: generating ? null : () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: generating
                    ? null
                    : () async {
                        final subject = _normalizeSubject(
                          subjectController.text,
                        );
                        final unit = unitController.text.trim();
                        final topic = topicController.text.trim().isNotEmpty
                            ? topicController.text.trim()
                            : (unit.isNotEmpty ? unit : subject);
                        final count =
                            int.tryParse(countController.text.trim()) ?? 3;
                        final difficulty =
                            int.tryParse(difficultyController.text.trim()) ?? 3;

                        if (subject.isEmpty) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('科目不能为空')),
                            );
                          }
                          return;
                        }
                        if (topic.isEmpty) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('主题不能为空')),
                            );
                          }
                          return;
                        }

                        setDialogState(() => generating = true);
                        try {
                          await provider.generateAIQuestions({
                            'topic': topic,
                            'subject': subject,
                            'scope': 'unit',
                            'count': count,
                            'difficulty': difficulty,
                          }, persist: true);

                          if (unit.isNotEmpty) {
                            final created = provider.aiGeneratedQuestions
                                .where((q) => q.id.trim().isNotEmpty)
                                .toList(growable: false);
                            for (final q in created) {
                              final input = _questionToInput(
                                q,
                                subject: subject,
                                unit: unit,
                              );
                              await provider.updateQuestion(q.id, input);
                            }
                            await provider.fetchQuestions(force: true);
                          }

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'AI创建完成：${provider.aiGeneratedQuestions.length} 道题',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('AI创建失败：$e')),
                            );
                          }
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => generating = false);
                          }
                        }
                      },
                icon: generating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(generating ? '生成中...' : '创建并写入题库'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _renameSubject(BuildContext context, String subject) async {
  final next = await _promptText(
    context,
    title: '重命名科目',
    label: '新科目名',
    initialValue: subject,
  );
  if (next == null) return;
  if (_sameText(next, subject)) return;
  if (!context.mounted) return;

  final provider = context.read<AppProvider>();
  final targets = provider.questions
      .where((q) => _sameText(_normalizeSubject(q.subject), subject))
      .toList(growable: false);
  if (targets.isEmpty) return;

  try {
    for (final q in targets) {
      await provider.updateQuestion(q.id, _questionToInput(q, subject: next));
    }
    await provider.fetchQuestions(force: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已重命名科目，共更新 ${targets.length} 道题')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('重命名失败：$e')));
    }
  }
}

Future<void> _deleteSubject(BuildContext context, String subject) async {
  final provider = context.read<AppProvider>();
  final targets = provider.questions
      .where((q) => _sameText(_normalizeSubject(q.subject), subject))
      .toList(growable: false);
  if (targets.isEmpty) return;

  final confirmed = await _confirm(
    context,
    title: '删除科目',
    message: '将删除科目“$subject”下的 ${targets.length} 道题，是否继续？',
  );
  if (!confirmed) return;

  try {
    for (final q in targets) {
      await provider.deleteQuestion(q.id);
    }
    await provider.fetchQuestions(force: true);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除科目“$subject”下全部题目')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }
}

Future<void> _renameUnit(
  BuildContext context,
  String subject,
  String unit,
) async {
  final next = await _promptText(
    context,
    title: '重命名单元',
    label: '新单元名',
    initialValue: unit == _unknownUnit ? '' : unit,
  );
  if (next == null) return;
  if (_sameText(next, unit)) return;
  if (!context.mounted) return;

  final provider = context.read<AppProvider>();
  final targets = provider.questions
      .where((q) => _sameText(_normalizeSubject(q.subject), subject))
      .where((q) => _sameText(_extractUnit(q), unit))
      .toList(growable: false);
  if (targets.isEmpty) return;

  try {
    for (final q in targets) {
      await provider.updateQuestion(
        q.id,
        _questionToInput(q, subject: subject, unit: next),
      );
    }
    await provider.fetchQuestions(force: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已重命名单元，共更新 ${targets.length} 道题')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('重命名失败：$e')));
    }
  }
}

Future<void> _deleteUnit(
  BuildContext context,
  String subject,
  String unit,
) async {
  final provider = context.read<AppProvider>();
  final targets = provider.questions
      .where((q) => _sameText(_normalizeSubject(q.subject), subject))
      .where((q) => _sameText(_extractUnit(q), unit))
      .toList(growable: false);
  if (targets.isEmpty) return;

  final confirmed = await _confirm(
    context,
    title: '删除单元',
    message: '将删除单元“$unit”下的 ${targets.length} 道题，是否继续？',
  );
  if (!confirmed) return;

  try {
    for (final q in targets) {
      await provider.deleteQuestion(q.id);
    }
    await provider.fetchQuestions(force: true);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除单元“$unit”下全部题目')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }
}

Future<void> _deleteSingleQuestion(
  BuildContext context,
  Question question,
) async {
  final provider = context.read<AppProvider>();
  final confirmed = await _confirm(context, title: '删除题目', message: '确定删除该题目？');
  if (!confirmed) return;
  if (!context.mounted) return;
  try {
    await provider.deleteQuestion(question.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('题目已删除')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }
}

Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(ctx).pop(value);
            },
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认'),
          ),
        ],
      );
    },
  );
  return result == true;
}

Widget _dialogInput(
  TextEditingController controller,
  String label, {
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

Map<String, dynamic> _questionToInput(
  Question q, {
  String? subject,
  String? unit,
}) {
  return {
    'title': q.title,
    'stem': q.stem,
    'type': q.type,
    'subject': subject ?? _normalizeSubject(q.subject),
    'source': q.source,
    'options': q.options.map((e) => e.toJson()).toList(),
    'answer_key': q.answerKey,
    'tags': unit == null ? q.tags : _mergeUnitTag(q.tags, unit),
    'difficulty': q.difficulty,
    'mastery_level': q.masteryLevel,
  };
}

Map<String, List<Question>> _groupByUnit(List<Question> questions) {
  final map = <String, List<Question>>{};
  for (final q in questions) {
    final unit = _extractUnit(q);
    map.putIfAbsent(unit, () => <Question>[]).add(q);
  }
  final entries = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return {for (final item in entries) item.key: item.value};
}

String _normalizeSubject(String raw) {
  final subject = raw.trim();
  if (subject.isEmpty) return 'general';
  return subject;
}

String _unitForEdit(Question q) {
  final unit = _extractUnit(q);
  return unit == _unknownUnit ? '' : unit;
}

List<String> _parseCsv(String raw) {
  final result = <String>[];
  for (final item in raw.split(',')) {
    final trimmed = item.trim();
    if (trimmed.isEmpty) continue;
    if (result.any((v) => _sameText(v, trimmed))) continue;
    result.add(trimmed);
  }
  return result;
}

List<String> _nonUnitTags(Question q) {
  final result = <String>[];
  for (final raw in q.tags) {
    final tag = raw.trim();
    if (tag.isEmpty) continue;
    if (_isUnitTag(tag)) continue;
    result.add(tag);
  }
  return result;
}

List<String> _mergeUnitTag(List<String> rawTags, String unit) {
  final result = <String>[];
  final normalizedUnit = unit.trim();
  if (normalizedUnit.isNotEmpty) {
    result.add('unit:$normalizedUnit');
  }
  for (final raw in rawTags) {
    final tag = raw.trim();
    if (tag.isEmpty || _isUnitTag(tag)) continue;
    if (result.any((v) => _sameText(v, tag))) continue;
    result.add(tag);
  }
  return result;
}

String _extractUnit(Question q) {
  for (final raw in q.tags) {
    final tag = raw.trim();
    if (tag.isEmpty) continue;

    final lower = tag.toLowerCase();
    if (lower.startsWith('unit:')) {
      final value = tag.substring(5).trim();
      if (value.isNotEmpty) return value;
    }
    if (tag.startsWith('单元:')) {
      final value = tag.substring(3).trim();
      if (value.isNotEmpty) return value;
    }
  }

  for (final raw in q.tags) {
    final tag = raw.trim();
    if (tag.isEmpty) continue;
    final lower = tag.toLowerCase();
    if (lower == 'ai_generated' ||
        lower == 'unit' ||
        lower == 'retest' ||
        lower == 'network_search') {
      continue;
    }
    if (_isUnitTag(tag)) continue;
    return tag;
  }

  return _unknownUnit;
}

bool _isUnitTag(String tag) {
  final lower = tag.trim().toLowerCase();
  return lower.startsWith('unit:') || tag.trim().startsWith('单元:');
}

bool _sameText(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

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

String _sourceZh(String raw) {
  switch (raw) {
    case 'wrong_book':
      return '错题本';
    case 'past_exam':
      return '历年真题';
    case 'paper':
      return '试卷';
    case 'unit_test':
      return '单元测试';
    case 'ai_generated':
      return 'AI生成';
    default:
      return raw;
  }
}
