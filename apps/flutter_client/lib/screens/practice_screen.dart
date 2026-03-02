import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final attempts = provider.attempts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('练习与 AI 批改'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchAttempts(),
          ),
        ],
      ),
      body: provider.isLoading && attempts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : attempts.isEmpty
              ? const Center(child: Text('暂无练习记录。'))
              : ListView.builder(
                  itemCount: attempts.length,
                  itemBuilder: (context, index) {
                    final a = attempts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: a.correct ? Colors.green : Colors.red,
                          child: Icon(a.correct ? Icons.check : Icons.close, color: Colors.white),
                        ),
                        title: Text('分数: ${a.score.toStringAsFixed(1)}'),
                        subtitle: Text(a.feedback),
                        trailing: Text(a.submittedAt.toLocal().toString().split(' ')[0]),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Start new practice session
        },
        label: const Text('开始练习'),
        icon: const Icon(Icons.play_arrow),
      ),
    );
  }
}
