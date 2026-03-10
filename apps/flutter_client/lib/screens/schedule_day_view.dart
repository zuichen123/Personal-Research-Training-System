import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ScheduleDayView extends StatefulWidget {
  final String userId;
  const ScheduleDayView({Key? key, required this.userId}) : super(key: key);

  @override
  State<ScheduleDayView> createState() => _ScheduleDayViewState();
}

class _ScheduleDayViewState extends State<ScheduleDayView> {
  List<dynamic> _schedules = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    try {
      final date = _selectedDate.toIso8601String().split('T')[0];
      final response = await http.get(
        Uri.parse('http://localhost:8080/api/schedule/daily?user_id=${widget.userId}&date=$date'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _schedules = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('今日课程 ${_selectedDate.month}/${_selectedDate.day}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final schedule = _schedules[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('${schedule['subject']} - ${schedule['topic']}'),
                    subtitle: Text('${schedule['start_time']} (${schedule['duration_minutes']}分钟)'),
                    trailing: ElevatedButton(
                      onPressed: () => _startLesson(schedule['id']),
                      child: const Text('开始上课'),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _startLesson(int scheduleId) {
    Navigator.pushNamed(context, '/lesson', arguments: scheduleId);
  }
}
