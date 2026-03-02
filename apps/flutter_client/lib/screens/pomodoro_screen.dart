import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pomodoro.dart';
import '../providers/app_provider.dart';

class PomodoroScreen extends StatelessWidget {
  const PomodoroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final sessions = provider.pomodoroSessions;
    final loading = provider.isSectionLoading(DataSection.pomodoro);
    final running = provider.runningPomodoro;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchPomodoroSessions(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchPomodoroSessions(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (running != null) _runningCard(context, provider, running),
            const SizedBox(height: 12),
            if (loading && sessions.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: Text('No pomodoro sessions yet.')),
              )
            else
              ...sessions.map((s) => _sessionCard(s)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStartDialog(context),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start'),
      ),
    );
  }

  Widget _runningCard(
    BuildContext context,
    AppProvider provider,
    PomodoroSession running,
  ) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Running Session',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Task: ${running.taskTitle}'),
            Text(
              'Duration: ${running.durationMinutes} min, Break: ${running.breakMinutes} min',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: () async {
                    await provider.endPomodoro(running.id, status: 'completed');
                  },
                  child: const Text('Complete'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    await provider.endPomodoro(running.id, status: 'canceled');
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(PomodoroSession session) {
    final ended = session.endedAt?.toLocal().toString().split('.').first ?? '-';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(session.taskTitle),
        subtitle: Text(
          'Status: ${session.status} | ${session.durationMinutes}m + ${session.breakMinutes}m\nEnd: $ended',
        ),
      ),
    );
  }

  Future<void> _showStartDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final taskController = TextEditingController();
    final durationController = TextEditingController(text: '25');
    final breakController = TextEditingController(text: '5');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Start Pomodoro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: taskController,
                decoration: const InputDecoration(labelText: 'Task title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration (min)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: breakController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Break (min)'),
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
                final task = taskController.text.trim();
                if (task.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Task title is required.')),
                  );
                  return;
                }

                final duration =
                    int.tryParse(durationController.text.trim()) ?? 25;
                final breakMin = int.tryParse(breakController.text.trim()) ?? 5;

                try {
                  await provider.startPomodoro(
                    taskTitle: task,
                    durationMinutes: duration,
                    breakMinutes: breakMin,
                  );
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text('Start failed: $e')));
                  }
                }
              },
              child: const Text('Start'),
            ),
          ],
        );
      },
    );

    taskController.dispose();
    durationController.dispose();
    breakController.dispose();
  }
}
