import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/practice.dart';
import '../models/question.dart';
import '../providers/app_provider.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final attempts = provider.attempts;
    final loading = provider.isSectionLoading(DataSection.attempts);

    return Scaffold(
      appBar: AppBar(
        title: const Text('练习与AI批阅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchAttempts(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchAttempts(force: true),
        child: _buildBody(provider, attempts, loading),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPracticeDialog(context),
        label: const Text('开始练习'),
        icon: const Icon(Icons.play_arrow),
      ),
    );
  }

  Widget _buildBody(
    AppProvider provider,
    List<PracticeAttempt> attempts,
    bool loading,
  ) {
    if (loading && attempts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && attempts.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Center(child: Text('加载失败：${provider.errorMessage}')),
        ],
      );
    }

    if (attempts.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 64),
          Center(
            child: Column(
              children: [
                Icon(Icons.edit_note_outlined,
                    size: 64,
                    color: Colors.purple.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                const Text('暂无练习记录',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('点击右下角按钮开始你的第一次练习',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: attempts.length,
      itemBuilder: (context, index) {
        final a = attempts[index];
        final scoreColor = a.score >= 80
            ? Colors.green
            : a.score >= 60
                ? Colors.orange
                : Colors.red;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: scoreColor,
              child: Text(
                a.score.toStringAsFixed(0),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text('题目ID: ${a.questionId}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Icon(
                  a.correct ? Icons.check_circle : Icons.cancel,
                  color: a.correct ? Colors.green : Colors.red,
                  size: 20,
                ),
              ],
            ),
            subtitle: Text(
              '反馈: ${a.feedback}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing:
                Text(a.submittedAt.toLocal().toString().split(' ')[0],
                    style: const TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }

  Future<void> _showPracticeDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    if (provider.questions.isEmpty) {
      await provider.fetchQuestions(force: true);
      if (!context.mounted) return;
    }
    String? selectedQuestionId = provider.questions.isEmpty
        ? null
        : provider.questions.first.id;
    final questionIdController = TextEditingController();
    final answerController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('提交练习'),
              content: Column(
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
                  const SizedBox(height: 8),
                  TextField(
                    controller: questionIdController,
                    decoration: const InputDecoration(
                      labelText: '或手动输入题目ID',
                      hintText: '可留空（使用下拉选择）',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: answerController,
                    decoration: const InputDecoration(
                      labelText: '你的答案',
                      hintText: '多点答案请用逗号分隔',
                    ),
                    maxLines: 3,
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
                    final manualId = questionIdController.text.trim();
                    final questionId = manualId.isNotEmpty
                        ? manualId
                        : (selectedQuestionId ?? '');
                    final answers = answerController.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();

                    if (questionId.isEmpty || answers.isEmpty) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('题目ID和答案不能为空')),
                        );
                      }
                      return;
                    }

                    try {
                      await provider.submitPractice(questionId, answers);
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('提交成功')));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('提交失败：$e')));
                      }
                    }
                  },
                  child: const Text('提交'),
                ),
              ],
            );
          },
        );
      },
    );

    questionIdController.dispose();
    answerController.dispose();
  }
}
