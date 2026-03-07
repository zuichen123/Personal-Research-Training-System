import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/logging/app_logger.dart';
import '../models/ai_agent_chat.dart';
import '../core/logging/trace_id.dart';
import '../models/mistake.dart';
import '../models/plan.dart';
import '../models/pomodoro.dart';
import '../models/practice.dart';
import '../models/question.dart';
import '../models/resource.dart';
import '../models/user_profile.dart';

class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  final String code;
  final String message;
  final int statusCode;

  @override
  String toString() => '$message (HTTP $statusCode, code=$code)';
}

class DownloadedResource {
  DownloadedResource({
    required this.filename,
    required this.contentType,
    required this.bytes,
  });

  final String filename;
  final String contentType;
  final Uint8List bytes;
}

typedef AIStreamProgressCallback = void Function(String message);

class ApiService {
  ApiService({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? _defaultBaseUrl(),
      _client = client ?? http.Client();

  static const Duration _defaultRequestTimeout = Duration(seconds: 15);
  static const Duration _aiRequestTimeout = Duration(seconds: 120);
  static const Duration _aiStreamIdleTimeout = Duration(seconds: 20);

  final String baseUrl;
  final http.Client _client;
  final AppLogger _logger = AppLogger.instance;

  static String _defaultBaseUrl() {
    const configured = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (configured.trim().isNotEmpty) {
      return _normalizeBaseUrl(configured);
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8080/api/v1';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://127.0.0.1:8080/api/v1';
  }

  static String _normalizeBaseUrl(String raw) {
    var normalized = raw.trim();
    for (; normalized.endsWith('/');) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Future<bool> checkHealth() async {
    try {
      final response = await _request(
        method: 'GET',
        path: '/healthz',
        timeout: const Duration(seconds: 8),
      );
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
    final response = await _request(
      method: 'GET',
      path: '/questions',
      query: query,
    );
    return _extractDataList(response).map(Question.fromJson).toList();
  }

  Future<Question> createQuestion(Map<String, dynamic> input) async {
    final response = await _request(
      method: 'POST',
      path: '/questions',
      jsonBody: input,
    );
    return Question.fromJson(_extractDataMap(response));
  }

  Future<Question> updateQuestion(String id, Map<String, dynamic> input) async {
    final response = await _request(
      method: 'PUT',
      path: '/questions/$id',
      jsonBody: input,
    );
    return Question.fromJson(_extractDataMap(response));
  }

  Future<void> deleteQuestion(String id) async {
    await _request(method: 'DELETE', path: '/questions/$id');
  }

  Future<PracticeAttempt> submitPractice(
    String questionId,
    List<String> userAnswer,
    int elapsedSeconds,
  ) async {
    final response = await _request(
      method: 'POST',
      path: '/practice/submit',
      jsonBody: {
        'question_id': questionId,
        'user_answer': userAnswer,
        'elapsed_seconds': elapsedSeconds,
      },
    );
    return PracticeAttempt.fromJson(_extractDataMap(response));
  }

  Future<List<PracticeAttempt>> getPracticeAttempts({
    String? questionId,
  }) async {
    final query = <String, String>{};
    if (questionId != null && questionId.trim().isNotEmpty) {
      query['question_id'] = questionId.trim();
    }
    final response = await _request(
      method: 'GET',
      path: '/practice/attempts',
      query: query,
    );
    return _extractDataList(response).map(PracticeAttempt.fromJson).toList();
  }

  Future<void> deletePracticeAttempt(String id) async {
    await _request(method: 'DELETE', path: '/practice/attempts/$id');
  }

  Future<List<MistakeRecord>> getMistakes({String? questionId}) async {
    final query = <String, String>{};
    if (questionId != null && questionId.trim().isNotEmpty) {
      query['question_id'] = questionId.trim();
    }
    final response = await _request(
      method: 'GET',
      path: '/mistakes',
      query: query,
    );
    return _extractDataList(response).map(MistakeRecord.fromJson).toList();
  }

  Future<MistakeRecord> createMistake(Map<String, dynamic> input) async {
    final response = await _request(
      method: 'POST',
      path: '/mistakes',
      jsonBody: input,
    );
    return MistakeRecord.fromJson(_extractDataMap(response));
  }

  Future<void> deleteMistake(String id) async {
    await _request(method: 'DELETE', path: '/mistakes/$id');
  }

  Future<List<ResourceMaterial>> getResources({String? questionId}) async {
    final query = <String, String>{};
    if (questionId != null && questionId.trim().isNotEmpty) {
      query['question_id'] = questionId.trim();
    }
    final response = await _request(
      method: 'GET',
      path: '/resources',
      query: query,
    );
    return _extractDataList(response).map(ResourceMaterial.fromJson).toList();
  }

  Future<ResourceMaterial> uploadResource({
    required String filePath,
    required String category,
    required String tags,
    String questionId = '',
  }) async {
    final traceId = newTraceId();
    final uri = Uri.parse('$baseUrl/resources');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', filePath))
      ..fields['category'] = category
      ..fields['tags'] = tags;
    if (questionId.trim().isNotEmpty) {
      request.fields['question_id'] = questionId.trim();
    }
    request.headers['X-Trace-ID'] = traceId;

    final start = DateTime.now();
    _logger.info(
      module: 'api',
      event: 'api.call.start',
      message: '上传资料请求开始',
      data: {'method': 'POST', 'path': '/resources', 'trace_id': traceId},
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final latency = DateTime.now().difference(start).inMilliseconds;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final ex = _toApiException(response);
      _logger.error(
        module: 'api',
        event: 'api.call.error',
        message: '上传资料失败',
        data: {
          'method': 'POST',
          'path': '/resources',
          'status': response.statusCode,
          'latency_ms': latency,
          'trace_id': traceId,
        },
        error: ex.toString(),
      );
      throw ex;
    }

    _logger.info(
      module: 'api',
      event: 'api.call.end',
      message: '上传资料成功',
      data: {
        'method': 'POST',
        'path': '/resources',
        'status': response.statusCode,
        'latency_ms': latency,
        'trace_id': traceId,
      },
    );
    return ResourceMaterial.fromJson(_extractDataMap(response));
  }

  Future<DownloadedResource> downloadResource(String id) async {
    final response = await _request(
      method: 'GET',
      path: '/resources/$id/download',
      expectJson: false,
    );
    final contentType =
        response.headers['content-type'] ?? 'application/octet-stream';
    final disposition = response.headers['content-disposition'] ?? '';
    final filename =
        _filenameFromDisposition(disposition) ?? 'resource_$id.bin';
    return DownloadedResource(
      filename: filename,
      contentType: contentType,
      bytes: response.bodyBytes,
    );
  }

  Future<void> deleteResource(String id) async {
    await _request(method: 'DELETE', path: '/resources/$id');
  }

  Future<List<PlanItem>> getPlans({String? planType}) async {
    final query = <String, String>{};
    if (planType != null && planType.trim().isNotEmpty) {
      query['plan_type'] = planType.trim();
    }
    final response = await _request(
      method: 'GET',
      path: '/plans',
      query: query,
    );
    return _extractDataList(response).map(PlanItem.fromJson).toList();
  }

  Future<PlanItem> createPlan(Map<String, dynamic> input) async {
    final response = await _request(
      method: 'POST',
      path: '/plans',
      jsonBody: input,
    );
    return PlanItem.fromJson(_extractDataMap(response));
  }

  Future<PlanItem> updatePlan(String id, Map<String, dynamic> input) async {
    final response = await _request(
      method: 'PUT',
      path: '/plans/$id',
      jsonBody: input,
    );
    return PlanItem.fromJson(_extractDataMap(response));
  }

  Future<void> deletePlan(String id) async {
    await _request(method: 'DELETE', path: '/plans/$id');
  }

  Future<List<PomodoroSession>> getPomodoroSessions({String? status}) async {
    final query = <String, String>{};
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    final response = await _request(
      method: 'GET',
      path: '/pomodoro',
      query: query,
    );
    return _extractDataList(response).map(PomodoroSession.fromJson).toList();
  }

  Future<PomodoroSession> startPomodoro({
    required String taskTitle,
    String planId = '',
    int durationMinutes = 25,
    int breakMinutes = 5,
  }) async {
    final response = await _request(
      method: 'POST',
      path: '/pomodoro/start',
      jsonBody: {
        'task_title': taskTitle,
        'plan_id': planId,
        'duration_minutes': durationMinutes,
        'break_minutes': breakMinutes,
      },
    );
    return PomodoroSession.fromJson(_extractDataMap(response));
  }

  Future<PomodoroSession> endPomodoro(
    String id, {
    String status = 'completed',
  }) async {
    final response = await _request(
      method: 'POST',
      path: '/pomodoro/$id/end',
      jsonBody: {'status': status},
    );
    return PomodoroSession.fromJson(_extractDataMap(response));
  }

  Future<void> deletePomodoro(String id) async {
    await _request(method: 'DELETE', path: '/pomodoro/$id');
  }

  Future<UserProfile> getUserProfile({String userId = 'default'}) async {
    final query = <String, String>{};
    if (userId.trim().isNotEmpty) {
      query['user_id'] = userId.trim();
    }
    final response = await _request(
      method: 'GET',
      path: '/profile',
      query: query,
    );
    return UserProfile.fromJson(_extractDataMap(response));
  }

  Future<UserProfile> updateUserProfile({
    String userId = 'default',
    required String nickname,
    required int age,
    required String academicStatus,
    required List<String> goals,
    String goalTargetDate = '',
    required int dailyStudyMinutes,
    List<String> weakSubjects = const [],
    String targetDestination = '',
    String notes = '',
  }) async {
    final body = <String, dynamic>{
      'user_id': userId.trim(),
      'nickname': nickname.trim(),
      'age': age,
      'academic_status': academicStatus.trim(),
      'goals': goals,
      'daily_study_minutes': dailyStudyMinutes,
      'weak_subjects': weakSubjects,
      'target_destination': targetDestination.trim(),
      'notes': notes.trim(),
    };
    final normalizedGoalDate = goalTargetDate.trim();
    if (normalizedGoalDate.isNotEmpty) {
      body['goal_target_date'] = normalizedGoalDate;
    }
    final response = await _request(
      method: 'PUT',
      path: '/profile',
      jsonBody: body,
    );
    return UserProfile.fromJson(_extractDataMap(response));
  }

  Future<Map<String, dynamic>> getAIProviderStatus() async {
    final response = await _request(method: 'GET', path: '/ai/provider');
    return _extractDataMap(response);
  }

  Future<Map<String, dynamic>> getAIDefaultAgentProvider() async {
    final response = await _request(
      method: 'GET',
      path: '/ai/provider/default-agent',
    );
    return _extractDataMap(response);
  }

  Future<Map<String, dynamic>> updateAIProviderConfig({
    required String provider,
    String? apiKey,
    String? model,
    String? openAIBaseURL,
  }) async {
    final body = <String, dynamic>{'provider': provider};
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      body['api_key'] = apiKey.trim();
    }
    if (model != null && model.trim().isNotEmpty) {
      body['model'] = model.trim();
    }
    if (openAIBaseURL != null && openAIBaseURL.trim().isNotEmpty) {
      body['openai_base_url'] = openAIBaseURL.trim();
    }
    final response = await _request(
      method: 'PUT',
      path: '/ai/provider/config',
      jsonBody: body,
    );
    return _extractDataMap(response);
  }

  Future<List<Map<String, dynamic>>> getAIPromptTemplates() async {
    final response = await _request(method: 'GET', path: '/ai/prompts');
    return _extractDataList(response);
  }

  Future<Map<String, dynamic>> updateAIPromptTemplate({
    required String key,
    String? customPrompt,
    String? outputFormatPrompt,
    Map<String, String>? segmentUpdates,
    List<String>? segmentDeletes,
    bool? replaceSegments,
  }) async {
    final body = <String, dynamic>{};
    if (customPrompt != null) {
      body['custom_prompt'] = customPrompt;
    }
    if (outputFormatPrompt != null) {
      body['output_format_prompt'] = outputFormatPrompt;
    }
    if (segmentUpdates != null) {
      body['segment_updates'] = segmentUpdates;
    }
    if (segmentDeletes != null) {
      body['segment_deletes'] = segmentDeletes;
    }
    if (replaceSegments != null) {
      body['replace_segments'] = replaceSegments;
    }
    final response = await _request(
      method: 'PUT',
      path: '/ai/prompts/$key',
      jsonBody: body,
    );
    return _extractDataMap(response);
  }

  Future<List<Map<String, dynamic>>> reloadAIPromptTemplates() async {
    final response = await _request(method: 'POST', path: '/ai/prompts/reload');
    return _extractDataList(response);
  }

  Future<List<AIAgentSummary>> getAIAgents() async {
    final response = await _request(method: 'GET', path: '/ai/agents');
    return _extractDataList(response).map(AIAgentSummary.fromJson).toList();
  }

  Future<AIAgentSummary> createAIAgent(Map<String, dynamic> input) async {
    final response = await _request(
      method: 'POST',
      path: '/ai/agents',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return AIAgentSummary.fromJson(_extractDataMap(response));
  }

  Future<AIAgentSummary> updateAIAgent(
    String id,
    Map<String, dynamic> input,
  ) async {
    final response = await _request(
      method: 'PUT',
      path: '/ai/agents/$id',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return AIAgentSummary.fromJson(_extractDataMap(response));
  }

  Future<void> deleteAIAgent(String id) async {
    await _request(method: 'DELETE', path: '/ai/agents/$id');
  }

  Future<List<AIAgentSession>> getAIAgentSessions(
    String agentId, {
    int limit = 20,
    String cursor = '',
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      if (cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
    };
    final response = await _request(
      method: 'GET',
      path: '/ai/agents/$agentId/sessions',
      query: query,
      timeout: _aiRequestTimeout,
    );
    return _extractDataList(response).map(AIAgentSession.fromJson).toList();
  }

  Future<AIAgentSession> createAIAgentSession(
    String agentId, {
    String title = '',
  }) async {
    final response = await _request(
      method: 'POST',
      path: '/ai/agents/$agentId/sessions',
      jsonBody: {'title': title},
      timeout: _aiRequestTimeout,
    );
    return AIAgentSession.fromJson(_extractDataMap(response));
  }

  Future<void> deleteAIAgentSession(String sessionId) async {
    await _request(method: 'DELETE', path: '/ai/sessions/$sessionId');
  }

  Future<Map<String, dynamic>> getAISessionScheduleBinding(
    String sessionId,
  ) async {
    final response = await _request(
      method: 'GET',
      path: '/ai/sessions/$sessionId/schedule-binding',
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
  }

  Future<Map<String, dynamic>> updateAISessionScheduleBinding(
    String sessionId,
    Map<String, dynamic> input,
  ) async {
    final response = await _request(
      method: 'PUT',
      path: '/ai/sessions/$sessionId/schedule-binding',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
  }

  Future<List<AIAgentMessage>> getAISessionMessages(
    String sessionId, {
    int limit = 40,
    String beforeId = '',
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      if (beforeId.trim().isNotEmpty) 'before_id': beforeId.trim(),
    };
    final response = await _request(
      method: 'GET',
      path: '/ai/sessions/$sessionId/messages',
      query: query,
      timeout: _aiRequestTimeout,
    );
    return _extractDataList(response).map(AIAgentMessage.fromJson).toList();
  }

  Future<AISendMessageResult> sendAISessionMessage(
    String sessionId, {
    required String content,
    AIStreamProgressCallback? onProgress,
  }) async {
    final data = await _requestAIStreamData(
      path: '/ai/sessions/$sessionId/messages',
      jsonBody: {'content': content},
      timeout: _aiRequestTimeout,
      onProgress: onProgress,
    );
    return AISendMessageResult.fromJson(_asMap(data));
  }

  Future<AISendMessageResult> confirmAISessionAction(
    String sessionId, {
    required String messageId,
    String action = '',
    Map<String, dynamic>? params,
    AIStreamProgressCallback? onProgress,
  }) async {
    final body = <String, dynamic>{
      'message_id': messageId,
      if (action.trim().isNotEmpty) 'action': action.trim(),
      if (params != null && params.isNotEmpty) 'params': params,
    };
    final data = await _requestAIStreamData(
      path: '/ai/sessions/$sessionId/confirm',
      jsonBody: body,
      timeout: _aiRequestTimeout,
      onProgress: onProgress,
    );
    return AISendMessageResult.fromJson(_asMap(data));
  }

  Future<Map<String, dynamic>> compressAISessionMessages(
    String sessionId, {
    bool force = false,
    String trigger = 'manual',
  }) async {
    final normalizedTrigger = trigger.trim().toLowerCase() == 'auto'
        ? 'auto'
        : 'manual';
    final response = await _request(
      method: 'POST',
      path: '/ai/sessions/$sessionId/compress',
      jsonBody: {'force': force, 'trigger': normalizedTrigger},
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
  }

  Future<List<AIAgentArtifact>> getAISessionArtifacts(
    String sessionId, {
    String status = '',
  }) async {
    final query = <String, String>{
      if (status.trim().isNotEmpty) 'status': status.trim(),
    };
    final response = await _request(
      method: 'GET',
      path: '/ai/sessions/$sessionId/artifacts',
      query: query,
      timeout: _aiRequestTimeout,
    );
    return _extractDataList(response).map(AIAgentArtifact.fromJson).toList();
  }

  Future<Map<String, dynamic>> importAIArtifactQuestions(
    String artifactId, {
    required List<int> selectedIndexes,
    String subjectOverride = '',
    int difficultyOverride = 0,
  }) async {
    final response = await _request(
      method: 'POST',
      path: '/ai/artifacts/$artifactId/import/questions',
      jsonBody: {
        'selected_indexes': selectedIndexes,
        if (subjectOverride.trim().isNotEmpty)
          'subject_override': subjectOverride.trim(),
        if (difficultyOverride > 0) 'difficulty_override': difficultyOverride,
      },
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
  }

  Future<Map<String, dynamic>> importAIArtifactPlan(
    String artifactId, {
    bool append = true,
  }) async {
    final response = await _request(
      method: 'POST',
      path: '/ai/artifacts/$artifactId/import/plan',
      jsonBody: {'append': append},
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
  }

  Future<Map<String, dynamic>> buildLearningPlan(
    Map<String, dynamic> input,
  ) async {
    final data = await _requestAIStreamData(
      path: '/ai/learning',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> optimizeLearningPlan(
    Map<String, dynamic> input,
  ) async {
    final data = await _requestAIStreamData(
      path: '/ai/learning/optimize',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _asMap(data);
  }

  Future<List<Question>> generateAIQuestions(
    Map<String, dynamic> input, {
    bool persist = false,
  }) async {
    final data = await _requestAIStreamData(
      path: '/ai/questions/generate',
      query: {'persist': '$persist'},
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _asMapList(data).map(Question.fromJson).toList();
  }

  Future<List<Question>> searchAIQuestions({
    required String topic,
    String subject = '',
    int count = 5,
  }) async {
    final response = await _request(
      method: 'GET',
      path: '/ai/questions/search',
      query: {'topic': topic, 'subject': subject, 'count': '$count'},
      timeout: _aiRequestTimeout,
    );
    return _extractDataList(response).map(Question.fromJson).toList();
  }

  Future<Map<String, dynamic>> gradeWithAI(Map<String, dynamic> input) async {
    final data = await _requestAIStreamData(
      path: '/ai/grade',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> evaluateWithAI(
    Map<String, dynamic> input,
  ) async {
    final data = await _requestAIStreamData(
      path: '/ai/evaluate',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> scoreWithAI(Map<String, dynamic> input) async {
    final data = await _requestAIStreamData(
      path: '/ai/score',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> computeMathWithAI(
    Map<String, dynamic> input,
  ) async {
    final data = await _requestAIStreamData(
      path: '/ai/math/compute',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> verifyMathWithAI(
    Map<String, dynamic> input,
  ) async {
    final data = await _requestAIStreamData(
      path: '/ai/math/verify',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> listAICourseScheduleLessons({
    String date = '',
    String dateFrom = '',
    String dateTo = '',
    String subject = '',
    String topic = '',
    String granularity = '',
  }) async {
    final query = <String, String>{};
    final normalizedDate = date.trim();
    final normalizedDateFrom = dateFrom.trim();
    final normalizedDateTo = dateTo.trim();
    final normalizedSubject = subject.trim();
    final normalizedTopic = topic.trim();
    final normalizedGranularity = granularity.trim();
    if (normalizedDate.isNotEmpty) {
      query['date'] = normalizedDate;
    }
    if (normalizedDateFrom.isNotEmpty) {
      query['date_from'] = normalizedDateFrom;
    }
    if (normalizedDateTo.isNotEmpty) {
      query['date_to'] = normalizedDateTo;
    }
    if (normalizedSubject.isNotEmpty) {
      query['subject'] = normalizedSubject;
    }
    if (normalizedTopic.isNotEmpty) {
      query['topic'] = normalizedTopic;
    }
    if (normalizedGranularity.isNotEmpty) {
      query['granularity'] = normalizedGranularity;
    }
    final response = await _request(
      method: 'GET',
      path: '/ai/course-schedule/lessons',
      query: query.isEmpty ? null : query,
      timeout: _aiRequestTimeout,
    );
    return _extractDataList(response).map(_asMap).toList(growable: false);
  }

  Future<Map<String, dynamic>> createAICourseScheduleLesson(
    Map<String, dynamic> input,
  ) async {
    final response = await _request(
      method: 'POST',
      path: '/ai/course-schedule/lessons',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
  }

  Future<Map<String, dynamic>> updateAICourseScheduleLesson(
    String id,
    Map<String, dynamic> input,
  ) async {
    final response = await _request(
      method: 'PUT',
      path: '/ai/course-schedule/lessons/$id',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
  }

  Future<Map<String, dynamic>> deleteAICourseScheduleLesson(String id) async {
    final response = await _request(
      method: 'DELETE',
      path: '/ai/course-schedule/lessons/$id',
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
  }

  Future<dynamic> _requestAIStreamData({
    required String path,
    required Map<String, dynamic> jsonBody,
    Map<String, String>? query,
    Duration timeout = _aiRequestTimeout,
    AIStreamProgressCallback? onProgress,
  }) async {
    final traceId = newTraceId();
    final mergedQuery = <String, String>{...?query, 'stream': '1'};
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: mergedQuery);
    final payload = jsonEncode(jsonBody);
    final started = DateTime.now();

    _logger.info(
      module: 'api',
      event: 'api.stream.start',
      message: 'AI stream request started',
      data: {
        'method': 'POST',
        'path': path,
        'query': mergedQuery,
        'trace_id': traceId,
        'payload_size': payload.length,
      },
    );

    final request = http.Request('POST', uri);
    request.headers['X-Trace-ID'] = traceId;
    request.headers['Content-Type'] = 'application/json';
    request.body = payload;

    late http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client
          .send(request)
          .timeout(
            timeout,
            onTimeout: () => throw TimeoutException(
              'No stream response received in ${timeout.inSeconds}s',
              timeout,
            ),
          );
    } catch (e) {
      final latency = DateTime.now().difference(started).inMilliseconds;
      _logger.error(
        module: 'api',
        event: 'api.stream.error',
        message: 'AI stream request failed before response',
        data: {
          'method': 'POST',
          'path': path,
          'query': mergedQuery,
          'latency_ms': latency,
          'trace_id': traceId,
        },
        error: e.toString(),
      );
      rethrow;
    }

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      final response = await http.Response.fromStream(streamedResponse);
      final ex = _toApiException(response);
      final latency = DateTime.now().difference(started).inMilliseconds;
      _logger.error(
        module: 'api',
        event: 'api.stream.error',
        message: 'AI stream response failed',
        data: {
          'method': 'POST',
          'path': path,
          'query': mergedQuery,
          'status': response.statusCode,
          'latency_ms': latency,
          'trace_id': traceId,
          'response_trace_id': response.headers['x-trace-id'],
        },
        error: ex.toString(),
      );
      throw ex;
    }

    final contentType = (streamedResponse.headers['content-type'] ?? '')
        .toLowerCase();
    if (!contentType.contains('text/event-stream')) {
      final response = await http.Response.fromStream(streamedResponse);
      final data = _decodeNonStreamResponseData(response);
      final latency = DateTime.now().difference(started).inMilliseconds;
      _logger.warn(
        module: 'api',
        event: 'api.stream.fallback',
        message: 'AI stream fallback to JSON response',
        data: {
          'method': 'POST',
          'path': path,
          'query': mergedQuery,
          'status': response.statusCode,
          'latency_ms': latency,
          'trace_id': traceId,
          'response_trace_id': response.headers['x-trace-id'],
          'content_type': contentType,
        },
      );
      return data;
    }

    try {
      final data = await _readSSEData(
        stream: streamedResponse.stream,
        idleTimeout: _aiStreamIdleTimeout,
        timeout: timeout,
        onProgress: onProgress,
      );
      final latency = DateTime.now().difference(started).inMilliseconds;
      _logger.info(
        module: 'api',
        event: 'api.stream.end',
        message: 'AI stream request finished',
        data: {
          'method': 'POST',
          'path': path,
          'query': mergedQuery,
          'status': streamedResponse.statusCode,
          'latency_ms': latency,
          'trace_id': traceId,
          'response_trace_id': streamedResponse.headers['x-trace-id'],
        },
      );
      return data;
    } catch (e) {
      final latency = DateTime.now().difference(started).inMilliseconds;
      _logger.error(
        module: 'api',
        event: 'api.stream.error',
        message: 'AI stream body parse failed',
        data: {
          'method': 'POST',
          'path': path,
          'query': mergedQuery,
          'status': streamedResponse.statusCode,
          'latency_ms': latency,
          'trace_id': traceId,
          'response_trace_id': streamedResponse.headers['x-trace-id'],
        },
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<dynamic> _readSSEData({
    required Stream<List<int>> stream,
    required Duration idleTimeout,
    required Duration timeout,
    AIStreamProgressCallback? onProgress,
  }) async {
    Future<dynamic> consume() async {
      final lineStream = stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(
            idleTimeout,
            onTimeout: (sink) => sink.addError(
              TimeoutException(
                'No stream event received in ${idleTimeout.inSeconds}s',
                idleTimeout,
              ),
            ),
          );

      var currentEvent = 'message';
      final dataLines = <String>[];
      final plainLines = <String>[];
      dynamic resultData;
      var hasResult = false;

      void resetEvent() {
        currentEvent = 'message';
        dataLines.clear();
      }

      void emitProgress(dynamic payload) {
        if (onProgress == null) {
          return;
        }
        final message = _extractStreamProgressMessage(payload);
        if (message.isNotEmpty) {
          onProgress(message);
        }
      }

      void handleEvent() {
        if (dataLines.isEmpty) {
          resetEvent();
          return;
        }
        final payloadText = dataLines.join('\n');
        final payload = _decodeStreamPayload(payloadText);
        switch (currentEvent) {
          case 'start':
          case 'progress':
            emitProgress(payload);
            break;
          case 'error':
            throw _streamPayloadToException(payload);
          case 'result':
            if (payload is Map<String, dynamic> &&
                payload.containsKey('data')) {
              resultData = payload['data'];
            } else {
              resultData = payload;
            }
            hasResult = true;
            break;
          default:
            break;
        }
        resetEvent();
      }

      await for (final line in lineStream) {
        if (line.isEmpty) {
          handleEvent();
          continue;
        }
        if (line.startsWith(':')) {
          continue;
        }
        if (line.startsWith('event:')) {
          currentEvent = line.substring(6).trim();
          continue;
        }
        if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
          continue;
        }
        plainLines.add(line);
      }
      if (dataLines.isNotEmpty) {
        handleEvent();
      }
      if (!hasResult) {
        final fallbackPayloadText = plainLines.join('\n').trim();
        if (fallbackPayloadText.isNotEmpty) {
          final fallbackPayload = _decodeStreamPayload(fallbackPayloadText);
          if (fallbackPayload is Map<String, dynamic> &&
              fallbackPayload.containsKey('error')) {
            throw _streamPayloadToException(fallbackPayload);
          }
          if (fallbackPayload is Map<String, dynamic> &&
              fallbackPayload.containsKey('data')) {
            return fallbackPayload['data'];
          }
          return fallbackPayload;
        }
        throw ApiException(
          code: 'stream_no_result',
          message: 'AI stream ended without result',
          statusCode: 502,
        );
      }
      return resultData;
    }

    return consume().timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'AI stream exceeded ${timeout.inSeconds}s',
        timeout,
      ),
    );
  }

  dynamic _decodeNonStreamResponseData(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) {
      throw ApiException(
        code: 'empty_body',
        message: 'AI response body is empty',
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final errorObj = decoded['error'];
      if (errorObj is Map<String, dynamic>) {
        throw ApiException(
          code: errorObj['code']?.toString() ?? 'api_error',
          message: errorObj['message']?.toString() ?? 'AI request failed',
          statusCode: response.statusCode,
        );
      }
      if (decoded.containsKey('data')) {
        return decoded['data'];
      }
      return decoded;
    }
    return decoded;
  }

  dynamic _decodeStreamPayload(String payload) {
    final normalized = payload.trim();
    if (normalized.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return jsonDecode(normalized);
    } catch (_) {
      return <String, dynamic>{'message': normalized};
    }
  }

  String _extractStreamProgressMessage(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return '';
    }
    final direct = payload['message']?.toString().trim() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }
    final elapsedMS = (payload['elapsed_ms'] as num?)?.toInt();
    if (elapsedMS == null || elapsedMS <= 0) {
      return '';
    }
    return 'AI request is running (${(elapsedMS / 1000).floor()}s)';
  }

  ApiException _streamPayloadToException(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final errorObj = payload['error'];
      if (errorObj is Map<String, dynamic>) {
        final statusCode = (errorObj['http_status'] as num?)?.toInt() ?? 500;
        return ApiException(
          code: errorObj['code']?.toString() ?? 'ai_stream_error',
          message:
              errorObj['message']?.toString() ?? 'AI stream request failed',
          statusCode: statusCode,
        );
      }
      final fallbackMessage = payload['message']?.toString() ?? '';
      if (fallbackMessage.trim().isNotEmpty) {
        return ApiException(
          code: 'ai_stream_error',
          message: fallbackMessage.trim(),
          statusCode: 500,
        );
      }
    }
    return ApiException(
      code: 'ai_stream_error',
      message: 'AI stream request failed',
      statusCode: 500,
    );
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) {
      return const <Map<String, dynamic>>[];
    }
    return raw
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
  }

  Future<http.Response> _request({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, dynamic>? jsonBody,
    Duration timeout = _defaultRequestTimeout,
    bool expectJson = true,
  }) async {
    final traceId = newTraceId();
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final started = DateTime.now();
    final payload = jsonBody == null ? null : jsonEncode(jsonBody);

    _logger.info(
      module: 'api',
      event: 'api.call.start',
      message: '请求开始',
      data: {
        'method': method,
        'path': path,
        'query': query,
        'trace_id': traceId,
        'payload_size': payload?.length ?? 0,
      },
    );

    late http.Response response;
    try {
      response = await _sendWithIdleTimeout(
        method: method,
        uri: uri,
        traceId: traceId,
        payload: payload,
        idleTimeout: timeout,
      );
    } catch (e) {
      final latency = DateTime.now().difference(started).inMilliseconds;
      _logger.error(
        module: 'api',
        event: 'api.call.error',
        message: '请求异常',
        data: {
          'method': method,
          'path': path,
          'query': query,
          'latency_ms': latency,
          'trace_id': traceId,
        },
        error: e.toString(),
      );
      rethrow;
    }

    final latency = DateTime.now().difference(started).inMilliseconds;
    final responseTraceId = response.headers['x-trace-id'];
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final ex = _toApiException(response);
      _logger.error(
        module: 'api',
        event: 'api.call.error',
        message: '请求失败',
        data: {
          'method': method,
          'path': path,
          'query': query,
          'status': response.statusCode,
          'latency_ms': latency,
          'trace_id': traceId,
          'response_trace_id': responseTraceId,
        },
        error: ex.toString(),
      );
      throw ex;
    }

    _logger.info(
      module: 'api',
      event: 'api.call.end',
      message: '请求成功',
      data: {
        'method': method,
        'path': path,
        'query': query,
        'status': response.statusCode,
        'latency_ms': latency,
        'trace_id': traceId,
        'response_trace_id': responseTraceId,
        'response_size': response.bodyBytes.length,
      },
    );

    if (expectJson && response.body.isEmpty) {
      throw ApiException(
        code: 'empty_body',
        message: '接口返回为空',
        statusCode: response.statusCode,
      );
    }
    return response;
  }

  Future<http.Response> _sendWithIdleTimeout({
    required String method,
    required Uri uri,
    required String traceId,
    required Duration idleTimeout,
    String? payload,
  }) async {
    final normalizedMethod = method.toUpperCase();
    final request = http.Request(normalizedMethod, uri);
    request.headers['X-Trace-ID'] = traceId;
    if (normalizedMethod == 'POST' || normalizedMethod == 'PUT') {
      request.headers['Content-Type'] = 'application/json';
      request.body = payload ?? '';
    }

    final streamedResponse = await _client
        .send(request)
        .timeout(
          idleTimeout,
          onTimeout: () => throw TimeoutException(
            'No response received in ${idleTimeout.inSeconds}s',
            idleTimeout,
          ),
        );
    final bytes = await _readBodyWithIdleTimeout(
      streamedResponse.stream,
      idleTimeout,
    );
    return http.Response.bytes(
      bytes,
      streamedResponse.statusCode,
      headers: streamedResponse.headers,
      isRedirect: streamedResponse.isRedirect,
      persistentConnection: streamedResponse.persistentConnection,
      reasonPhrase: streamedResponse.reasonPhrase,
      request: streamedResponse.request,
    );
  }

  Future<Uint8List> _readBodyWithIdleTimeout(
    Stream<List<int>> stream,
    Duration idleTimeout,
  ) {
    final completer = Completer<Uint8List>();
    final builder = BytesBuilder(copy: false);
    StreamSubscription<List<int>>? subscription;
    Timer? timer;

    void resetTimer() {
      timer?.cancel();
      timer = Timer(idleTimeout, () async {
        await subscription?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException(
              'No response content received in ${idleTimeout.inSeconds}s',
              idleTimeout,
            ),
          );
        }
      });
    }

    resetTimer();
    subscription = stream.listen(
      (chunk) {
        builder.add(chunk);
        resetTimer();
      },
      onError: (Object error, StackTrace stackTrace) {
        timer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      onDone: () {
        timer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(builder.takeBytes());
        }
      },
      cancelOnError: true,
    );
    return completer.future;
  }

  List<Map<String, dynamic>> _extractDataList(http.Response response) {
    final decoded = jsonDecode(response.body);
    final list = decoded is Map<String, dynamic>
        ? decoded['data'] as List<dynamic>? ?? <dynamic>[]
        : <dynamic>[];
    return list.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Map<String, dynamic> _extractDataMap(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return decoded;
    }
    return <String, dynamic>{};
  }

  ApiException _toApiException(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final errorObj = decoded['error'];
        if (errorObj is Map<String, dynamic>) {
          return ApiException(
            code: errorObj['code']?.toString() ?? 'api_error',
            message: errorObj['message']?.toString() ?? '请求失败',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (_) {
      // ignore parse error and fallback
    }
    return ApiException(
      code: 'http_${response.statusCode}',
      message: '请求失败',
      statusCode: response.statusCode,
    );
  }

  String? _filenameFromDisposition(String raw) {
    final marker = 'filename=';
    final idx = raw.toLowerCase().indexOf(marker);
    if (idx < 0) {
      return null;
    }
    final value = raw.substring(idx + marker.length).trim();
    return value.replaceAll('"', '').trim();
  }
}
