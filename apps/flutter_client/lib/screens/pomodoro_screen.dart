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
        title: const Text('专注计时'),
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
                child: Center(child: Text('暂无专注记录')),
              )
            else
              ...sessions.map((s) => _sessionCard(s)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStartDialog(context),
        icon: const Icon(Icons.play_arrow),
        label: const Text('开始'),
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
            const Text('进行中的专注', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('任务: ${running.taskTitle}'),
            Text(
              '时长: ${running.durationMinutes} 分钟, 休息: ${running.breakMinutes} 分钟',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: () async {
                    await provider.endPomodoro(running.id, status: 'completed');
                  },
                  child: const Text('完成'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    await provider.endPomodoro(running.id, status: 'canceled');
                  },
                  child: const Text('取消'),
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
          '状态: ${_statusZh(session.status)} | ${session.durationMinutes}m + ${session.breakMinutes}m\n结束时间: $ended',
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
          title: const Text('开始专注'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: taskController,
                decoration: const InputDecoration(labelText: '任务名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '专注时长(分钟)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: breakController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '休息时长(分钟)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final task = taskController.text.trim();
                if (task.isEmpty) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(const SnackBar(content: Text('任务名称不能为空')));
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
                    ).showSnackBar(SnackBar(content: Text('开始失败：$e')));
                  }
                }
              },
              child: const Text('开始'),
            ),
          ],
        );
      },
    );
  }

  String _statusZh(String status) {
    switch (status) {
      case 'running':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'canceled':
        return '已取消';
      default:
        return status;
    }
  }
}
