import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ai_agent_chat.dart';
import '../../providers/ai_agent_provider.dart';
import '../../providers/app_provider.dart';
import '../agent_chat_hub_screen.dart';
import '../plans_screen.dart';

enum CourseScheduleView { year, month, day, lesson }

class CourseScheduleScreen extends StatefulWidget {
  const CourseScheduleScreen({super.key});

  @override
  State<CourseScheduleScreen> createState() => _CourseScheduleScreenState();
}

class _CourseScheduleScreenState extends State<CourseScheduleScreen> {
  CourseScheduleView _view = CourseScheduleView.year;
  DateTime _focusDate = DateUtils.dateOnly(DateTime.now());
  _CourseLesson? _selectedLesson;
  bool _startingLesson = false;
  bool _savingMastery = false;
  double _masteryScore = 75;
  final TextEditingController _masteryNoteController = TextEditingController();
  final List<_MasteryRecord> _masteryRecords = [];

  static const List<_CourseTemplateLesson> _weeklyTemplates = [
    _CourseTemplateLesson(
      id: 'mon_math_1',
      weekday: DateTime.monday,
      period: 1,
      subject: 'Math',
      topic: 'Quadratic Function',
      classroom: 'A-301',
      startTime: '08:00',
      endTime: '08:45',
    ),
    _CourseTemplateLesson(
      id: 'mon_eng_2',
      weekday: DateTime.monday,
      period: 2,
      subject: 'English',
      topic: 'Reading Comprehension',
      classroom: 'B-204',
      startTime: '09:00',
      endTime: '09:45',
    ),
    _CourseTemplateLesson(
      id: 'tue_phy_3',
      weekday: DateTime.tuesday,
      period: 3,
      subject: 'Physics',
      topic: 'Newton Laws',
      classroom: 'Lab-2',
      startTime: '10:00',
      endTime: '10:45',
    ),
    _CourseTemplateLesson(
      id: 'wed_chem_4',
      weekday: DateTime.wednesday,
      period: 4,
      subject: 'Chemistry',
      topic: 'Mole Concept',
      classroom: 'Lab-1',
      startTime: '11:00',
      endTime: '11:45',
    ),
    _CourseTemplateLesson(
      id: 'thu_bio_5',
      weekday: DateTime.thursday,
      period: 5,
      subject: 'Biology',
      topic: 'Cell Structure',
      classroom: 'A-202',
      startTime: '14:00',
      endTime: '14:45',
    ),
    _CourseTemplateLesson(
      id: 'fri_hist_6',
      weekday: DateTime.friday,
      period: 6,
      subject: 'History',
      topic: 'Industrial Revolution',
      classroom: 'C-101',
      startTime: '15:00',
      endTime: '15:45',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refreshSelectedLesson();
  }

  @override
  void dispose() {
    _masteryNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Schedule'),
        actions: [
          IconButton(
            tooltip: 'Open Plans',
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
          _buildCurrentView(context),
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
                _smallChip('Month lessons: $monthLessons'),
                _smallChip('Day lessons: $dayLessons'),
                _smallChip('Mastery records: ${_masteryRecords.length}'),
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

  Widget _buildCurrentView(BuildContext context) {
    switch (_view) {
      case CourseScheduleView.year:
        return _buildYearView(context);
      case CourseScheduleView.month:
        return _buildMonthView(context);
      case CourseScheduleView.day:
        return _buildDayView();
      case CourseScheduleView.lesson:
        return _buildLessonView(context);
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
                  Text('Lessons: ${monthLessons.length}'),
                  const SizedBox(height: 6),
                  if (topSubjects.isEmpty)
                    const Text('No lessons')
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
                  const Text('Tap to month view'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthView(BuildContext context) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
              Text('No lesson on ${_dateLabel(_focusDate)}'),
              const SizedBox(height: 6),
              const Text('Switch to month view and choose another day.'),
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
                    title: Text('${lesson.subject}  P${lesson.period}'),
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

  Widget _buildLessonView(BuildContext context) {
    final lesson = _selectedLesson ?? _lessonsForDate(_focusDate).firstOrNull;
    if (lesson == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No lesson selected'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => setState(() => _view = CourseScheduleView.day),
                icon: const Icon(Icons.view_day),
                label: const Text('Back to day view'),
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
        _afterClassPracticeCard(lesson),
        const SizedBox(height: 12),
        _masteryCard(context, lesson),
        if (_masteryRecords.isNotEmpty) ...[
          const SizedBox(height: 12),
          _masteryHistoryCard(),
        ],
      ],
    );
  }

  Widget _currentLessonCard(BuildContext context, _CourseLesson lesson) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Current Lesson',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _smallChip(_dateLabel(lesson.date)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${lesson.subject}  P${lesson.period}',
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
                label: Text(_startingLesson ? 'Starting...' : 'Start Lesson'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _knowledgeSummaryCard(_CourseLesson lesson) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Knowledge Summary',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('- Topic: ${lesson.topic}'),
            Text('- Key concept: ${lesson.subject} fundamentals'),
            const Text('- Placeholder for AI-generated summary details'),
          ],
        ),
      ),
    );
  }

  Widget _afterClassPracticeCard(_CourseLesson lesson) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'After-Class Practice',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('- Placeholder for AI question generation'),
            const Text(
              '- Placeholder for homework checklist and completion status',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openPracticePrompt(lesson),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Practice Prompt'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _masteryCard(BuildContext context, _CourseLesson lesson) {
    final scoreText = _masteryScore.round().toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mastery Evaluation',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Score: $scoreText / 100'),
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
                labelText: 'Lesson note (optional)',
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
                  _savingMastery ? 'Saving...' : 'Save to Review Plan',
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
              'Mastery History',
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
                      'score ${record.score}  |  plan ${record.planTitle}',
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _startLesson(_CourseLesson lesson) async {
    if (_startingLesson) {
      return;
    }
    setState(() => _startingLesson = true);

    final agentProvider = context.read<AIAgentProvider>();
    try {
      if (agentProvider.agents.isEmpty) {
        await agentProvider.refreshAgents();
      }
      final enabledAgents = agentProvider.agents
          .where((agent) => agent.enabled)
          .toList(growable: false);
      if (enabledAgents.isEmpty) {
        throw StateError('No enabled AI agent found.');
      }

      final selectedAgent = _selectLessonAgent(enabledAgents);
      await agentProvider.selectAgent(selectedAgent.id);
      await agentProvider.createSession(
        title: 'Lesson ${lesson.subject} ${_dateLabel(lesson.date)}',
      );
      final sessionId = agentProvider.selectedSessionIdOf(selectedAgent.id);
      if (sessionId.isNotEmpty) {
        await agentProvider.updateSessionScheduleBinding(
          sessionId: sessionId,
          mode: 'manual',
          theme: '${lesson.subject}: ${lesson.topic}',
          autoEnabled: true,
          manualPlanIds: const <String>[],
        );
      }

      await agentProvider.sendMessage(_buildLessonKickoffPrompt(lesson));
      if (!mounted) {
        return;
      }
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AgentChatHubScreen()));
    } catch (_) {
      if (!mounted) {
        return;
      }
      final message =
          agentProvider.errorMessage ?? 'Failed to start lesson session.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _startingLesson = false);
      }
    }
  }

  Future<void> _saveMastery(_CourseLesson lesson) async {
    if (_savingMastery) {
      return;
    }
    setState(() => _savingMastery = true);

    final appProvider = context.read<AppProvider>();
    final score = _masteryScore.round();
    final targetDate = _nextReviewDate(score, lesson.date);
    final note = _masteryNoteController.text.trim();
    final planTitle =
        'Review ${lesson.subject} (${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')})';

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
            lessonLabel: '${lesson.subject} P${lesson.period}',
            score: score,
            createdAt: DateTime.now(),
            planTitle: planTitle,
          ),
        );
        _masteryNoteController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved mastery and created review plan: $planTitle'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      final message =
          appProvider.errorMessage ?? 'Failed to save mastery plan.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _savingMastery = false);
      }
    }
  }

  void _openPracticePrompt(_CourseLesson lesson) {
    final message =
        'Practice prompt prepared: ${lesson.subject} - ${lesson.topic}. '
        'Use Start Lesson to send this context to AI tutor.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  AIAgentSummary _selectLessonAgent(List<AIAgentSummary> agents) {
    final preferred = agents.where((agent) {
      final name = agent.name.toLowerCase();
      return name.contains('tutor') ||
          name.contains('lesson') ||
          name.contains('teacher');
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

  String _buildLessonKickoffPrompt(_CourseLesson lesson) {
    final date = _dateLabel(lesson.date);
    return [
      'Start a lesson tutoring session.',
      'Date: $date',
      'Subject: ${lesson.subject}',
      'Topic: ${lesson.topic}',
      'Period: ${lesson.period}',
      'Please follow this sequence:',
      '1) Explain key concepts briefly.',
      '2) Give one worked example.',
      '3) Ask the student one check question.',
      '4) Evaluate the answer and explain mistakes.',
      '5) Provide next-step review suggestions.',
    ].join('\n');
  }

  String _buildMasteryPlanContent({
    required _CourseLesson lesson,
    required int score,
    required String note,
  }) {
    final recommendation = _recommendationForScore(score);
    return [
      'Course: ${lesson.subject}',
      'Topic: ${lesson.topic}',
      'Date: ${_dateLabel(lesson.date)}',
      'Mastery score: $score/100',
      'Recommendation: $recommendation',
      'Class note: ${note.isEmpty ? '-' : note}',
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
      return 'Re-study immediately and do 3 extra exercises.';
    }
    if (score < 80) {
      return 'Review within 48h and finish a short quiz.';
    }
    return 'Schedule a spaced review in 3-4 days.';
  }

  List<_CourseLesson> _lessonsInMonth(int year, int month) {
    final days = DateUtils.getDaysInMonth(year, month);
    final out = <_CourseLesson>[];
    for (var day = 1; day <= days; day++) {
      final date = DateTime(year, month, day);
      out.addAll(_lessonsForDate(date));
    }
    return out;
  }

  List<_CourseLesson> _lessonsForDate(DateTime date) {
    final normalizedDate = DateUtils.dateOnly(date);
    return _weeklyTemplates
        .where((template) => template.weekday == normalizedDate.weekday)
        .map((template) {
          final dayKey = _toDateKey(normalizedDate);
          return _CourseLesson(
            id: '${template.id}_$dayKey',
            date: normalizedDate,
            period: template.period,
            subject: template.subject,
            topic: template.topic,
            classroom: template.classroom,
            startTime: template.startTime,
            endTime: template.endTime,
          );
        })
        .toList(growable: false)
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
        return 'Year';
      case CourseScheduleView.month:
        return 'Month';
      case CourseScheduleView.day:
        return 'Day';
      case CourseScheduleView.lesson:
        return 'Lesson';
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

class _CourseTemplateLesson {
  const _CourseTemplateLesson({
    required this.id,
    required this.weekday,
    required this.period,
    required this.subject,
    required this.topic,
    required this.classroom,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final int weekday;
  final int period;
  final String subject;
  final String topic;
  final String classroom;
  final String startTime;
  final String endTime;
}

class _CourseLesson {
  const _CourseLesson({
    required this.id,
    required this.date,
    required this.period,
    required this.subject,
    required this.topic,
    required this.classroom,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final DateTime date;
  final int period;
  final String subject;
  final String topic;
  final String classroom;
  final String startTime;
  final String endTime;
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

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
