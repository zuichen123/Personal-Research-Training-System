import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/logging/app_logger.dart';
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

class ApiService {
  ApiService({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? _defaultBaseUrl(),
      _client = client ?? http.Client();

  static const Duration _defaultRequestTimeout = Duration(seconds: 15);
  static const Duration _aiRequestTimeout = Duration(seconds: 60);

  final String baseUrl;
  final http.Client _client;
  final AppLogger _logger = AppLogger.instance;

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

  Future<Question> getQuestionById(String id) async {
    final response = await _request(method: 'GET', path: '/questions/$id');
    return Question.fromJson(_extractDataMap(response));
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
  ) async {
    final response = await _request(
      method: 'POST',
      path: '/practice/submit',
      jsonBody: {'question_id': questionId, 'user_answer': userAnswer},
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

  Future<MistakeRecord> getMistakeById(String id) async {
    final response = await _request(method: 'GET', path: '/mistakes/$id');
    return MistakeRecord.fromJson(_extractDataMap(response));
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

  Future<ResourceMaterial> getResourceById(String id) async {
    final response = await _request(method: 'GET', path: '/resources/$id');
    return ResourceMaterial.fromJson(_extractDataMap(response));
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

  Future<PlanItem> getPlanById(String id) async {
    final response = await _request(method: 'GET', path: '/plans/$id');
    return PlanItem.fromJson(_extractDataMap(response));
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

  Future<Map<String, dynamic>> buildLearningPlan(
    Map<String, dynamic> input,
  ) async {
    final response = await _request(
      method: 'POST',
      path: '/ai/learning',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
  }

  Future<Map<String, dynamic>> optimizeLearningPlan(
    Map<String, dynamic> input,
  ) async {
    final response = await _request(
      method: 'POST',
      path: '/ai/learning/optimize',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
  }

  Future<List<Question>> generateAIQuestions(
    Map<String, dynamic> input, {
    bool persist = false,
  }) async {
    final response = await _request(
      method: 'POST',
      path: '/ai/questions/generate',
      query: {'persist': '$persist'},
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _extractDataList(response).map(Question.fromJson).toList();
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
    final response = await _request(
      method: 'POST',
      path: '/ai/grade',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
  }

  Future<Map<String, dynamic>> evaluateWithAI(
    Map<String, dynamic> input,
  ) async {
    final response = await _request(
      method: 'POST',
      path: '/ai/evaluate',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
  }

  Future<Map<String, dynamic>> scoreWithAI(Map<String, dynamic> input) async {
    final response = await _request(
      method: 'POST',
      path: '/ai/score',
      jsonBody: input,
      timeout: _aiRequestTimeout,
    );
    return _extractDataMap(response);
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
