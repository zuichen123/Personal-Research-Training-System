import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class QuestionsScreen extends StatelessWidget {
  const QuestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final questions = provider.questions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('题库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchQuestions(),
          ),
        ],
      ),
      body: provider.isLoading && questions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : questions.isEmpty
              ? const Center(child: Text('未找到题目。'))
              : ListView.builder(
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final q = questions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(q.title.isNotEmpty ? q.title : q.stem),
                        subtitle: Text('类型: ${q.type} | 难度: ${q.difficulty}'),
                        trailing: Chip(label: Text(q.tags.isNotEmpty ? q.tags.first : '无标签')),
                        onTap: () {
                          // TODO: Show question details
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add new question
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
