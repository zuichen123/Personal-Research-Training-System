import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pomodoro.dart';
import '../providers/app_provider.dart';

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      if (provider.runningPomodoro != null) {
        setState(() {}); // 刷新倒计时
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

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
            if (running != null) const SizedBox(height: 12),
            if (loading && sessions.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 64,
                        color: Colors.teal.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '暂无专注记录',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '点击右下角按钮开始一次专注',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...sessions.map((s) => _sessionCard(context, s)),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // ── 计算倒计时 ──
    final endTime = running.startedAt.add(
      Duration(minutes: running.durationMinutes),
    );
    final remaining = endTime.difference(DateTime.now());
    final totalSeconds = running.durationMinutes * 60;
    final elapsedSeconds = totalSeconds - remaining.inSeconds;
    final progress = totalSeconds > 0
        ? (elapsedSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final isOvertime = remaining.isNegative;
    final displayMinutes = isOvertime ? 0 : remaining.inMinutes;
    final displaySeconds = isOvertime ? 0 : remaining.inSeconds % 60;

    return Card(
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer,
              cs.primary.withValues(alpha: 0.18),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: cs.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  '进行中的专注',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 倒计时视觉 ──
            Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.12),
                        color: isOvertime ? Colors.red : cs.primary,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isOvertime
                              ? '已超时'
                              : '${displayMinutes.toString().padLeft(2, '0')}:${displaySeconds.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: isOvertime ? 16 : 28,
                            fontWeight: FontWeight.bold,
                            color: isOvertime
                                ? Colors.red
                                : cs.onPrimaryContainer,
                          ),
                        ),
                        if (!isOvertime)
                          Text(
                            '剩余',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            Text(
              '任务: ${running.taskTitle}',
              style: TextStyle(
                fontSize: 15,
                color: cs.onPrimaryContainer,
              ),
            ),
            Text(
              '时长: ${running.durationMinutes} 分钟, 休息: ${running.breakMinutes} 分钟',
              style: TextStyle(color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    await provider.endPomodoro(running.id, status: 'completed');
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('完成'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await provider.endPomodoro(running.id, status: 'canceled');
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('取消'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    await _deleteSession(context, running.id);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(BuildContext context, PomodoroSession session) {
    final ended = session.endedAt != null
        ? _formatTime(session.endedAt!)
        : '-';
    final statusColor = session.status == 'completed'
        ? Colors.green
        : session.status == 'canceled'
            ? Colors.grey
            : Colors.orange;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          radius: 18,
          child: Icon(
            _statusIcon(session.status),
            color: Colors.white,
            size: 18,
          ),
        ),
        title: Text(session.taskTitle),
        subtitle: Text(
          '${_statusZh(session.status)} | ${session.durationMinutes}m + ${session.breakMinutes}m\n结束: $ended',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: '删除',
          onPressed: () async {
            await _deleteSession(context, session.id);
          },
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'running':
        return Icons.play_arrow;
      case 'completed':
        return Icons.check;
      case 'canceled':
        return Icons.close;
      default:
        return Icons.help_outline;
    }
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
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(const SnackBar(content: Text('任务名称不能为空')));
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
                  if (ctx.mounted) Navigator.of(ctx).pop();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('开始失败：$e')));
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

  Future<void> _deleteSession(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('删除计时记录'),
          content: const Text('确认删除这条专注计时记录？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await context.read<AppProvider>().deletePomodoro(id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已删除专注计时记录')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      final message = context.read<AppProvider>().errorMessage ?? '删除失败';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
