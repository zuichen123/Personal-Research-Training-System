import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question.dart';
import '../models/mistake.dart';
import '../models/practice.dart';
import '../models/resource.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8080/api/v1'});

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/healthz'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- Questions ---
  Future<List<Question>> getQuestions() async {
    final response = await http.get(Uri.parse('$baseUrl/questions'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final list = data['data'] as List<dynamic>? ?? [];
      return list.map((e) => Question.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load questions');
    }
  }

  Future<Question> getQuestion(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/questions/$id'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Question.fromJson(data['data'] ?? data);
    } else {
      throw Exception('Failed to load question');
    }
  }

  Future<Question> createQuestion(Map<String, dynamic> input) async {
    final response = await http.post(
      Uri.parse('$baseUrl/questions'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(input),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body);
      return Question.fromJson(data['data'] ?? data);
    } else {
      throw Exception('Failed to create question: ${response.body}');
    }
  }
  
  Future<void> updateQuestion(String id, Map<String, dynamic> input) async {
    final response = await http.put(
      Uri.parse('$baseUrl/questions/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(input),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update question: ${response.body}');
    }
  }

  Future<void> deleteQuestion(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/questions/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete question');
    }
  }

  // --- Mistakes ---
  Future<List<MistakeRecord>> getMistakes() async {
    final response = await http.get(Uri.parse('$baseUrl/mistakes'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final list = data['data'] as List<dynamic>? ?? [];
      return list.map((e) => MistakeRecord.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load mistakes');
    }
  }

  // --- Practice ---
  Future<PracticeAttempt> submitPractice(String questionId, List<String> userAnswer) async {
    final response = await http.post(
      Uri.parse('$baseUrl/practice/submit'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'question_id': questionId,
        'user_answer': userAnswer,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return PracticeAttempt.fromJson(data['data'] ?? data);
    } else {
      throw Exception('Failed to submit practice');
    }
  }

  Future<List<PracticeAttempt>> getPracticeAttempts() async {
    final response = await http.get(Uri.parse('$baseUrl/practice/attempts'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final list = data['data'] as List<dynamic>? ?? [];
      return list.map((e) => PracticeAttempt.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load practice attempts');
    }
  }

  // --- Resources ---
  Future<List<ResourceMaterial>> getResources() async {
    final response = await http.get(Uri.parse('$baseUrl/resources'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final list = data['data'] as List<dynamic>? ?? [];
      return list.map((e) => ResourceMaterial.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load resources');
    }
  }

  // File upload logic should use MultipartRequest
  Future<ResourceMaterial> uploadResource(String filePath, String category, String tags) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/resources'));
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    request.fields['category'] = category;
    request.fields['tags'] = tags;

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return ResourceMaterial.fromJson(data['data'] ?? data);
    } else {
      throw Exception('Failed to upload resource');
    }
  }
}
