import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/practice.dart';
import '../models/question.dart';
import '../providers/app_provider.dart';
import '../widgets/ai_formula_text.dart';
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
        title: const Text('Practice'),
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
        label: const Text('Start Session'),
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
          SizedBox(height: 72),
          Center(
            child: Column(
              children: [
                Icon(Icons.edit_note_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No practice history yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap "Start Session" to begin',
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
      itemCount: latestAttempts.length,
      itemBuilder: (context, index) {
        final a = latestAttempts[index];
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
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    stem.isEmpty ? 'Question not found' : stem,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    'Attempts $count',
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
              'Subject: ${subject.isEmpty ? '-' : subject}  Type: $type\nDuration: ${_formatDuration(a.elapsedSeconds)}  Feedback: ${a.feedback}',
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
                  tooltip: 'Delete',
                  onPressed: () async {
                    await _deleteAttempt(context, a.id);
                  },
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
      },
    );
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
        return 'Single Choice';
      case 'multi_choice':
        return 'Multiple Choice';
      case 'short_answer':
        return 'Short Answer';
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
          title: const Text('Delete practice attempt'),
          content: const Text('Are you sure you want to delete this attempt?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
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
      ).showSnackBar(const SnackBar(content: Text('Attempt deleted')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      final message =
          context.read<AppProvider>().errorMessage ?? 'Delete failed';
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
}
