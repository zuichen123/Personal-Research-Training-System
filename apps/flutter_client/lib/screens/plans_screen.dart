import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plan.dart';
import '../providers/app_provider.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  String _typeFilter = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final loading = provider.isSectionLoading(DataSection.plans);
    final plans = provider.plans
        .where((item) {
          if (_typeFilter.isEmpty) return true;
          return item.planType == _typeFilter;
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchPlans(force: true),
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
                  child: DropdownButtonFormField<String>(
                    value: _typeFilter.isEmpty ? null : _typeFilter,
                    decoration: const InputDecoration(
                      labelText: '类型筛选',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'year_plan', child: Text('年计划')),
                      DropdownMenuItem(value: 'month_goal', child: Text('月目标')),
                      DropdownMenuItem(value: 'month_plan', child: Text('月计划')),
                      DropdownMenuItem(value: 'week_plan', child: Text('周计划')),
                      DropdownMenuItem(value: 'day_goal', child: Text('日目标')),
                      DropdownMenuItem(value: 'day_plan', child: Text('日计划')),
                      DropdownMenuItem(
                        value: 'current_phase',
                        child: Text('当前阶段'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _typeFilter = value ?? ''),
                  ),
                ),
                if (_typeFilter.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: '清除筛选',
                    onPressed: () => setState(() => _typeFilter = ''),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.fetchPlans(force: true),
              child: _buildBody(provider, plans, loading),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add_task),
        label: const Text('新建计划'),
      ),
    );
  }

  Widget _buildBody(AppProvider provider, List<PlanItem> plans, bool loading) {
    if (loading && plans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && plans.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Center(child: Text('加载失败：${provider.errorMessage}')),
        ],
      );
    }

    if (plans.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 64),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.event_note_outlined,
                  size: 64,
                  color: Colors.indigo.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                const Text(
                  '暂无计划',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  '点击右下角按钮制定你的第一个计划',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final item = plans[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(item.status),
              radius: 18,
              child: Icon(
                _statusIcon(item.status),
                color: Colors.white,
                size: 18,
              ),
            ),
            title: Text(item.title),
            subtitle: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(
                    _planTypeZh(item.planType),
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Chip(
                  label: Text(
                    _statusZh(item.status),
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: _statusColor(
                    item.status,
                  ).withValues(alpha: 0.15),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Chip(
                  label: Text(
                    'P${item.priority}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                if (item.targetDate.isNotEmpty)
                  Text(
                    '📅 ${item.targetDate}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await _showCreateDialog(context, plan: item);
                } else if (value == 'delete') {
                  await _deletePlan(context, item.id, item.title);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'done':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'in_progress':
        return Icons.play_arrow;
      case 'done':
        return Icons.check;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _deletePlan(
    BuildContext context,
    String id,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除计划'),
        content: Text('确认删除计划"$title"？'),
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
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<AppProvider>().deletePlan(id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除计划')));
    } catch (_) {
      if (!context.mounted) return;
      final message = context.read<AppProvider>().errorMessage ?? '删除失败';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showCreateDialog(BuildContext context, {PlanItem? plan}) async {
    final provider = context.read<AppProvider>();
    final isEdit = plan != null;
    final titleController = TextEditingController(text: plan?.title ?? '');
    final contentController = TextEditingController(text: plan?.content ?? '');
    final targetController = TextEditingController(
      text: plan?.targetDate ?? '',
    );
    final statusController = TextEditingController(
      text: plan?.status ?? 'pending',
    );
    final priorityController = TextEditingController(
      text: '${plan?.priority ?? 3}',
    );
    String selectedType = plan?.planType ?? 'day_plan';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(isEdit ? '编辑计划' : '创建计划'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: '计划类型'),
                      items: const [
                        DropdownMenuItem(
                          value: 'year_plan',
                          child: Text('年计划'),
                        ),
                        DropdownMenuItem(
                          value: 'month_goal',
                          child: Text('月目标'),
                        ),
                        DropdownMenuItem(
                          value: 'month_plan',
                          child: Text('月计划'),
                        ),
                        DropdownMenuItem(
                          value: 'week_plan',
                          child: Text('周计划'),
                        ),
                        DropdownMenuItem(value: 'day_goal', child: Text('日目标')),
                        DropdownMenuItem(value: 'day_plan', child: Text('日计划')),
                        DropdownMenuItem(
                          value: 'current_phase',
                          child: Text('当前阶段'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _input(titleController, '标题'),
                    _input(contentController, '内容', maxLines: 3),
                    _input(targetController, '目标日期(YYYY-MM-DD)'),
                    _input(statusController, '状态(pending/in_progress/done)'),
                    _input(priorityController, '优先级(1-5)'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(const SnackBar(content: Text('标题不能为空')));
                      return;
                    }
                    final input = {
                      'plan_type': selectedType,
                      'title': titleController.text.trim(),
                      'content': contentController.text.trim(),
                      'target_date': targetController.text.trim(),
                      'status': statusController.text.trim(),
                      'priority':
                          int.tryParse(priorityController.text.trim()) ?? 3,
                    };
                    try {
                      if (isEdit) {
                        await provider.updatePlan(plan.id, input);
                      } else {
                        await provider.createPlan(input);
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
                      }
                    }
                  },
                  child: Text(isEdit ? '保存' : '创建'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  String _planTypeZh(String planType) {
    switch (planType) {
      case 'year_plan':
        return '年计划';
      case 'month_goal':
        return '月目标';
      case 'month_plan':
        return '月计划';
      case 'week_plan':
        return '周计划';
      case 'day_goal':
        return '日目标';
      case 'day_plan':
        return '日计划';
      case 'current_phase':
        return '当前阶段';
      default:
        return planType;
    }
  }

  String _statusZh(String status) {
    switch (status) {
      case 'pending':
        return '待开始';
      case 'in_progress':
        return '进行中';
      case 'done':
        return '已完成';
      default:
        return status;
    }
  }
}
