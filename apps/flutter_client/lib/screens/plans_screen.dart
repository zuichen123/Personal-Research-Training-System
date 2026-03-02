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
          if (_typeFilter.isEmpty) {
            return true;
          }
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
            child: DropdownButtonFormField<String>(
              value: _typeFilter.isEmpty ? null : _typeFilter,
              decoration: const InputDecoration(
                labelText: '类型筛选',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'month_goal', child: Text('月目标')),
                DropdownMenuItem(value: 'month_plan', child: Text('月计划')),
                DropdownMenuItem(value: 'day_goal', child: Text('日目标')),
                DropdownMenuItem(value: 'day_plan', child: Text('日计划')),
                DropdownMenuItem(value: 'current_phase', child: Text('当前阶段')),
              ],
              onChanged: (value) => setState(() => _typeFilter = value ?? ''),
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
        children: const [
          SizedBox(height: 96),
          Center(child: Text('暂无计划')),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final item = plans[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(item.title),
            subtitle: Text(
              '类型:${_planTypeZh(item.planType)}  状态:${_statusZh(item.status)}\n目标日期:${item.targetDate.isEmpty ? "-" : item.targetDate}  优先级:${item.priority}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await _showCreateDialog(context, plan: item);
                } else if (value == 'delete') {
                  await context.read<AppProvider>().deletePlan(item.id);
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
                          value: 'month_goal',
                          child: Text('月目标'),
                        ),
                        DropdownMenuItem(
                          value: 'month_plan',
                          child: Text('月计划'),
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
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
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
      case 'month_goal':
        return '月目标';
      case 'month_plan':
        return '月计划';
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
