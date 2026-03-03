import 'package:flutter/material.dart';

import '../models/mistake.dart';
import '../models/question.dart';
import 'question_detail_screen.dart';

class MistakeDetailScreen extends StatelessWidget {
  const MistakeDetailScreen({
    super.key,
    required this.mistake,
    required this.question,
    required this.allMistakes,
  });

  final MistakeRecord mistake;
  final Question? question;
  final List<MistakeRecord> allMistakes;

  @override
  Widget build(BuildContext context) {
    final sameQuestionMistakes = allMistakes
        .where((item) => item.questionId == mistake.questionId)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('错题详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(context),
          const SizedBox(height: 12),
          _questionCard(context),
          const SizedBox(height: 12),
          _answerCard(context),
          const SizedBox(height: 12),
          _feedbackCard(context),
          if (sameQuestionMistakes.length > 1) ...[
            const SizedBox(height: 12),
            _historyCard(context, sameQuestionMistakes),
          ],
          const SizedBox(height: 12),
          _createdTimeCard(context),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final difficultyColor = _difficultyColor(mistake.difficulty);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              backgroundColor: difficultyColor.withValues(alpha: 0.15),
              label: Text(
                '难度 ${mistake.difficulty}',
                style: TextStyle(color: difficultyColor),
              ),
            ),
            Chip(label: Text('科目 ${mistake.subject}')),
            Chip(label: Text('掌握度 ${mistake.masteryLevel}%')),
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
            Text(
              question!.title.isNotEmpty ? question!.title : '题目',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(question!.stem),
            if (question!.options.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...question!.options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${option.key}. ${option.text}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _answerCard(BuildContext context) {
    final answerWidgets = mistake.userAnswer.isEmpty
        ? <Widget>[const Text('-')]
        : mistake.userAnswer
              .map(
                (answer) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SelectableText(answer),
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

  Widget _feedbackCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('错因与反馈', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(mistake.feedback.isEmpty ? '-' : mistake.feedback),
            if (mistake.reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('错因: ${mistake.reason}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _historyCard(
    BuildContext context,
    List<MistakeRecord> sameQuestionMistakes,
  ) {
    final sorted = sameQuestionMistakes.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('同题历史错题', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...sorted.map((item) {
              final isCurrent = item.id == mistake.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.createdAt.toLocal().toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          '难度${item.difficulty}  掌握${item.masteryLevel}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          const Text('当前', style: TextStyle(fontSize: 12)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '作答: ${item.userAnswer.join(", ")}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _createdTimeCard(BuildContext context) {
    final time = mistake.createdAt.toLocal().toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 18),
            const SizedBox(width: 8),
            Text('记录时间: $time', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Color _difficultyColor(int difficulty) {
    if (difficulty <= 1) return Colors.green;
    if (difficulty == 2) return Colors.lightGreen;
    if (difficulty == 3) return Colors.orange;
    if (difficulty == 4) return Colors.deepOrange;
    return Colors.red;
  }
}
