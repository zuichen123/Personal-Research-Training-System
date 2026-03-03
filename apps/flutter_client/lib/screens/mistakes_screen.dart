import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mistake.dart';
import '../models/question.dart';
import '../providers/app_provider.dart';

class MistakesScreen extends StatefulWidget {
  const MistakesScreen({super.key});

  @override
  State<MistakesScreen> createState() => _MistakesScreenState();
}

class _MistakesScreenState extends State<MistakesScreen> {
  String? _selectedQuestionId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final mistakes = provider.mistakes;
    final loading = provider.isSectionLoading(DataSection.mistakes);
    final questions = provider.questions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('错题本'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchMistakes(force: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedQuestionId,
                    decoration: const InputDecoration(
                      labelText: '按题目筛选',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: questions
                        .map(
                          (q) => DropdownMenuItem(
                            value: q.id,
                            child: Text(
                              q.title.isNotEmpty ? q.title : q.stem,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => _selectedQuestionId = v);
                      provider.fetchMistakes(force: true, questionId: v);
                    },
                  ),
                ),
                if (_selectedQuestionId != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: '清除筛选',
                    onPressed: () {
                      setState(() => _selectedQuestionId = null);
                      provider.fetchMistakes(force: true);
                    },
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.fetchMistakes(force: true),
              child: _buildBody(provider, mistakes, loading, questions),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('添加错题'),
      ),
    );
  }

  Widget _buildBody(
    AppProvider provider,
    List<MistakeRecord> mistakes,
    bool loading,
    List<Question> questions,
  ) {
    if (loading && mistakes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && mistakes.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Center(child: Text('加载失败：${provider.errorMessage}')),
        ],
      );
    }

    if (mistakes.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 64),
          Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text('暂无错题记录',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('做题后答错的题目会自动出现在这里',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: mistakes.length,
      itemBuilder: (context, index) {
        final m = mistakes[index];
        // Try to find the question title
        String questionLabel = '题目ID: ${m.questionId}';
        for (final q in questions) {
          if (q.id == m.questionId) {
            questionLabel = q.title.isNotEmpty ? q.title : q.stem;
            break;
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _difficultyColor(m.difficulty),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '难度 ${m.difficulty}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(m.subject, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () async {
                        await context.read<AppProvider>().deleteMistake(m.id);
                      },
                      icon: const Icon(Icons.delete_outline, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  questionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text('掌握度: ${m.masteryLevel}%'),
                const SizedBox(height: 6),
                Text('你的答案: ${m.userAnswer.join(", ")}'),
                const SizedBox(height: 6),
                Text(
                  '反馈: ${m.feedback}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13),
                ),
                if (m.reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('错因: ${m.reason}',
                      style: const TextStyle(fontSize: 13)),
                ],
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

  Future<void> _showCreateDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    if (provider.questions.isEmpty) {
      await provider.fetchQuestions(force: true);
      if (!context.mounted) return;
    }

    String? selectedQuestionId =
        provider.questions.isNotEmpty ? provider.questions.first.id : null;
    final feedbackController = TextEditingController();
    final reasonController = TextEditingController();
    final answerController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('添加错题'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (provider.questions.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedQuestionId,
                        decoration:
                            const InputDecoration(labelText: '选择题目'),
                        items: provider.questions
                            .map(
                              (Question q) => DropdownMenuItem(
                                value: q.id,
                                child: Text(
                                  q.title.isEmpty ? q.stem : q.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedQuestionId = value),
                      ),
                    const SizedBox(height: 12),
                    _input(answerController, '你的错误答案(逗号分隔)'),
                    _input(feedbackController, '反馈/备注', maxLines: 2),
                    _input(reasonController, '错误原因', maxLines: 2),
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
                    if (selectedQuestionId == null ||
                        selectedQuestionId!.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('请选择题目')),
                      );
                      return;
                    }
                    // Find the question to get its fields
                    Question? question;
                    for (final q in provider.questions) {
                      if (q.id == selectedQuestionId) {
                        question = q;
                        break;
                      }
                    }
                    final input = {
                      'question_id': selectedQuestionId,
                      'subject': question?.subject ?? 'general',
                      'difficulty': question?.difficulty ?? 3,
                      'mastery_level': question?.masteryLevel ?? 0,
                      'user_answer': answerController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      'feedback': feedbackController.text.trim(),
                      'reason': reasonController.text.trim(),
                    };
                    try {
                      await provider.createMistake(input);
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('错题已添加')),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('添加失败：$e')),
                        );
                      }
                    }
                  },
                  child: const Text('添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _input(
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
}
