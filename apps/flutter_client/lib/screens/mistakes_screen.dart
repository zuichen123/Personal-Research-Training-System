import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class MistakesScreen extends StatelessWidget {
  const MistakesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final mistakes = provider.mistakes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('错题本'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchMistakes(),
          ),
        ],
      ),
      body: provider.isLoading && mistakes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : mistakes.isEmpty
              ? const Center(child: Text('太棒了！没有错题记录。'))
              : ListView.builder(
                  itemCount: mistakes.length,
                  itemBuilder: (context, index) {
                    final m = mistakes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('题目 ID: ${m.questionId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('你的答案: ${m.userAnswer.join(", ")}'),
                            const SizedBox(height: 8),
                            Text('解析: ${m.feedback}', style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
