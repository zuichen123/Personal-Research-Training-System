import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../providers/app_provider.dart';
import 'question_detail_screen.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  String _subjectFilter = '';
  String _sourceFilter = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final loading = provider.isSectionLoading(DataSection.questions);
    final all = provider.questions;
    final questions = all
        .where((item) {
          if (_subjectFilter.isNotEmpty &&
              item.subject.toLowerCase() != _subjectFilter.toLowerCase()) {
            return false;
          }
          if (_sourceFilter.isNotEmpty &&
              item.source.toLowerCase() != _sourceFilter.toLowerCase()) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

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
      body: Column(
        children: [
          _filters(all),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.fetchQuestions(force: true),
              child: _buildBody(provider, questions, loading),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('新建题目'),
      ),
    );
  }

  Widget _filters(List<Question> questions) {
    final subjects = <String>{
      for (final q in questions)
        if (q.subject.trim().isNotEmpty) q.subject.trim(),
    }.toList()
      ..sort();
    final sources = <String>{
      for (final q in questions)
        if (q.source.trim().isNotEmpty) q.source.trim(),
    }.toList()
      ..sort();

    final hasFilter = _subjectFilter.isNotEmpty || _sourceFilter.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _subjectFilter.isEmpty ? null : _subjectFilter,
              decoration: const InputDecoration(
                labelText: '科目筛选',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: subjects
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _subjectFilter = v ?? ''),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _sourceFilter.isEmpty ? null : _sourceFilter,
              decoration: const InputDecoration(
                labelText: '来源筛选',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: sources
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(_sourceZh(e))))
                  .toList(),
              onChanged: (v) => setState(() => _sourceFilter = v ?? ''),
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: '清除筛选',
              onPressed: () {
                setState(() {
                  _subjectFilter = '';
                  _sourceFilter = '';
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(
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
        children: [
          const SizedBox(height: 64),
          Center(
            child: Column(
              children: [
                Icon(Icons.quiz_outlined,
                    size: 64,
                    color: Colors.blue.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                const Text('暂无题目',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('点击右下角按钮新建第一个题目',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
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
                    fontSize: 14),
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
                  label: Text(q.subject, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Chip(
                  label: Text(_sourceZh(q.source),
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Chip(
                  label: Text(_typeZh(q.type),
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text('掌握:${q.masteryLevel}%',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await _showEditDialog(context, question: q);
                } else if (value == 'delete') {
                  await context.read<AppProvider>().deleteQuestion(q.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _difficultyColor(int difficulty) {
    if (difficulty <= 1) return Colors.green;
    if (difficulty == 2) return Colors.lightGreen;
    if (difficulty == 3) return Colors.orange;
    if (difficulty == 4) return Colors.deepOrange;
    return Colors.red;
  }

  Future<void> _showEditDialog(
    BuildContext context, {
    Question? question,
  }) async {
    final provider = context.read<AppProvider>();
    final isEdit = question != null;
    final titleController = TextEditingController(text: question?.title ?? '');
    final stemController = TextEditingController(text: question?.stem ?? '');
    final subjectController = TextEditingController(
      text: question?.subject ?? 'general',
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
      text: question?.tags.join(',') ?? '',
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
                final input = {
                  'title': titleController.text.trim(),
                  'stem': stemController.text.trim(),
                  'type': typeController.text.trim(),
                  'subject': subjectController.text.trim(),
                  'source': sourceController.text.trim(),
                  'options': <Map<String, dynamic>>[],
                  'answer_key': answerKeyController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  'tags': tagsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
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
}
