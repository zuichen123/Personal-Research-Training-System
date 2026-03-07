import 'dart:math' as math;

import 'package:flutter/material.dart';

enum CourseScheduleView { year, month, day, lesson }

class CourseScheduleScreen extends StatefulWidget {
  const CourseScheduleScreen({super.key});

  @override
  State<CourseScheduleScreen> createState() => _CourseScheduleScreenState();
}

class _CourseScheduleScreenState extends State<CourseScheduleScreen> {
  CourseScheduleView _view = CourseScheduleView.year;
  DateTime _focusDate = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Course Schedule')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _buildNavigatorCard(context),
          const SizedBox(height: 12),
          _buildViewSwitcher(context),
          const SizedBox(height: 12),
          _buildCurrentView(context),
        ],
      ),
    );
  }

  Widget _buildNavigatorCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
            const SizedBox(height: 6),
            Text(
              'Step 1 skeleton: year/month/day/lesson views ready for data binding.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSwitcher(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CourseScheduleView.values
              .map((view) {
                return ChoiceChip(
                  selected: _view == view,
                  label: Text(_viewLabel(view)),
                  onSelected: (_) => setState(() => _view = view),
                );
              })
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
        return _buildDayView(context);
      case CourseScheduleView.lesson:
        return _buildLessonView();
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
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {
        final month = index + 1;
        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _focusDate = DateTime(year, month, 1);
                _view = CourseScheduleView.month;
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
                  const SizedBox(height: 6),
                  const Text('No courses yet'),
                  const Spacer(),
                  const Text('Tap to open month view'),
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
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                if (index < leadingBlank ||
                    index >= leadingBlank + daysInMonth) {
                  return const SizedBox.shrink();
                }
                final day = index - leadingBlank + 1;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _focusDate = DateTime(year, month, day);
                      _view = CourseScheduleView.day;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text('$day')),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayView(BuildContext context) {
    final slots = List.generate(8, (index) => index + 1);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: slots
              .map((slot) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('$slot')),
                  title: const Text('No lesson assigned'),
                  subtitle: Text('Period $slot - ${_timeRange(slot)}'),
                  trailing: const Icon(Icons.chevron_right),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildLessonView() {
    const lessons = [
      'Math',
      'English',
      'Physics',
      'Chemistry',
      'Biology',
      'History',
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: lessons
              .map((lesson) {
                return Card(
                  child: ListTile(
                    title: Text(lesson),
                    subtitle: const Text('No schedule bound yet'),
                    trailing: const Icon(Icons.schedule),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  void _moveFocus(int offset) {
    setState(() {
      switch (_view) {
        case CourseScheduleView.year:
          _focusDate = DateTime(
            _focusDate.year + offset,
            _focusDate.month,
            _focusDate.day,
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
          _focusDate = _focusDate.add(Duration(days: offset));
          break;
        case CourseScheduleView.lesson:
          _focusDate = DateTime(
            _focusDate.year,
            _focusDate.month + offset,
            _focusDate.day,
          );
          break;
      }
    });
  }

  String get _periodLabel {
    switch (_view) {
      case CourseScheduleView.year:
        return '${_focusDate.year} Year';
      case CourseScheduleView.month:
        return '${_focusDate.year}-${_focusDate.month.toString().padLeft(2, '0')}';
      case CourseScheduleView.day:
        return '${_focusDate.year}-${_focusDate.month.toString().padLeft(2, '0')}-${_focusDate.day.toString().padLeft(2, '0')}';
      case CourseScheduleView.lesson:
        return 'Lesson Catalog';
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

  String _timeRange(int slot) {
    final startHour = 7 + slot;
    final endHour = startHour + 1;
    final start = '${startHour.toString().padLeft(2, '0')}:00';
    final end = '${endHour.toString().padLeft(2, '0')}:00';
    return '$start-$end';
  }
}
