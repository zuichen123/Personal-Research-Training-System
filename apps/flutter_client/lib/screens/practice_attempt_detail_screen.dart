import 'package:flutter/material.dart';

import '../models/practice.dart';
import '../models/question.dart';
import '../widgets/ai_formula_text.dart';
import 'question_detail_screen.dart';

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return '$y-$mo-$d $h:$mi';
}

class PracticeAttemptDetailScreen extends StatelessWidget {
  const PracticeAttemptDetailScreen({
    super.key,
    required this.attempt,
    required this.question,
    required this.allAttempts,
  });

  final PracticeAttempt attempt;
  final Question? question;
  final List<PracticeAttempt> allAttempts;

  @override
  Widget build(BuildContext context) {
    final sameQuestionAttempts = allAttempts
        .where((item) => item.questionId == attempt.questionId)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('练习详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(context),
          const SizedBox(height: 12),
          _questionCard(context),
          const SizedBox(height: 12),
          _answerCard(context),
          const SizedBox(height: 12),
          _aiFeedbackCard(context),
          if (sameQuestionAttempts.length > 1) ...[
            const SizedBox(height: 12),
            _historyCard(context, sameQuestionAttempts),
          ],
          const SizedBox(height: 12),
          _submitTimeCard(context),
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context) {
    final scoreColor = attempt.score >= 80
        ? Colors.green
        : attempt.score >= 60
        ? Colors.orange
        : Colors.red;
    final statusText = attempt.correct ? '正确' : '错误';
    final statusColor = attempt.correct ? Colors.green : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  backgroundColor: scoreColor.withValues(alpha: 0.15),
                  label: Text(
                    '得分 ${attempt.score.toStringAsFixed(1)}',
                    style: TextStyle(color: scoreColor),
                  ),
                ),
                Chip(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  label: Text(statusText, style: TextStyle(color: statusColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionCard(BuildContext context) {
    if (question == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('未找到对应题目，可能已被删除。'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AIFormulaText(
              question!.title.isNotEmpty ? question!.title : '题目',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            AIFormulaText(question!.stem),
            if (question!.options.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...question!.options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: AIFormulaText('${option.key}. ${option.text}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _answerCard(BuildContext context) {
    final answerWidgets = attempt.userAnswer.isEmpty
        ? <Widget>[const Text('-')]
        : attempt.userAnswer
              .map(
                (answer) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AIFormulaText(answer, selectable: true),
                ),
              )
              .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('我的作答', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...answerWidgets,
                ],
              ),
            ),
            if (question != null) ...[
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () {
                  if (question == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuestionDetailScreen(
                        question: question!,
                        questionNumber: 1,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.replay),
                label: const Text('重新作答'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _submitTimeCard(BuildContext context) {
    final time = _formatTime(attempt.submittedAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 18),
            const SizedBox(width: 8),
            Text('提交时间: $time', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _aiFeedbackCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final analysis = attempt.feedback.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            title: Text(
              '题目解析',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: cs.primary,
              ),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AIFormulaText(
                  analysis.isEmpty ? '暂无题目解析' : analysis,
                  selectable: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyCard(
    BuildContext context,
    List<PracticeAttempt> sameQuestionAttempts,
  ) {
    final sorted = sameQuestionAttempts.toList(growable: false)
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('同题历史作答', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...sorted.map((item) {
              final isCurrent = item.id == attempt.id;
              final color = item.correct ? Colors.green : Colors.red;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatTime(item.submittedAt),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      item.score.toStringAsFixed(1),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      const Text('当前', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
