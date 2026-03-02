import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mistake.dart';
import '../providers/app_provider.dart';

class MistakesScreen extends StatelessWidget {
  const MistakesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final mistakes = provider.mistakes;
    final loading = provider.isSectionLoading(DataSection.mistakes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wrong Question Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchMistakes(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchMistakes(force: true),
        child: _buildBody(provider, mistakes, loading),
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
          Center(child: Text('Load failed: ${provider.errorMessage}')),
        ],
      );
    }

    if (mistakes.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 96),
          Center(child: Text('No mistake records.')),
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
                Text(
                  'Question ID: ${m.questionId}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('Subject: ${m.subject} | Difficulty: ${m.difficulty}/5'),
                Text('Mastery: ${m.masteryLevel}%'),
                const SizedBox(height: 8),
                Text('Your answer: ${m.userAnswer.join(", ")}'),
                const SizedBox(height: 8),
                Text(
                  'Feedback: ${m.feedback}',
                  style: const TextStyle(color: Colors.red),
                ),
                if (m.reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Reason: ${m.reason}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
