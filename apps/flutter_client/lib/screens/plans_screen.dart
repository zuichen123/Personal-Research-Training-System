import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plan.dart';
import '../providers/app_provider.dart';

enum _PlanGranularity { year, month, day }

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  _PlanGranularity _granularity = _PlanGranularity.year;
  DateTime _focusDate = DateUtils.dateOnly(DateTime.now());
  String _sourceFilter = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final loading = provider.isSectionLoading(DataSection.plans);
    final plans = provider.plans
        .where((item) => _sourceFilter.isEmpty || item.source == _sourceFilter)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchPlans(force: true),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              _sourceFilter.isEmpty
                  ? Icons.filter_alt_outlined
                  : Icons.filter_alt,
            ),
            onSelected: (value) {
              setState(() => _sourceFilter = value == 'all' ? '' : value);
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'all',
                checked: _sourceFilter.isEmpty,
                child: const Text('全部来源'),
              ),
              CheckedPopupMenuItem(
                value: 'manual',
                checked: _sourceFilter == 'manual',
                child: const Text('manual'),
              ),
              CheckedPopupMenuItem(
                value: 'ai_learning',
                checked: _sourceFilter == 'ai_learning',
                child: const Text('ai_learning'),
              ),
              CheckedPopupMenuItem(
                value: 'ai_agent',
                checked: _sourceFilter == 'ai_agent',
                child: const Text('ai_agent'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchPlans(force: true),
        child: _buildBody(provider, plans, loading),
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
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Center(child: Text('加载失败：${provider.errorMessage}')),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        _navigatorCard(),
        const SizedBox(height: 12),
        _overviewCard(plans),
        const SizedBox(height: 12),
        if (_granularity == _PlanGranularity.year) _yearGrid(plans),
        if (_granularity == _PlanGranularity.month) _monthGrid(plans),
        if (_granularity == _PlanGranularity.day) _dayView(plans),
        const SizedBox(height: 12),
        _undatedPlansCard(plans),
      ],
    );
  }

  Widget _navigatorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '当前颗粒度：${_granularityZh(_granularity)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _moveFocus(-1),
                ),
                Text(_periodLabel),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _moveFocus(1),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InputChip(
                  label: Text('${_focusDate.year}年'),
                  selected: _granularity == _PlanGranularity.year,
                  onPressed: () {
                    setState(() => _granularity = _PlanGranularity.year);
                  },
                ),
                if (_granularity != _PlanGranularity.year)
                  InputChip(
                    label: Text('${_focusDate.month}月'),
                    selected: _granularity == _PlanGranularity.month,
                    onPressed: () {
                      setState(() => _granularity = _PlanGranularity.month);
                    },
                  ),
                if (_granularity == _PlanGranularity.day)
                  InputChip(
                    label: Text('${_focusDate.day}日'),
                    selected: true,
                    onPressed: () {},
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewCard(List<PlanItem> plans) {
    final scoped = _scopePlans(plans);
    final done = scoped.where((e) => e.status == 'completed').length;
    final total = scoped.length;
    final rate = total == 0 ? 0 : (done * 100 ~/ total);

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.45,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_overviewTitle(), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _smallChip('总计 $total'),
                _smallChip('完成 $done'),
                _smallChip('完成率 $rate%'),
              ],
            ),
            const SizedBox(height: 8),
            if (scoped.isEmpty)
              const Text('当前颗粒度暂无计划')
            else
              ..._sorted(scoped).take(3).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${item.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _yearGrid(List<PlanItem> plans) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 980 ? 3 : 2;
    final year = _focusDate.year;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('点击月份格进入月视图', style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: crossAxisCount == 2 ? 1.08 : 1.2,
          ),
          itemBuilder: (context, index) {
            final month = index + 1;
            final monthPlans = _plansInMonth(plans, year, month);
            final monthScale = monthPlans.where(_isMonthScale).toList(growable: false);
            final preview = _sorted(monthScale).take(3).toList(growable: false);

            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _focusDate = DateTime(year, month, 1);
                  _granularity = _PlanGranularity.month;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          '$month月',
                          style: TextStyle(
                            fontSize: 84,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            color: cs.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$month月', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        if (preview.isEmpty)
                          Text('暂无月尺度计划', style: TextStyle(color: cs.onSurfaceVariant))
                        else
                          ...preview.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          '月尺度 ${monthScale.length} 项',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _monthGrid(List<PlanItem> plans) {
    final year = _focusDate.year;
    final month = _focusDate.month;
    final firstWeekday = DateTime(year, month, 1).weekday;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final leadingBlank = (firstWeekday + 6) % 7;
    final totalCells = leadingBlank + daysInMonth;
    final tailBlank = (7 - totalCells % 7) % 7;
    final count = totalCells + tailBlank;
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final ratio = width >= 900 ? 0.95 : width >= 700 ? 0.75 : 0.56;

    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('点击日期格进入日视图', style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(
          children: weekdays
              .map((name) => Expanded(child: Center(child: Text(name))))
              .toList(growable: false),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) {
            if (index < leadingBlank || index >= leadingBlank + daysInMonth) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
                ),
              );
            }

            final day = index - leadingBlank + 1;
            final date = DateTime(year, month, day);
            final dayPlans = _plansInDay(plans, date);
            final dayScale = dayPlans.where(_isDayScale).toList(growable: false);
            final preview = _sorted(dayScale.isEmpty ? dayPlans : dayScale)
                .take(2)
                .toList(growable: false);
            final isToday = DateUtils.isSameDay(date, DateTime.now());

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _focusDate = date;
                  _granularity = _PlanGranularity.day;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: dayPlans.isNotEmpty
                      ? cs.primaryContainer.withValues(alpha: 0.2)
                      : cs.surface,
                  border: Border.all(
                    color: isToday ? cs.primary : cs.outlineVariant.withValues(alpha: 0.4),
                    width: isToday ? 1.4 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: cs.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$day日', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                        const SizedBox(height: 4),
                        if (preview.isEmpty)
                          Text('暂无计划', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))
                        else
                          ...preview.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Text('共${dayPlans.length}', style: const TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _dayView(List<PlanItem> plans) {
    final dayPlans = _sorted(_plansInDay(plans, _focusDate));
    if (dayPlans.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$_periodLabel 当天暂无计划，可新建后设置目标日期。'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dayPlans.map(_planCard).toList(growable: false),
    );
  }

  Widget _planCard(PlanItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.title),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _smallChip(_planTypeZh(item.planType)),
            _smallChip(_statusZh(item.status)),
            _smallChip('P${item.priority}'),
            if (item.targetDate.isNotEmpty) _smallChip(item.targetDate),
          ],
        ),
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
  }

  Widget _undatedPlansCard(List<PlanItem> plans) {
    final undated = plans.where((item) => _planDate(item) == null).toList(growable: false);
    if (undated.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: ExpansionTile(
        title: Text('未设置日期计划 (${undated.length})'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: _sorted(undated).take(6).map(_planCard).toList(growable: false),
      ),
    );
  }

  Widget _smallChip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _moveFocus(int offset) {
    setState(() {
      switch (_granularity) {
        case _PlanGranularity.year:
          final year = _focusDate.year + offset;
          final maxDay = DateUtils.getDaysInMonth(year, _focusDate.month);
          _focusDate = DateTime(year, _focusDate.month, math.min(_focusDate.day, maxDay));
          break;
        case _PlanGranularity.month:
          final moved = DateTime(_focusDate.year, _focusDate.month + offset, 1);
          final maxDay = DateUtils.getDaysInMonth(moved.year, moved.month);
          _focusDate = DateTime(moved.year, moved.month, math.min(_focusDate.day, maxDay));
          break;
        case _PlanGranularity.day:
          _focusDate = _focusDate.add(Duration(days: offset));
          break;
      }
    });
  }

  List<PlanItem> _scopePlans(List<PlanItem> plans) {
    switch (_granularity) {
      case _PlanGranularity.year:
        return _plansInYear(plans, _focusDate.year);
      case _PlanGranularity.month:
        return _plansInMonth(plans, _focusDate.year, _focusDate.month);
      case _PlanGranularity.day:
        return _plansInDay(plans, _focusDate);
    }
  }

  List<PlanItem> _plansInYear(List<PlanItem> plans, int year) {
    return plans
        .where((item) => _planDate(item)?.year == year)
        .toList(growable: false);
  }

  List<PlanItem> _plansInMonth(List<PlanItem> plans, int year, int month) {
    return plans
        .where((item) {
          final date = _planDate(item);
          return date != null && date.year == year && date.month == month;
        })
        .toList(growable: false);
  }

  List<PlanItem> _plansInDay(List<PlanItem> plans, DateTime day) {
    return plans
        .where((item) {
          final date = _planDate(item);
          return date != null && DateUtils.isSameDay(date, day);
        })
        .toList(growable: false);
  }

  DateTime? _planDate(PlanItem item) {
    final raw = item.targetDate.trim();
    if (raw.isEmpty) {
      return null;
    }
    final normalized = raw.replaceAll('/', '-').replaceAll('.', '-');
    final direct = DateTime.tryParse(normalized);
    if (direct != null) {
      return DateUtils.dateOnly(direct);
    }
    final ym = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(normalized);
    if (ym != null) {
      final year = int.tryParse(ym.group(1)!);
      final month = int.tryParse(ym.group(2)!);
      if (year != null && month != null && month >= 1 && month <= 12) {
        return DateTime(year, month, 1);
      }
    }
    final y = RegExp(r'^(\d{4})$').firstMatch(normalized);
    if (y != null) {
      final year = int.tryParse(y.group(1)!);
      if (year != null) {
        return DateTime(year, 1, 1);
      }
    }
    return null;
  }

  List<PlanItem> _sorted(Iterable<PlanItem> plans) {
    final list = plans.toList(growable: true);
    list.sort((a, b) {
      final statusRank = _statusRank(a.status).compareTo(_statusRank(b.status));
      if (statusRank != 0) {
        return statusRank;
      }
      final priorityRank = b.priority.compareTo(a.priority);
      if (priorityRank != 0) {
        return priorityRank;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  int _statusRank(String status) {
    switch (status) {
      case 'in_progress':
        return 0;
      case 'pending':
        return 1;
      case 'completed':
        return 2;
      case 'archived':
        return 3;
      default:
        return 4;
    }
  }

  bool _isMonthScale(PlanItem item) {
    return item.planType == 'month_goal' || item.planType == 'month_plan';
  }

  bool _isDayScale(PlanItem item) {
    return item.planType == 'day_goal' || item.planType == 'day_plan' || item.planType == 'week_plan';
  }

  String _granularityZh(_PlanGranularity g) {
    switch (g) {
      case _PlanGranularity.year:
        return '年';
      case _PlanGranularity.month:
        return '月';
      case _PlanGranularity.day:
        return '日';
    }
  }

  String get _periodLabel {
    switch (_granularity) {
      case _PlanGranularity.year:
        return '${_focusDate.year}年';
      case _PlanGranularity.month:
        return '${_focusDate.year}年 ${_focusDate.month}月';
      case _PlanGranularity.day:
        return '${_focusDate.year}-${_focusDate.month.toString().padLeft(2, '0')}-${_focusDate.day.toString().padLeft(2, '0')}';
    }
  }

  String _overviewTitle() {
    switch (_granularity) {
      case _PlanGranularity.year:
        return '${_focusDate.year}年计划总览';
      case _PlanGranularity.month:
        return '${_focusDate.year}年${_focusDate.month}月计划总览';
      case _PlanGranularity.day:
        return '$_periodLabel 计划总览';
    }
  }

  Future<void> _deletePlan(BuildContext context, String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除计划'),
        content: Text('确认删除计划 "$title" 吗？'),
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
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await context.read<AppProvider>().deletePlan(id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除计划')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      final message = context.read<AppProvider>().errorMessage ?? '删除失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showCreateDialog(BuildContext context, {PlanItem? plan}) async {
    final provider = context.read<AppProvider>();
    final isEdit = plan != null;
    final titleController = TextEditingController(text: plan?.title ?? '');
    final contentController = TextEditingController(text: plan?.content ?? '');
    final targetController = TextEditingController(text: plan?.targetDate ?? '');
    final statusController = TextEditingController(text: plan?.status ?? 'pending');
    final priorityController = TextEditingController(text: '${plan?.priority ?? 3}');
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
                      decoration: const InputDecoration(
                        labelText: '计划类型',
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
                        DropdownMenuItem(value: 'current_phase', child: Text('当前阶段')),
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
                    _input(statusController, '状态(pending/in_progress/completed/archived)'),
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
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('标题不能为空')));
                      return;
                    }
                    final input = {
                      'plan_type': selectedType,
                      'title': titleController.text.trim(),
                      'content': contentController.text.trim(),
                      'target_date': targetController.text.trim(),
                      'status': statusController.text.trim(),
                      'priority': int.tryParse(priorityController.text.trim()) ?? 3,
                      'source': isEdit ? plan.source : 'manual',
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
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('操作失败：$e')));
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

  Widget _input(TextEditingController controller, String label, {int maxLines = 1}) {
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
      case 'completed':
        return '已完成';
      case 'archived':
        return '已归档';
      default:
        return status;
    }
  }
}
