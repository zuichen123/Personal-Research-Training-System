import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/question.dart';
import '../models/mistake.dart';
import '../models/practice.dart';
import '../models/resource.dart';

class AppProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Question> _questions = [];
  List<Question> get questions => _questions;

  List<MistakeRecord> _mistakes = [];
  List<MistakeRecord> get mistakes => _mistakes;

  List<PracticeAttempt> _attempts = [];
  List<PracticeAttempt> get attempts => _attempts;

  List<ResourceMaterial> _resources = [];
  List<ResourceMaterial> get resources => _resources;

  Future<void> loadAllData() async {
    _setLoading(true);
    try {
      await Future.wait([
        fetchQuestions(),
        fetchMistakes(),
        fetchAttempts(),
        fetchResources(),
      ]);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchQuestions() async {
    try {
      _questions = await _api.getQuestions();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> createQuestion(Map<String, dynamic> input) async {
    try {
      final q = await _api.createQuestion(input);
      _questions.add(q);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> fetchMistakes() async {
    try {
      _mistakes = await _api.getMistakes();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> fetchAttempts() async {
    try {
      _attempts = await _api.getPracticeAttempts();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> fetchResources() async {
    try {
      _resources = await _api.getResources();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> submitPractice(String questionId, List<String> userAnswers) async {
    try {
      final attempt = await _api.submitPractice(questionId, userAnswers);
      _attempts.insert(0, attempt);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
