import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mistake.dart';
import '../providers/app_provider.dart';

class MistakesScreen extends StatefulWidget {
  const MistakesScreen({super.key});

  @override
  State<MistakesScreen> createState() => _MistakesScreenState();
}

class _MistakesScreenState extends State<MistakesScreen> {
  final _questionIdFilter = TextEditingController();

  @override
  void dispose() {
    _questionIdFilter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final mistakes = provider.mistakes;
    final loading = provider.isSectionLoading(DataSection.mistakes);

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
                  child: TextField(
                    controller: _questionIdFilter,
                    decoration: const InputDecoration(
                      labelText: '按题目ID筛选',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    provider.fetchMistakes(
                      force: true,
                      questionId: _questionIdFilter.text.trim(),
                    );
                  },
                  child: const Text('筛选'),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.fetchMistakes(force: true),
              child: _buildBody(provider, mistakes, loading),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    AppProvider provider,
    List<MistakeRecord> mistakes,
    bool loading,
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
        children: const [
          SizedBox(height: 96),
          Center(child: Text('暂无错题记录')),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: mistakes.length,
      itemBuilder: (context, index) {
        final m = mistakes[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '题目ID: ${m.questionId}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await context.read<AppProvider>().deleteMistake(m.id);
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('科目: ${m.subject} | 难度: ${m.difficulty}/5'),
                Text('掌握度: ${m.masteryLevel}%'),
                const SizedBox(height: 8),
                Text('你的答案: ${m.userAnswer.join(", ")}'),
                const SizedBox(height: 8),
                Text(
                  '反馈: ${m.feedback}',
                  style: const TextStyle(color: Colors.red),
                ),
                if (m.reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('错因: ${m.reason}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
