import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/mistake.dart';
import '../models/plan.dart';
import '../models/pomodoro.dart';
import '../models/practice.dart';
import '../models/question.dart';
import '../models/resource.dart';

class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? _defaultBaseUrl(),
      _client = client ?? http.Client();

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:8080/api/v1';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }

    return 'http://127.0.0.1:8080/api/v1';
  }

  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/healthz'))
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Question>> getQuestions({String? subject, String? source}) async {
    final query = <String, String>{};
    if (subject != null && subject.trim().isNotEmpty) {
      query['subject'] = subject.trim();
    }
    if (source != null && source.trim().isNotEmpty) {
      query['source'] = source.trim();
    }

    final uri = Uri.parse('$baseUrl/questions').replace(queryParameters: query);
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    _throwApiErrorIfNeeded(response, 'Failed to load questions');

    return _extractDataList(response.body).map(Question.fromJson).toList();
  }

  Future<Question> createQuestion(Map<String, dynamic> input) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/questions'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(input),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 201 && response.statusCode != 200) {
      _throwApiErrorIfNeeded(response, 'Failed to create question');
    }

    return Question.fromJson(_extractDataMap(response.body));
  }

  Future<PracticeAttempt> submitPractice(
    String questionId,
    List<String> userAnswer,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/practice/submit'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'question_id': questionId,
            'user_answer': userAnswer,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwApiErrorIfNeeded(response, 'Failed to submit practice');
    }

    return PracticeAttempt.fromJson(_extractDataMap(response.body));
  }

  Future<List<PracticeAttempt>> getPracticeAttempts() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/practice/attempts'))
        .timeout(const Duration(seconds: 10));
    _throwApiErrorIfNeeded(response, 'Failed to load practice attempts');

    return _extractDataList(
      response.body,
    ).map(PracticeAttempt.fromJson).toList();
  }

  Future<List<MistakeRecord>> getMistakes() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/mistakes'))
        .timeout(const Duration(seconds: 10));
    _throwApiErrorIfNeeded(response, 'Failed to load mistakes');

    return _extractDataList(response.body).map(MistakeRecord.fromJson).toList();
  }

  Future<List<ResourceMaterial>> getResources() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/resources'))
        .timeout(const Duration(seconds: 10));
    _throwApiErrorIfNeeded(response, 'Failed to load resources');

    return _extractDataList(
      response.body,
    ).map(ResourceMaterial.fromJson).toList();
  }

  Future<ResourceMaterial> uploadResource(
    String filePath,
    String category,
    String tags,
  ) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/resources'))
          ..files.add(await http.MultipartFile.fromPath('file', filePath))
          ..fields['category'] = category
          ..fields['tags'] = tags;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwApiErrorIfNeeded(response, 'Failed to upload resource');
    }

    return ResourceMaterial.fromJson(_extractDataMap(response.body));
  }

  Future<List<PlanItem>> getPlans({String? planType}) async {
    final query = <String, String>{};
    if (planType != null && planType.trim().isNotEmpty) {
      query['plan_type'] = planType.trim();
    }

    final uri = Uri.parse('$baseUrl/plans').replace(queryParameters: query);
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    _throwApiErrorIfNeeded(response, 'Failed to load plans');

    return _extractDataList(response.body).map(PlanItem.fromJson).toList();
  }

  Future<PlanItem> createPlan(Map<String, dynamic> input) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/plans'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(input),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwApiErrorIfNeeded(response, 'Failed to create plan');
    }

    return PlanItem.fromJson(_extractDataMap(response.body));
  }

  Future<List<PomodoroSession>> getPomodoroSessions({String? status}) async {
    final query = <String, String>{};
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }

    final uri = Uri.parse('$baseUrl/pomodoro').replace(queryParameters: query);
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    _throwApiErrorIfNeeded(response, 'Failed to load pomodoro sessions');

    return _extractDataList(
      response.body,
    ).map(PomodoroSession.fromJson).toList();
  }

  Future<PomodoroSession> startPomodoro({
    required String taskTitle,
    String planId = '',
    int durationMinutes = 25,
    int breakMinutes = 5,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/pomodoro/start'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'task_title': taskTitle,
            'plan_id': planId,
            'duration_minutes': durationMinutes,
            'break_minutes': breakMinutes,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwApiErrorIfNeeded(response, 'Failed to start pomodoro');
    }

    return PomodoroSession.fromJson(_extractDataMap(response.body));
  }

  Future<PomodoroSession> endPomodoro(
    String id, {
    String status = 'completed',
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/pomodoro/$id/end'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'status': status}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      _throwApiErrorIfNeeded(response, 'Failed to end pomodoro');
    }

    return PomodoroSession.fromJson(_extractDataMap(response.body));
  }

  Future<Map<String, dynamic>> buildLearningPlan(
    Map<String, dynamic> input,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/ai/learning'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(input),
        )
        .timeout(const Duration(seconds: 10));

    _throwApiErrorIfNeeded(response, 'Failed to build learning plan');
    return _extractDataMap(response.body);
  }

  List<Map<String, dynamic>> _extractDataList(String body) {
    final decoded = json.decode(body);
    final list = decoded is Map<String, dynamic>
        ? decoded['data'] as List<dynamic>? ?? []
        : <dynamic>[];

    return list.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Map<String, dynamic> _extractDataMap(String body) {
    final decoded = json.decode(body);

    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return decoded;
    }

    return <String, dynamic>{};
  }

  void _throwApiErrorIfNeeded(http.Response response, String fallbackMessage) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    try {
      final decoded = json.decode(response.body);
      final errorObj = decoded is Map<String, dynamic>
          ? decoded['error'] as Map<String, dynamic>?
          : null;
      final message = errorObj?['message']?.toString();

      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
    } catch (_) {
      // fallback below
    }

    throw Exception('$fallbackMessage (HTTP ${response.statusCode})');
  }
}
