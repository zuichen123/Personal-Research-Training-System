import 'package:flutter/material.dart';

import '../models/mistake.dart';
import '../models/plan.dart';
import '../models/pomodoro.dart';
import '../models/practice.dart';
import '../models/question.dart';
import '../models/resource.dart';
import '../services/api_service.dart';

enum DataSection { questions, mistakes, attempts, resources, plans, pomodoro }

class AppProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  final Map<DataSection, bool> _isSectionLoading = {
    DataSection.questions: false,
    DataSection.mistakes: false,
    DataSection.attempts: false,
    DataSection.resources: false,
    DataSection.plans: false,
    DataSection.pomodoro: false,
  };

  final Map<DataSection, bool> _isSectionLoaded = {
    DataSection.questions: false,
    DataSection.mistakes: false,
    DataSection.attempts: false,
    DataSection.resources: false,
    DataSection.plans: false,
    DataSection.pomodoro: false,
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
        await ensureQuestionsLoaded();
        break;
      case 1:
        await ensureMistakesLoaded();
        break;
      case 2:
        await ensureAttemptsLoaded();
        break;
      case 3:
        await ensureResourcesLoaded();
        break;
      case 4:
        await ensurePlansLoaded();
        break;
      case 5:
        await ensurePomodoroLoaded();
        break;
      default:
        return;
    }
  }

  Future<void> ensureQuestionsLoaded() async {
    if (isSectionLoaded(DataSection.questions)) {
      return;
    }
    await fetchQuestions();
  }

  Future<void> ensureMistakesLoaded() async {
    if (isSectionLoaded(DataSection.mistakes)) {
      return;
    }
    await fetchMistakes();
  }

  Future<void> ensureAttemptsLoaded() async {
    if (isSectionLoaded(DataSection.attempts)) {
      return;
    }
    await fetchAttempts();
  }

  Future<void> ensureResourcesLoaded() async {
    if (isSectionLoaded(DataSection.resources)) {
      return;
    }
    await fetchResources();
  }

  Future<void> ensurePlansLoaded() async {
    if (isSectionLoaded(DataSection.plans)) {
      return;
    }
    await fetchPlans();
  }

  Future<void> ensurePomodoroLoaded() async {
    if (isSectionLoaded(DataSection.pomodoro)) {
      return;
    }
    await fetchPomodoroSessions();
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
    try {
      final q = await _api.createQuestion(input);
      _questions.insert(0, q);
      _isSectionLoaded[DataSection.questions] = true;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchMistakes({bool force = false}) async {
    if (!force && isSectionLoading(DataSection.mistakes)) {
      return;
    }

    await _runSection(DataSection.mistakes, () async {
      _mistakes = await _api.getMistakes();
      _isSectionLoaded[DataSection.mistakes] = true;
    });
  }

  Future<void> fetchAttempts({bool force = false}) async {
    if (!force && isSectionLoading(DataSection.attempts)) {
      return;
    }

    await _runSection(DataSection.attempts, () async {
      _attempts = await _api.getPracticeAttempts();
      _isSectionLoaded[DataSection.attempts] = true;
    });
  }

  Future<void> fetchResources({bool force = false}) async {
    if (!force && isSectionLoading(DataSection.resources)) {
      return;
    }

    await _runSection(DataSection.resources, () async {
      _resources = await _api.getResources();
      _isSectionLoaded[DataSection.resources] = true;
    });
  }

  Future<void> fetchPlans({bool force = false}) async {
    if (!force && isSectionLoading(DataSection.plans)) {
      return;
    }

    await _runSection(DataSection.plans, () async {
      _plans = await _api.getPlans();
      _isSectionLoaded[DataSection.plans] = true;
    });
  }

  Future<void> createPlan(Map<String, dynamic> input) async {
    try {
      final item = await _api.createPlan(input);
      _plans.insert(0, item);
      _isSectionLoaded[DataSection.plans] = true;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchPomodoroSessions({bool force = false}) async {
    if (!force && isSectionLoading(DataSection.pomodoro)) {
      return;
    }

    await _runSection(DataSection.pomodoro, () async {
      _pomodoroSessions = await _api.getPomodoroSessions();
      _isSectionLoaded[DataSection.pomodoro] = true;
    });
  }

  Future<void> startPomodoro({
    required String taskTitle,
    int durationMinutes = 25,
    int breakMinutes = 5,
    String planId = '',
  }) async {
    try {
      final session = await _api.startPomodoro(
        taskTitle: taskTitle,
        durationMinutes: durationMinutes,
        breakMinutes: breakMinutes,
        planId: planId,
      );
      _pomodoroSessions.insert(0, session);
      _isSectionLoaded[DataSection.pomodoro] = true;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> endPomodoro(String id, {String status = 'completed'}) async {
    try {
      final updated = await _api.endPomodoro(id, status: status);
      final idx = _pomodoroSessions.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) {
        _pomodoroSessions[idx] = updated;
      } else {
        _pomodoroSessions.insert(0, updated);
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> submitPractice(
    String questionId,
    List<String> userAnswers,
  ) async {
    try {
      final attempt = await _api.submitPractice(questionId, userAnswers);
      _attempts.insert(0, attempt);
      _isSectionLoaded[DataSection.attempts] = true;

      _isSectionLoaded[DataSection.mistakes] = false;
      if (!attempt.correct) {
        await fetchMistakes(force: true);
      }

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
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
      _errorMessage = e.toString();
    } finally {
      _setSectionLoading(section, false);
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
}
