import 'package:flutter/material.dart';

import '../core/logging/app_logger.dart';
import '../i18n/error_mapper.dart';
import '../models/mistake.dart';
import '../models/plan.dart';
import '../models/pomodoro.dart';
import '../models/practice.dart';
import '../models/question.dart';
import '../models/resource.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';

enum DataSection {
  questions,
  mistakes,
  attempts,
  resources,
  plans,
  pomodoro,
  profile,
  ai,
}

class AppProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final AppLogger _logger = AppLogger.instance;
  ApiService get apiService => _api;

  final Map<DataSection, bool> _isSectionLoading = {
    DataSection.questions: false,
    DataSection.mistakes: false,
    DataSection.attempts: false,
    DataSection.resources: false,
    DataSection.plans: false,
    DataSection.pomodoro: false,
    DataSection.profile: false,
    DataSection.ai: false,
  };

  final Map<DataSection, bool> _isSectionLoaded = {
    DataSection.questions: false,
    DataSection.mistakes: false,
    DataSection.attempts: false,
    DataSection.resources: false,
    DataSection.plans: false,
    DataSection.pomodoro: false,
    DataSection.profile: false,
    DataSection.ai: false,
  };

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _isSectionLoading.values.any((v) => v);

  bool isSectionLoading(DataSection section) =>
      _isSectionLoading[section] ?? false;

  bool isSectionLoaded(DataSection section) =>
      _isSectionLoaded[section] ?? false;

  List<Question> _questions = [];
  List<Question> get questions => _questions;

  List<MistakeRecord> _mistakes = [];
  List<MistakeRecord> get mistakes => _mistakes;

  List<PracticeAttempt> _attempts = [];
  List<PracticeAttempt> get attempts => _attempts;

  List<ResourceMaterial> _resources = [];
  List<ResourceMaterial> get resources => _resources;

  List<PlanItem> _plans = [];
  List<PlanItem> get plans => _plans;

  List<PomodoroSession> _pomodoroSessions = [];
  List<PomodoroSession> get pomodoroSessions => _pomodoroSessions;

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;

  Map<String, dynamic> _aiProviderStatus = {};
  Map<String, dynamic> get aiProviderStatus => _aiProviderStatus;

  List<Map<String, dynamic>> _aiPromptTemplates = [];
  List<Map<String, dynamic>> get aiPromptTemplates => _aiPromptTemplates;

  Map<String, dynamic>? _aiLearningPlan;
  Map<String, dynamic>? get aiLearningPlan => _aiLearningPlan;

  Map<String, dynamic>? _aiGradeResult;
  Map<String, dynamic>? get aiGradeResult => _aiGradeResult;

  Map<String, dynamic>? _aiEvaluateResult;
  Map<String, dynamic>? get aiEvaluateResult => _aiEvaluateResult;

  Map<String, dynamic>? _aiScoreResult;
  Map<String, dynamic>? get aiScoreResult => _aiScoreResult;

  List<Question> _aiGeneratedQuestions = [];
  List<Question> get aiGeneratedQuestions => _aiGeneratedQuestions;

  List<Question> _aiSearchQuestions = [];
  List<Question> get aiSearchQuestions => _aiSearchQuestions;

  PomodoroSession? get runningPomodoro {
    for (final item in _pomodoroSessions) {
      if (item.status == 'running') {
        return item;
      }
    }
    return null;
  }

  Future<void> ensureDataForTab(int tabIndex) async {
    switch (tabIndex) {
      case 0:
        await ensureAILoaded();
        break;
      case 1:
        await ensureQuestionsLoaded();
        break;
      case 2:
        await ensureMistakesLoaded();
        break;
      case 3:
        await ensureAttemptsLoaded();
        break;
      case 4:
        await ensurePomodoroLoaded();
        break;
      default:
        return;
    }
  }

  Future<void> ensureQuestionsLoaded() async {
    if (!isSectionLoaded(DataSection.questions)) {
      await fetchQuestions();
    }
  }

  Future<void> ensureMistakesLoaded() async {
    if (!isSectionLoaded(DataSection.mistakes)) {
      await fetchMistakes();
    }
  }

  Future<void> ensureAttemptsLoaded() async {
    if (!isSectionLoaded(DataSection.attempts)) {
      await fetchAttempts();
    }
  }

  Future<void> ensureResourcesLoaded() async {
    if (!isSectionLoaded(DataSection.resources)) {
      await fetchResources();
    }
  }

  Future<void> ensurePlansLoaded() async {
    if (!isSectionLoaded(DataSection.plans)) {
      await fetchPlans();
    }
  }

  Future<void> ensurePomodoroLoaded() async {
    if (!isSectionLoaded(DataSection.pomodoro)) {
      await fetchPomodoroSessions();
    }
  }

  Future<void> ensureAILoaded() async {
    if (!isSectionLoaded(DataSection.ai)) {
      await fetchAIProviderStatus();
    }
  }

  Future<void> ensureProfileLoaded() async {
    if (!isSectionLoaded(DataSection.profile)) {
      await fetchUserProfile();
    }
  }

  Future<void> fetchQuestions({bool force = false}) async {
    if (!force && isSectionLoading(DataSection.questions)) {
      return;
    }
    await _runSection(DataSection.questions, () async {
      _questions = await _api.getQuestions();
      _isSectionLoaded[DataSection.questions] = true;
    });
  }

  Future<void> createQuestion(Map<String, dynamic> input) async {
    await _runAction('创建题目', () async {
      final q = await _api.createQuestion(input);
      _questions.insert(0, q);
      _isSectionLoaded[DataSection.questions] = true;
      notifyListeners();
    });
  }

  Future<void> updateQuestion(String id, Map<String, dynamic> input) async {
    await _runAction('更新题目', () async {
      final updated = await _api.updateQuestion(id, input);
      final idx = _questions.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) {
        _questions[idx] = updated;
      } else {
        _questions.insert(0, updated);
      }
      notifyListeners();
    });
  }

  Future<void> deleteQuestion(String id) async {
    await _runAction('删除题目', () async {
      await _api.deleteQuestion(id);
      _questions.removeWhere((e) => e.id == id);
      notifyListeners();
    });
  }

  Future<void> fetchMistakes({bool force = false, String? questionId}) async {
    if (!force && isSectionLoading(DataSection.mistakes)) {
      return;
    }
    await _runSection(DataSection.mistakes, () async {
      _mistakes = await _api.getMistakes(questionId: questionId);
      _isSectionLoaded[DataSection.mistakes] = true;
    });
  }

  Future<void> deleteMistake(String id) async {
    await _runAction('删除错题', () async {
      await _api.deleteMistake(id);
      _mistakes.removeWhere((e) => e.id == id);
      notifyListeners();
    });
  }

  Future<void> createMistake(Map<String, dynamic> input) async {
    await _runAction('新建错题', () async {
      final m = await _api.createMistake(input);
      _mistakes.insert(0, m);
      _isSectionLoaded[DataSection.mistakes] = true;
      notifyListeners();
    });
  }

  Future<void> fetchAttempts({bool force = false, String? questionId}) async {
    if (!force && isSectionLoading(DataSection.attempts)) {
      return;
    }
    await _runSection(DataSection.attempts, () async {
      _attempts = await _api.getPracticeAttempts(questionId: questionId);
      _isSectionLoaded[DataSection.attempts] = true;
    });
  }

  Future<void> submitPractice(
    String questionId,
    List<String> userAnswers,
  ) async {
    await _runAction('提交练习', () async {
      final attempt = await _api.submitPractice(questionId, userAnswers);
      _attempts.insert(0, attempt);
      _isSectionLoaded[DataSection.attempts] = true;
      if (!attempt.correct) {
        await fetchMistakes(force: true);
      }
      notifyListeners();
    });
  }

  Future<void> deletePracticeAttempt(String id) async {
    await _runAction('删除练习记录', () async {
      await _api.deletePracticeAttempt(id);
      _attempts.removeWhere((e) => e.id == id);
      notifyListeners();
    });
  }

  Future<void> fetchResources({bool force = false, String? questionId}) async {
    if (!force && isSectionLoading(DataSection.resources)) {
      return;
    }
    await _runSection(DataSection.resources, () async {
      _resources = await _api.getResources(questionId: questionId);
      _isSectionLoaded[DataSection.resources] = true;
    });
  }

  Future<void> uploadResource({
    required String filePath,
    required String category,
    required String tags,
    String questionId = '',
  }) async {
    await _runAction('上传资料', () async {
      final item = await _api.uploadResource(
        filePath: filePath,
        category: category,
        tags: tags,
        questionId: questionId,
      );
      _resources.insert(0, item);
      _isSectionLoaded[DataSection.resources] = true;
      notifyListeners();
    });
  }

  Future<DownloadedResource> downloadResource(String id) {
    return _api.downloadResource(id);
  }

  Future<void> deleteResource(String id) async {
    await _runAction('删除资料', () async {
      await _api.deleteResource(id);
      _resources.removeWhere((e) => e.id == id);
      notifyListeners();
    });
  }

  Future<void> fetchPlans({bool force = false, String? planType}) async {
    if (!force && isSectionLoading(DataSection.plans)) {
      return;
    }
    await _runSection(DataSection.plans, () async {
      _plans = await _api.getPlans(planType: planType);
      _isSectionLoaded[DataSection.plans] = true;
    });
  }

  Future<void> createPlan(Map<String, dynamic> input) async {
    await _runAction('创建计划', () async {
      final item = await _api.createPlan(input);
      _plans.insert(0, item);
      _isSectionLoaded[DataSection.plans] = true;
      notifyListeners();
    });
  }

  Future<void> updatePlan(String id, Map<String, dynamic> input) async {
    await _runAction('更新计划', () async {
      final updated = await _api.updatePlan(id, input);
      final idx = _plans.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) {
        _plans[idx] = updated;
      } else {
        _plans.insert(0, updated);
      }
      notifyListeners();
    });
  }

  Future<void> deletePlan(String id) async {
    await _runAction('删除计划', () async {
      await _api.deletePlan(id);
      _plans.removeWhere((e) => e.id == id);
      notifyListeners();
    });
  }

  Future<void> fetchPomodoroSessions({
    bool force = false,
    String? status,
  }) async {
    if (!force && isSectionLoading(DataSection.pomodoro)) {
      return;
    }
    await _runSection(DataSection.pomodoro, () async {
      _pomodoroSessions = await _api.getPomodoroSessions(status: status);
      _isSectionLoaded[DataSection.pomodoro] = true;
    });
  }

  Future<void> startPomodoro({
    required String taskTitle,
    int durationMinutes = 25,
    int breakMinutes = 5,
    String planId = '',
  }) async {
    await _runAction('开始专注', () async {
      final session = await _api.startPomodoro(
        taskTitle: taskTitle,
        durationMinutes: durationMinutes,
        breakMinutes: breakMinutes,
        planId: planId,
      );
      _pomodoroSessions.insert(0, session);
      _isSectionLoaded[DataSection.pomodoro] = true;
      notifyListeners();
    });
  }

  Future<void> endPomodoro(String id, {String status = 'completed'}) async {
    await _runAction('结束专注', () async {
      final updated = await _api.endPomodoro(id, status: status);
      final idx = _pomodoroSessions.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) {
        _pomodoroSessions[idx] = updated;
      } else {
        _pomodoroSessions.insert(0, updated);
      }
      notifyListeners();
    });
  }

  Future<void> deletePomodoro(String id) async {
    await _runAction('删除专注记录', () async {
      await _api.deletePomodoro(id);
      _pomodoroSessions.removeWhere((e) => e.id == id);
      notifyListeners();
    });
  }

  Future<void> fetchAIProviderStatus({bool force = false}) async {
    if (!force && isSectionLoading(DataSection.ai)) {
      return;
    }
    await _runSection(DataSection.ai, () async {
      _aiProviderStatus = await _api.getAIProviderStatus();
      _aiPromptTemplates = await _api.getAIPromptTemplates();
      _isSectionLoaded[DataSection.ai] = true;
    });
  }

  Future<void> fetchUserProfile({
    bool force = false,
    String userId = 'default',
  }) async {
    if (!force && isSectionLoading(DataSection.profile)) {
      return;
    }
    await _runSection(DataSection.profile, () async {
      _userProfile = await _api.getUserProfile(userId: userId);
      _isSectionLoaded[DataSection.profile] = true;
    });
  }

  Future<void> updateUserProfile({
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
    await _runAction('更新用户信息', () async {
      _userProfile = await _api.updateUserProfile(
        userId: userId,
        nickname: nickname,
        age: age,
        academicStatus: academicStatus,
        goals: goals,
        goalTargetDate: goalTargetDate,
        dailyStudyMinutes: dailyStudyMinutes,
        weakSubjects: weakSubjects,
        targetDestination: targetDestination,
        notes: notes,
      );
      _isSectionLoaded[DataSection.profile] = true;
      notifyListeners();
    });
  }

  Future<void> updateAIProviderConfig({
    required String provider,
    String? apiKey,
    String? model,
    String? openAIBaseURL,
  }) async {
    await _runAction('更新AI模型API地址', () async {
      _aiProviderStatus = await _api.updateAIProviderConfig(
        provider: provider,
        apiKey: apiKey,
        model: model,
        openAIBaseURL: openAIBaseURL,
      );
      _isSectionLoaded[DataSection.ai] = true;
      notifyListeners();
    });
  }

  Future<void> fetchAIPromptTemplates() async {
    await _runAction('刷新AI Prompt配置', () async {
      _aiPromptTemplates = await _api.getAIPromptTemplates();
      _isSectionLoaded[DataSection.ai] = true;
      notifyListeners();
    });
  }

  Future<void> reloadAIPromptTemplates() async {
    await _runAction('热更新AI Prompt配置', () async {
      _aiPromptTemplates = await _api.reloadAIPromptTemplates();
      _isSectionLoaded[DataSection.ai] = true;
      notifyListeners();
    });
  }

  Future<void> updateAIPromptTemplate({
    required String key,
    String? customPrompt,
    String? outputFormatPrompt,
  }) async {
    await _runAction('更新AI Prompt配置', () async {
      final updated = await _api.updateAIPromptTemplate(
        key: key,
        customPrompt: customPrompt,
        outputFormatPrompt: outputFormatPrompt,
      );
      _upsertPromptTemplate(updated);
      _isSectionLoaded[DataSection.ai] = true;
      notifyListeners();
    });
  }

  Future<void> buildLearningPlan(Map<String, dynamic> input) async {
    await _runAction('生成学习计划', () async {
      final payload = Map<String, dynamic>.from(input);
      final profile = _userProfile;
      payload.putIfAbsent('user_id', () => profile?.userId ?? 'default');
      if (profile != null) {
        payload.putIfAbsent(
          'profile',
          () => {
            'academic_status': profile.academicStatus,
            'daily_study_minutes': profile.dailyStudyMinutes,
            'goals': profile.goals,
            'weak_subjects': profile.weakSubjects,
            'target_destination': profile.targetDestination,
            'notes': profile.notes,
          },
        );
        payload.putIfAbsent('profile_summary', () {
          final goals = profile.goals.join(', ');
          final weak = profile.weakSubjects.join(', ');
          return 'academic=${profile.academicStatus}; daily_minutes=${profile.dailyStudyMinutes}; goals=$goals; weak_subjects=$weak; target=${profile.targetDestination}';
        });
      }
      _aiLearningPlan = await _api.buildLearningPlan(payload);
      notifyListeners();
    });
  }

  Future<void> optimizeLearningPlan({
    required String action,
    int days = 0,
    String reason = '',
    String supplement = '',
  }) async {
    await _runAction('优化学习计划', () async {
      if (_aiLearningPlan == null) {
        throw StateError('ai learning plan is empty');
      }
      final payload = <String, dynamic>{
        'action': action,
        'days': days,
        'reason': reason,
        'supplement': supplement,
        'plan': _aiLearningPlan,
      };
      final optimized = await _api.optimizeLearningPlan(payload);
      final updatedPlan = optimized['updated_plan'];
      if (updatedPlan is Map<String, dynamic>) {
        _aiLearningPlan = updatedPlan;
      } else {
        _aiLearningPlan = optimized;
      }
      notifyListeners();
    });
  }

  Future<int> importLearningPlanToPlans() async {
    var imported = 0;
    await _runAction('导入AI计划到计划表', () async {
      final items = _normalizeLearningPlanItems(_aiLearningPlan);
      if (items.isEmpty) {
        throw StateError('learning plan has no plan_items');
      }
      for (final mapped in items) {
        final planType = _firstNonEmptyKey(mapped, const [
          'plan_type',
          'planType',
          'type',
        ]);
        final title = _firstNonEmptyKey(mapped, const [
          'title',
          'name',
          'final_goal',
        ]);
        if (planType.isEmpty || title.isEmpty) {
          continue;
        }
        final created = await _api.createPlan({
          'plan_type': planType,
          'title': title,
          'content': _firstNonEmptyKey(mapped, const [
            'content',
            'description',
            'detail',
          ]),
          'target_date': _firstNonEmptyKey(mapped, const [
            'target_date',
            'targetDate',
            'end_date',
            'endDate',
          ]),
          'status': _firstNonEmptyKey(mapped, const [
            'status',
            'current_status',
          ], fallback: 'pending'),
          'priority': _parsePlanPriority(mapped['priority']),
          'source': 'ai_learning',
        });
        _plans.insert(0, created);
        imported++;
      }
      if (imported == 0) {
        throw StateError('learning plan has no valid plan_items');
      }
      _isSectionLoaded[DataSection.plans] = true;
      notifyListeners();
    });
    return imported;
  }

  Future<void> generateAIQuestions(
    Map<String, dynamic> input, {
    bool persist = false,
  }) async {
    await _runAction('AI出题', () async {
      _aiGeneratedQuestions = await _api.generateAIQuestions(
        input,
        persist: persist,
      );
      if (persist) {
        await fetchQuestions(force: true);
      }
      notifyListeners();
    });
  }

  Future<void> searchAIQuestions({
    required String topic,
    String subject = '',
    int count = 5,
  }) async {
    await _runAction('AI搜题', () async {
      _aiSearchQuestions = await _api.searchAIQuestions(
        topic: topic,
        subject: subject,
        count: count,
      );
      notifyListeners();
    });
  }

  Future<void> gradeWithAI(Map<String, dynamic> input) async {
    await _runAction('AI批阅', () async {
      _aiGradeResult = await _api.gradeWithAI(input);
      notifyListeners();
    });
  }

  Future<void> evaluateWithAI(Map<String, dynamic> input) async {
    await _runAction('AI评估', () async {
      _aiEvaluateResult = await _api.evaluateWithAI(input);
      notifyListeners();
    });
  }

  Future<void> scoreWithAI(Map<String, dynamic> input) async {
    await _runAction('AI评分', () async {
      _aiScoreResult = await _api.scoreWithAI(input);
      notifyListeners();
    });
  }

  Future<void> _runSection(
    DataSection section,
    Future<void> Function() action,
  ) async {
    _setSectionLoading(section, true);
    try {
      await action();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = mapErrorToZh(e);
      _logger.error(
        module: 'provider',
        event: 'section.error',
        message: '分区数据加载失败',
        data: {'section': section.name},
        error: e.toString(),
      );
    } finally {
      _setSectionLoading(section, false);
    }
  }

  Future<void> _runAction(
    String actionName,
    Future<void> Function() action,
  ) async {
    try {
      _logger.info(
        module: 'provider',
        event: 'action.start',
        message: '$actionName开始',
      );
      await action();
      _errorMessage = null;
      _logger.info(
        module: 'provider',
        event: 'action.end',
        message: '$actionName成功',
      );
    } catch (e) {
      _errorMessage = mapErrorToZh(e);
      _logger.error(
        module: 'provider',
        event: 'action.error',
        message: '$actionName失败',
        error: e.toString(),
      );
      notifyListeners();
      rethrow;
    }
  }

  void _setSectionLoading(DataSection section, bool value) {
    _isSectionLoading[section] = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  List<Map<String, dynamic>> _normalizeLearningPlanItems(
    Map<String, dynamic>? plan,
  ) {
    if (plan == null) {
      return const [];
    }

    final out = <Map<String, dynamic>>[];
    final raw = plan['plan_items'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) {
          continue;
        }
        out.add(Map<String, dynamic>.from(item.cast<dynamic, dynamic>()));
      }
    }
    if (out.isNotEmpty) {
      return out;
    }

    final goal = _firstNonEmptyKey(plan, const ['final_goal', 'goal', 'title']);
    if (goal.isEmpty) {
      return const [];
    }
    return [
      {
        'plan_type': 'current_phase',
        'title': 'AI学习计划',
        'content': goal,
        'target_date': _firstNonEmptyKey(plan, const [
          'plan_end_date',
          'end_date',
        ]),
        'status': _firstNonEmptyKey(plan, const [
          'current_status',
          'status',
        ], fallback: 'pending'),
        'priority': 1,
      },
    ];
  }

  String _firstNonEmptyKey(
    Map<String, dynamic> raw,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = raw[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  int _parsePlanPriority(dynamic raw) {
    final value = int.tryParse('${raw ?? ''}') ?? 3;
    if (value < 1) return 1;
    if (value > 5) return 5;
    return value;
  }

  void _upsertPromptTemplate(Map<String, dynamic> template) {
    final key = (template['key'] ?? '').toString().trim();
    if (key.isEmpty) {
      return;
    }
    final index = _aiPromptTemplates.indexWhere(
      (item) => (item['key'] ?? '').toString().trim() == key,
    );
    if (index >= 0) {
      _aiPromptTemplates[index] = template;
      return;
    }
    _aiPromptTemplates.add(template);
  }
}
