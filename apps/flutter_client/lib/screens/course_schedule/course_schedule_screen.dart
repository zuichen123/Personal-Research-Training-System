import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ai_agent_chat.dart';
import '../../models/plan.dart';
import '../../models/course_lesson.dart';
import '../../providers/ai_agent_provider.dart';
import '../../providers/app_provider.dart';
import '../plans_screen.dart';
import '../practice_session_screen.dart';
import 'course_lesson_session_screen.dart';

enum CourseScheduleView { year, month, day, lesson }

class CourseScheduleScreen extends StatefulWidget {
  const CourseScheduleScreen({super.key});

  @override
  State<CourseScheduleScreen> createState() => _CourseScheduleScreenState();
}

class _CourseScheduleScreenState extends State<CourseScheduleScreen> {
  CourseScheduleView _view = CourseScheduleView.day;
  DateTime _focusDate = DateUtils.dateOnly(DateTime.now());
  CourseLesson? _selectedLesson;
  bool _startingLesson = false;
  bool _savingMastery = false;
  double _masteryScore = 75;
  final TextEditingController _masteryNoteController = TextEditingController();
  final List<_MasteryRecord> _masteryRecords = [];
  final Map<String, _LessonSessionBinding> _lessonSessions =
      <String, _LessonSessionBinding>{};
  List<CourseLesson> _lessons = [];
  bool _loadingLessons = false;
  String? _lessonsError;

  @override
  void initState() {
    super.initState();
    _refreshSelectedLesson();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AppProvider>().fetchPlans();
      _fetchLessons();
    });
  }

  Future<void> _fetchLessons() async {
    if (!mounted) return;

    setState(() {
      _loadingLessons = true;
      _lessonsError = null;
    });

    try {
      final api = context.read<AppProvider>().apiService;
      final dateStr = _focusDate.toIso8601String().split('T')[0];
      final granularity = _view == CourseScheduleView.day ? 'day' : 'week';

      final lessons = await api.getCourseScheduleLessons(dateStr, granularity);

      if (mounted) {
        setState(() => _lessons = lessons);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _lessonsError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLessons = false);
      }
    }
  }

  @override
  void dispose() {
    _masteryNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('\u667a\u80fd\u8bfe\u7a0b\u8868'),
        actions: [
          IconButton(
            tooltip: '\u6253\u5f00\u8ba1\u5212',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PlansScreen()));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _buildNavigatorCard(context),
          const SizedBox(height: 12),
          _buildViewSwitcher(),
          const SizedBox(height: 12),
          _buildCurrentView(context, appProvider),
        ],
      ),
    );
  }

  Widget _buildNavigatorCard(BuildContext context) {
    final monthLessons = _lessonsInMonth(
      _focusDate.year,
      _focusDate.month,
    ).length;
    final dayLessons = _lessonsForDate(_focusDate).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _periodLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _moveFocus(-1),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _moveFocus(1),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _smallChip('\u672c\u6708\u8bfe\u7a0b: $monthLessons'),
                _smallChip('\u5f53\u65e5\u8bfe\u7a0b: $dayLessons'),
                _smallChip(
                  '\u638c\u63e1\u8bb0\u5f55: ${_masteryRecords.length}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSwitcher() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CourseScheduleView.values
              .map(
                (view) => ChoiceChip(
                  selected: _view == view,
                  label: Text(_viewLabel(view)),
                  onSelected: (_) {
                    setState(() => _view = view);
                    if (view != CourseScheduleView.lesson) {
                      _refreshSelectedLesson();
                    }
                  },
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildCurrentView(BuildContext context, AppProvider appProvider) {
    if (_loadingLessons) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_lessonsError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('加载失败: $_lessonsError', style: TextStyle(color: Colors.red)),
        ),
      );
    }

    switch (_view) {
      case CourseScheduleView.year:
        return _buildYearView(context);
      case CourseScheduleView.month:
        return _buildMonthView(context);
      case CourseScheduleView.day:
        return _buildDayView();
      case CourseScheduleView.lesson:
        return _buildLessonView(context, appProvider);
    }
  }

  Widget _buildYearView(BuildContext context) {
    final year = _focusDate.year;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 950
        ? 4
        : width >= 700
        ? 3
        : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final month = index + 1;
        final monthLessons = _lessonsInMonth(year, month);
        final subjectCount = <String, int>{};
        for (final lesson in monthLessons) {
          subjectCount[lesson.subject] =
              (subjectCount[lesson.subject] ?? 0) + 1;
        }
        final topSubjects = subjectCount.entries.toList(growable: false)
          ..sort((a, b) => b.value.compareTo(a.value));

        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _focusDate = DateTime(year, month, 1);
                _view = CourseScheduleView.month;
                _refreshSelectedLesson();
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$month',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('\u8bfe\u7a0b\u6570: ${monthLessons.length}'),
                  const SizedBox(height: 6),
                  if (topSubjects.isEmpty)
                    const Text('\u6682\u65e0\u8bfe\u7a0b')
                  else
                    ...topSubjects
                        .take(2)
                        .map(
                          (item) => Text(
                            '${item.key}: ${item.value}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  const Spacer(),
                  const Text('\u70b9\u51fb\u67e5\u770b\u6708\u89c6\u56fe'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthView(BuildContext context) {
    const weekdays = [
      '\u4e00',
      '\u4e8c',
      '\u4e09',
      '\u56db',
      '\u4e94',
      '\u516d',
      '\u65e5',
    ];
    final year = _focusDate.year;
    final month = _focusDate.month;
    final firstWeekday = DateTime(year, month, 1).weekday;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final leadingBlank = (firstWeekday + 6) % 7;
    final totalCells = leadingBlank + daysInMonth;
    final tailBlank = (7 - totalCells % 7) % 7;
    final count = totalCells + tailBlank;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: weekdays
                  .map(
                    (item) => Expanded(
                      child: Center(
                        child: Text(item, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: count,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 0.88,
              ),
              itemBuilder: (context, index) {
                if (index < leadingBlank ||
                    index >= leadingBlank + daysInMonth) {
                  return const SizedBox.shrink();
                }
                final day = index - leadingBlank + 1;
                final date = DateTime(year, month, day);
                final lessons = _lessonsForDate(date);

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _focusDate = date;
                      _view = CourseScheduleView.day;
                      _refreshSelectedLesson();
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$day',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        if (lessons.isEmpty)
                          const Text(
                            '-',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          )
                        else ...[
                          Text(
                            lessons.first.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          if (lessons.length > 1)
                            Text(
                              '+${lessons.length - 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayView() {
    final lessons = _lessonsForDate(_focusDate);
    if (lessons.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_dateLabel(_focusDate)} \u65e0\u8bfe\u7a0b'),
              const SizedBox(height: 6),
              const Text(
                '\u53ef\u5207\u6362\u5230\u6708\u89c6\u56fe\u9009\u62e9\u5176\u4ed6\u65e5\u671f\u3002',
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: lessons
              .map((lesson) {
                final selected = _selectedLesson?.id == lesson.id;
                return Card(
                  color: selected
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : null,
                  child: ListTile(
                    title: Text(
                      '${lesson.subject}  \u7b2c${lesson.period}\u8282',
                    ),
                    subtitle: Text(
                      '${lesson.topic}  |  ${lesson.startTime}-${lesson.endTime}  |  ${lesson.classroom}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      setState(() {
                        _selectedLesson = lesson;
                        _view = CourseScheduleView.lesson;
                      });
                    },
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildLessonView(BuildContext context, AppProvider appProvider) {
    final lesson = _selectedLesson ?? _lessonsForDate(_focusDate).firstOrNull;
    if (lesson == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('\u672a\u9009\u62e9\u8bfe\u7a0b'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => setState(() => _view = CourseScheduleView.day),
                icon: const Icon(Icons.view_day),
                label: const Text('\u8fd4\u56de\u65e5\u89c6\u56fe'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _currentLessonCard(context, lesson),
        const SizedBox(height: 12),
        _knowledgeSummaryCard(lesson),
        const SizedBox(height: 12),
        _afterClassPracticeCard(context, lesson),
        const SizedBox(height: 12),
        _masteryCard(context, lesson),
        const SizedBox(height: 12),
        _linkedPlanCard(context, appProvider, lesson),
        if (_masteryRecords.isNotEmpty) ...[
          const SizedBox(height: 12),
          _masteryHistoryCard(),
        ],
      ],
    );
  }

  Widget _currentLessonCard(BuildContext context, CourseLesson lesson) {
    final hasSession = _lessonSessions.containsKey(lesson.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '\u5f53\u524d\u8bfe\u7a0b',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _smallChip(_dateLabel(DateTime.parse(lesson.date))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${lesson.subject}  \u7b2c${lesson.period}\u8282',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(lesson.topic),
            const SizedBox(height: 4),
            Text(
              '${lesson.startTime}-${lesson.endTime}  |  ${lesson.classroom}',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startingLesson ? null : () => _startLesson(lesson),
                icon: _startingLesson
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  _startingLesson
                      ? '\u542f\u52a8\u4e2d...'
                      : hasSession
                      ? '\u8fdb\u5165\u4e0a\u8bfe\u4f1a\u8bdd'
                      : '\u521b\u5efa\u4e0a\u8bfe\u4f1a\u8bdd',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _knowledgeSummaryCard(CourseLesson lesson) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '\u77e5\u8bc6\u70b9\u603b\u7ed3',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('- \u4e3b\u9898\uff1a${lesson.topic}'),
            Text(
              '- \u6838\u5fc3\u6982\u5ff5\uff1a${lesson.subject}\u57fa\u7840\u77e5\u8bc6',
            ),
            const Text(
              '- \u667a\u80fd\u52a9\u6559\u751f\u6210\u603b\u7ed3\uff08\u5f85\u8865\u5145\uff09',
            ),
          ],
        ),
      ),
    );
  }

  Widget _afterClassPracticeCard(BuildContext context, CourseLesson lesson) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('课后练习', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('当前课程会优先匹配 ${lesson.subject} / ${lesson.topic} 相关题目，直接进入作答。'),
            const SizedBox(height: 4),
            const Text('若当前题库尚未存在匹配题目，会明确提示“暂无已绑定课后作业”，避免继续随机抽题。'),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _openLessonHomework(context, lesson),
              icon: const Icon(Icons.play_arrow),
              label: const Text('进入课后作业'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openPracticePrompt(lesson),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('查看出题提示词'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLessonHomework(
    BuildContext context,
    CourseLesson lesson,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticeSessionScreen(
          sessionTitle: '${lesson.subject} · 课后作业',
          lessonSubject: lesson.subject,
          lessonTopic: lesson.topic,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    await context.read<AppProvider>().fetchAttempts(force: true);
  }

  Widget _masteryCard(BuildContext context, CourseLesson lesson) {
    final scoreText = _masteryScore.round().toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '\u638c\u63e1\u5ea6\u8bc4\u4f30',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('\u8bc4\u5206\uff1a$scoreText / 100'),
            Slider(
              value: _masteryScore,
              min: 0,
              max: 100,
              divisions: 20,
              label: scoreText,
              onChanged: (value) => setState(() => _masteryScore = value),
            ),
            TextField(
              controller: _masteryNoteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '\u8bfe\u5802\u5907\u6ce8\uff08\u53ef\u9009\uff09',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _savingMastery ? null : () => _saveMastery(lesson),
                icon: _savingMastery
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _savingMastery
                      ? '\u4fdd\u5b58\u4e2d...'
                      : '\u4fdd\u5b58\u5230\u590d\u4e60\u8ba1\u5212',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _masteryHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '\u638c\u63e1\u5ea6\u5386\u53f2',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._masteryRecords
                .take(5)
                .map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${_dateLabel(record.createdAt)}  |  ${record.lessonLabel}  |  '
                      '\u5f97\u5206 ${record.score}  |  \u8ba1\u5212 ${record.planTitle}',
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _linkedPlanCard(
    BuildContext context,
    AppProvider appProvider,
    CourseLesson lesson,
  ) {
    final plans = _relatedPlansForLesson(appProvider.plans, lesson);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '关联计划',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PlansScreen()),
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('打开计划管理'),
                ),
              ],
            ),
            if (plans.isEmpty) ...[
              const SizedBox(height: 6),
              const Text('当前课程暂无关联计划，可先保存掌握度自动生成复习计划。'),
            ] else ...[
              const SizedBox(height: 6),
              ...plans.take(4).map((item) {
                final completed = item.status == 'completed';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '状态: ${_planStatusLabel(item.status)}  |  截止: ${item.targetDate.isEmpty ? '-' : item.targetDate}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: completed
                            ? null
                            : () => _markPlanCompleted(
                                context,
                                appProvider,
                                item.id,
                              ),
                        child: Text(completed ? '已完成' : '标记完成'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  List<PlanItem> _relatedPlansForLesson(
    List<PlanItem> plans,
    CourseLesson lesson,
  ) {
    final subject = lesson.subject.toLowerCase();
    final topic = lesson.topic.toLowerCase();
    final related = plans
        .where((item) {
          final title = item.title.toLowerCase();
          final content = item.content.toLowerCase();
          if (item.source == 'ai_agent' &&
              item.targetDate == _dateLabel(DateTime.parse(lesson.date))) {
            return true;
          }
          return title.contains(subject) ||
              title.contains(topic) ||
              content.contains(subject) ||
              content.contains(topic);
        })
        .toList(growable: false);
    related.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return related;
  }

  String _planStatusLabel(String status) {
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

  Future<void> _markPlanCompleted(
    BuildContext context,
    AppProvider appProvider,
    String id,
  ) async {
    try {
      await appProvider.updatePlan(id, {'status': 'completed'});
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已标记计划完成')));
    } catch (e) {
      debugPrint('Error marking plan completed: $e');
      if (!context.mounted) {
        return;
      }
      final message = appProvider.errorMessage ?? '更新计划状态失败';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _startLesson(CourseLesson lesson) async {
    if (_startingLesson) {
      return;
    }
    setState(() => _startingLesson = true);

    final agentProvider = context.read<AIAgentProvider>();
    final appProvider = context.read<AppProvider>();
    try {
      if (!appProvider.isSectionLoaded(DataSection.profile)) {
        try {
          await appProvider.fetchUserProfile();
        } catch (e) {
          debugPrint('Failed to fetch user profile: $e');
          // Continue without profile; session context will mark profile as not provided.
        }
      }
      final lessonTheme = _buildLessonSessionTheme(
        lesson: lesson,
        appProvider: appProvider,
      );

      final existing = _lessonSessions[lesson.id];
      if (existing != null && existing.sessionId.trim().isNotEmpty) {
        await agentProvider.selectAgent(existing.agentId);
        await agentProvider.updateSessionScheduleBinding(
          sessionId: existing.sessionId,
          mode: 'manual',
          theme: lessonTheme,
          autoEnabled: true,
          manualPlanIds: const <String>[],
        );
        await _openLessonSession(lesson, existing);
        return;
      }

      if (agentProvider.agents.isEmpty) {
        await agentProvider.refreshAgents();
      }
      final enabledAgents = agentProvider.agents
          .where((agent) => agent.enabled)
          .toList(growable: false);
      if (enabledAgents.isEmpty) {
        throw StateError(
          '\u672a\u627e\u5230\u53ef\u7528\u7684\u667a\u80fd\u52a9\u6559\u3002',
        );
      }

      final selectedAgent = _selectLessonAgent(enabledAgents);
      final sessionTitle =
          '课程会话 ${lesson.subject} ${_dateLabel(DateTime.parse(lesson.date))} 第${lesson.period}节';
      await agentProvider.selectAgent(selectedAgent.id);
      await agentProvider.createSession(title: sessionTitle);
      final sessionId = agentProvider.selectedSessionIdOf(selectedAgent.id);
      if (sessionId.isEmpty) {
        throw StateError(
          '\u4e0a\u8bfe\u4f1a\u8bdd\u521b\u5efa\u5931\u8d25\u3002',
        );
      }
      await agentProvider.updateSessionScheduleBinding(
        sessionId: sessionId,
        mode: 'manual',
        theme: lessonTheme,
        autoEnabled: true,
        manualPlanIds: const <String>[],
      );
      final binding = _LessonSessionBinding(
        agentId: selectedAgent.id,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        createdAt: DateTime.now(),
      );
      setState(() {
        _lessonSessions[lesson.id] = binding;
      });

      await _openLessonSession(lesson, binding);
    } catch (e) {
      debugPrint('Error starting lesson: $e');
      if (!mounted) {
        return;
      }
      final message =
          agentProvider.errorMessage ??
          '启动课程会话失败。';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _startingLesson = false);
      }
    }
  }

  Future<void> _openLessonSession(
    CourseLesson lesson,
    _LessonSessionBinding binding,
  ) async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseLessonSessionScreen(
          lessonTitle: '${lesson.subject} 第${lesson.period}节',
          lessonTopic: lesson.topic,
          agentId: binding.agentId,
          sessionId: binding.sessionId,
          sessionTitle: binding.sessionTitle,
        ),
      ),
    );
  }

  Future<void> _saveMastery(CourseLesson lesson) async {
    if (_savingMastery) {
      return;
    }
    setState(() => _savingMastery = true);

    final appProvider = context.read<AppProvider>();
    final score = _masteryScore.round();
    final targetDate = _nextReviewDate(score, DateTime.parse(lesson.date));
    final note = _masteryNoteController.text.trim();
    final planTitle =
        '\u590d\u4e60 ${lesson.subject} (${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')})';

    try {
      await appProvider.createPlan({
        'plan_type': 'day_plan',
        'title': planTitle,
        'content': _buildMasteryPlanContent(
          lesson: lesson,
          score: score,
          note: note,
        ),
        'target_date': _toDateString(targetDate),
        'status': 'pending',
        'priority': _priorityFromScore(score),
        'source': 'ai_agent',
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _masteryRecords.insert(
          0,
          _MasteryRecord(
            lessonLabel: '${lesson.subject} \u7b2c${lesson.period}\u8282',
            score: score,
            createdAt: DateTime.now(),
            planTitle: planTitle,
          ),
        );
        _masteryNoteController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u5df2\u4fdd\u5b58\u638c\u63e1\u5ea6\u5e76\u521b\u5efa\u590d\u4e60\u8ba1\u5212\uff1a$planTitle',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error saving mastery: $e');
      if (!mounted) {
        return;
      }
      final message =
          appProvider.errorMessage ??
          '保存掌握度计划失败。';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _savingMastery = false);
      }
    }
  }

  void _openPracticePrompt(CourseLesson lesson) {
    final hasSession = _lessonSessions.containsKey(lesson.id);
    final actionLabel = hasSession
        ? '\u8fdb\u5165\u4f1a\u8bdd'
        : '\u5f00\u59cb\u4e0a\u8bfe';
    final message =
        '\u5df2\u751f\u6210\u7ec3\u4e60\u63d0\u793a\u8bcd\uff1a${lesson.subject} - ${lesson.topic}\u3002'
        '\u53ef\u76f4\u63a5\u70b9\u51fb\u201c$actionLabel\u201d\u53d1\u9001\u4e0a\u4e0b\u6587\u7ed9\u667a\u80fd\u52a9\u6559\u3002';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: actionLabel,
          onPressed: () => _startLesson(lesson),
        ),
      ),
    );
  }

  AIAgentSummary _selectLessonAgent(List<AIAgentSummary> agents) {
    final preferred = agents.where((agent) {
      final name = agent.name.toLowerCase();
      return name.contains('tutor') ||
          name.contains('lesson') ||
          name.contains('teacher') ||
          name.contains('\u52a9\u6559') ||
          name.contains('\u8001\u5e08') ||
          name.contains('\u8bb2\u5e08');
    });
    if (preferred.isNotEmpty) {
      return preferred.first;
    }
    final withChatIntent = agents.where(
      (agent) => agent.intentCapabilities
          .map((item) => item.trim().toLowerCase())
          .contains('chat'),
    );
    if (withChatIntent.isNotEmpty) {
      return withChatIntent.first;
    }
    return agents.first;
  }

  String _buildLessonSessionTheme({
    required CourseLesson lesson,
    required AppProvider appProvider,
  }) {
    final timeline = _buildLessonTimeline(lesson);
    final currentIndex = timeline.indexWhere((item) => item.id == lesson.id);
    CourseLesson? previous;
    CourseLesson? next;
    if (currentIndex > 0) {
      previous = timeline[currentIndex - 1];
    }
    if (currentIndex >= 0 && currentIndex < timeline.length - 1) {
      next = timeline[currentIndex + 1];
    }

    final lines = <String>[
      'course_session_context=true',
      'current_lesson=${_lessonBrief(lesson)}',
      'classroom=${lesson.classroom}',
      'time=${lesson.startTime}-${lesson.endTime}',
      'previous_lesson=${previous == null ? "-" : _lessonBrief(previous)}',
      'next_lesson=${next == null ? "-" : _lessonBrief(next)}',
    ];

    final profile = appProvider.userProfile;
    if (profile == null) {
      lines.add('student_profile=not_provided');
    } else {
      lines.add('student_id=${profile.userId}');
      lines.add(
        'student_nickname=${profile.nickname.trim().isEmpty ? "-" : profile.nickname.trim()}',
      );
      lines.add(
        'academic_status=${profile.academicStatus.trim().isEmpty ? "-" : profile.academicStatus.trim()}',
      );
      lines.add('daily_study_minutes=${profile.dailyStudyMinutes}');
      lines.add(
        'goals=${profile.goals.isEmpty ? "-" : profile.goals.join(", ")}',
      );
      lines.add(
        'weak_subjects=${profile.weakSubjects.isEmpty ? "-" : profile.weakSubjects.join(", ")}',
      );
      lines.add(
        'target_destination=${profile.targetDestination.trim().isEmpty ? "-" : profile.targetDestination.trim()}',
      );
      lines.add(
        'notes=${profile.notes.trim().isEmpty ? "-" : profile.notes.trim()}',
      );
    }
    return lines.join('; ');
  }

  List<CourseLesson> _buildLessonTimeline(CourseLesson anchor) {
    final lessons = <CourseLesson>[];
    final anchorDate = DateTime.parse(anchor.date);
    for (var offset = -7; offset <= 7; offset++) {
      final date = anchorDate.add(Duration(days: offset));
      lessons.addAll(_lessonsForDate(date));
    }
    lessons.sort((left, right) {
      final dateCompare = left.date.compareTo(right.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return left.period.compareTo(right.period);
    });
    return lessons;
  }

  String _lessonBrief(CourseLesson lesson) {
    return '${_dateLabel(DateTime.parse(lesson.date))} 第${lesson.period}节 ${lesson.subject}/${lesson.topic}';
  }

  String _buildMasteryPlanContent({
    required CourseLesson lesson,
    required int score,
    required String note,
  }) {
    final recommendation = _recommendationForScore(score);
    return [
      '\u5b66\u79d1\uff1a${lesson.subject}',
      '\u4e3b\u9898\uff1a${lesson.topic}',
      '日期：${_dateLabel(DateTime.parse(lesson.date))}',
      '\u638c\u63e1\u5ea6\uff1a$score/100',
      '\u5efa\u8bae\uff1a$recommendation',
      '\u8bfe\u5802\u5907\u6ce8\uff1a${note.isEmpty ? '-' : note}',
    ].join('\n');
  }

  int _priorityFromScore(int score) {
    if (score < 60) {
      return 5;
    }
    if (score < 80) {
      return 4;
    }
    return 3;
  }

  DateTime _nextReviewDate(int score, DateTime baseDate) {
    if (score < 60) {
      return DateUtils.dateOnly(baseDate.add(const Duration(days: 1)));
    }
    if (score < 80) {
      return DateUtils.dateOnly(baseDate.add(const Duration(days: 2)));
    }
    return DateUtils.dateOnly(baseDate.add(const Duration(days: 4)));
  }

  String _recommendationForScore(int score) {
    if (score < 60) {
      return '\u5efa\u8bae\u7acb\u5373\u91cd\u5b66\uff0c\u5e76\u52a0\u7ec33\u9898\u3002';
    }
    if (score < 80) {
      return '\u5efa\u8bae48\u5c0f\u65f6\u5185\u590d\u4e60\uff0c\u5e76\u5b8c\u6210\u4e00\u6b21\u5c0f\u6d4b\u3002';
    }
    return '\u5efa\u8bae\u57283-4\u5929\u540e\u5b89\u6392\u95f4\u9694\u590d\u4e60\u3002';
  }

  List<CourseLesson> _lessonsInMonth(int year, int month) {
    final days = DateUtils.getDaysInMonth(year, month);
    final out = <CourseLesson>[];
    for (var day = 1; day <= days; day++) {
      final date = DateTime(year, month, day);
      out.addAll(_lessonsForDate(date));
    }
    return out;
  }

  List<CourseLesson> _lessonsForDate(DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0];
    return _lessons.where((lesson) => lesson.date == dateStr).toList()
      ..sort((a, b) => a.period.compareTo(b.period));
  }

  void _moveFocus(int offset) {
    setState(() {
      switch (_view) {
        case CourseScheduleView.year:
          final year = _focusDate.year + offset;
          final maxDay = DateUtils.getDaysInMonth(year, _focusDate.month);
          _focusDate = DateTime(
            year,
            _focusDate.month,
            math.min(_focusDate.day, maxDay),
          );
          break;
        case CourseScheduleView.month:
          final moved = DateTime(_focusDate.year, _focusDate.month + offset, 1);
          final maxDay = DateUtils.getDaysInMonth(moved.year, moved.month);
          _focusDate = DateTime(
            moved.year,
            moved.month,
            math.min(_focusDate.day, maxDay),
          );
          break;
        case CourseScheduleView.day:
        case CourseScheduleView.lesson:
          _focusDate = _focusDate.add(Duration(days: offset));
          break;
      }
      _refreshSelectedLesson();
    });
    _fetchLessons();
  }

  void _refreshSelectedLesson() {
    final lessons = _lessonsForDate(_focusDate);
    if (lessons.isEmpty) {
      _selectedLesson = null;
      return;
    }
    if (_selectedLesson == null) {
      _selectedLesson = lessons.first;
      return;
    }
    final matched = lessons.where((item) => item.id == _selectedLesson!.id);
    _selectedLesson = matched.isEmpty ? lessons.first : matched.first;
  }

  Widget _smallChip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String get _periodLabel {
    switch (_view) {
      case CourseScheduleView.year:
        return '${_focusDate.year}';
      case CourseScheduleView.month:
        return '${_focusDate.year}-${_focusDate.month.toString().padLeft(2, '0')}';
      case CourseScheduleView.day:
      case CourseScheduleView.lesson:
        return _dateLabel(_focusDate);
    }
  }

  String _viewLabel(CourseScheduleView view) {
    switch (view) {
      case CourseScheduleView.year:
        return '\u5e74\u89c6\u56fe';
      case CourseScheduleView.month:
        return '\u6708\u89c6\u56fe';
      case CourseScheduleView.day:
        return '\u65e5\u89c6\u56fe';
      case CourseScheduleView.lesson:
        return '\u8bfe\u89c6\u56fe';
    }
  }

  String _dateLabel(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _toDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  String _toDateString(DateTime date) {
    return _dateLabel(DateUtils.dateOnly(date));
  }
}

class _MasteryRecord {
  const _MasteryRecord({
    required this.lessonLabel,
    required this.score,
    required this.createdAt,
    required this.planTitle,
  });

  final String lessonLabel;
  final int score;
  final DateTime createdAt;
  final String planTitle;
}

class _LessonSessionBinding {
  const _LessonSessionBinding({
    required this.agentId,
    required this.sessionId,
    required this.sessionTitle,
    required this.createdAt,
  });

  final String agentId;
  final String sessionId;
  final String sessionTitle;
  final DateTime createdAt;
}

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
