import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/practice.dart';
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
        title: const Text('Practice + AI Grading'),
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
        label: const Text('Start Practice'),
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
          Center(child: Text('Load failed: ${provider.errorMessage}')),
        ],
      );
    }

    if (attempts.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 96),
          Center(child: Text('No practice records yet.')),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: attempts.length,
      itemBuilder: (context, index) {
        final a = attempts[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: a.correct ? Colors.green : Colors.red,
              child: Icon(
                a.correct ? Icons.check : Icons.close,
                color: Colors.white,
              ),
            ),
            title: Text('Score: ${a.score.toStringAsFixed(1)}'),
            subtitle: Text(a.feedback),
            trailing: Text(a.submittedAt.toLocal().toString().split(' ')[0]),
          ),
        );
      },
    );
  }

  Future<void> _showPracticeDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final questionIdController = TextEditingController();
    final answerController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Submit Practice'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionIdController,
                decoration: const InputDecoration(
                  labelText: 'Question ID',
                  hintText: 'Paste question id',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: answerController,
                decoration: const InputDecoration(
                  labelText: 'Your answer',
                  hintText: 'Use comma to separate multiple points',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final questionId = questionIdController.text.trim();
                final answers = answerController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                if (questionId.isEmpty || answers.isEmpty) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Question ID and answer are required.'),
                      ),
                    );
                  }
                  return;
                }

                try {
                  await provider.submitPractice(questionId, answers);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Submitted successfully.')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Submit failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    questionIdController.dispose();
    answerController.dispose();
  }
}
