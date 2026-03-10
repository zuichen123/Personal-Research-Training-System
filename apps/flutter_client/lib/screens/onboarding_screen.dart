import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OnboardingScreen extends StatefulWidget {
  final String userId;

  const OnboardingScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _currentQuestion = '';
  int _currentStep = 0;
  bool _isFinal = false;
  bool _isLoading = true;
  final TextEditingController _answerController = TextEditingController();
  final List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _loadNextQuestion();
  }

  Future<void> _loadNextQuestion() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/api/profile/onboarding/next?user_id=${widget.userId}'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _currentQuestion = data['question'];
          _currentStep = data['step'];
          _isFinal = data['is_final'];
          _chatHistory.add({'role': 'assistant', 'content': _currentQuestion});
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('加载问题失败');
    }
  }

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;

    setState(() {
      _chatHistory.add({'role': 'user', 'content': answer});
      _isLoading = true;
    });
    _answerController.clear();

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/profile/onboarding/answer'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': widget.userId,
          'step': _currentStep,
          'response': answer,
        }),
      );

      if (response.statusCode == 200) {
        if (_isFinal) {
          await _completeOnboarding();
        } else {
          await _loadNextQuestion();
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('保存答案失败');
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/profile/onboarding/complete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': widget.userId}),
      );

      if (response.statusCode == 200) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      _showError('完成引导失败');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('初始设置 (${_currentStep + 1}/10)'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_currentStep + 1) / 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final message = _chatHistory[index];
                final isUser = message['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(message['content']!),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _answerController,
                      decoration: const InputDecoration(
                        hintText: '输入你的答案...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submitAnswer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _submitAnswer,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }
}
