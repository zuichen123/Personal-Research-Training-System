import 'package:flutter/foundation.dart';

import '../core/logging/app_logger.dart';
import '../i18n/error_mapper.dart';
import '../models/ai_agent_chat.dart';
import '../services/api_service.dart';

class AIAgentProvider with ChangeNotifier {
  AIAgentProvider({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;
  final AppLogger _logger = AppLogger.instance;

  bool _loading = false;
  bool get loading => _loading;

  bool _sending = false;
  bool get sending => _sending;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<AIAgentSummary> _agents = [];
  List<AIAgentSummary> get agents => _agents;

  String _selectedAgentId = '';
  String get selectedAgentId => _selectedAgentId;

  final Map<String, List<AIAgentSession>> _sessionsByAgent = {};
  final Map<String, String> _selectedSessionByAgent = {};
  final Map<String, List<AIAgentMessage>> _messagesBySession = {};
  final Map<String, List<AIAgentArtifact>> _artifactsBySession = {};

  List<AIAgentSession> sessionsOf(String agentId) =>
      _sessionsByAgent[agentId] ?? const <AIAgentSession>[];

  String selectedSessionIdOf(String agentId) =>
      _selectedSessionByAgent[agentId] ?? '';

  List<AIAgentMessage> messagesOf(String sessionId) =>
      _messagesBySession[sessionId] ?? const <AIAgentMessage>[];

  List<AIAgentArtifact> artifactsOf(String sessionId) =>
      _artifactsBySession[sessionId] ?? const <AIAgentArtifact>[];

  Future<void> initialize() async {
    try {
      await refreshAgents();
    } catch (_) {
      // Keep provider error state without crashing initial screen rendering.
    }
  }

  Future<void> refreshAgents() async {
    await _runLoading(() async {
      _agents = await _api.getAIAgents();
      if (_agents.isEmpty) {
        _selectedAgentId = '';
        return;
      }
      if (_selectedAgentId.isEmpty ||
          !_agents.any((item) => item.id == _selectedAgentId)) {
        _selectedAgentId = _agents.first.id;
      }
      await _loadSessions(_selectedAgentId);
    });
  }

  Future<void> createAgent({
    required String name,
    required String protocol,
    required String primaryBaseUrl,
    required String primaryApiKey,
    required String primaryModel,
    String fallbackBaseUrl = '',
    String fallbackApiKey = '',
    String fallbackModel = '',
    String systemPrompt = '',
    bool enabled = true,
    List<String> intentCapabilities = const [
      'chat',
      'generate_questions',
      'build_plan',
    ],
  }) async {
    await _runLoading(() async {
      await _api.createAIAgent({
        'name': name,
        'protocol': protocol,
        'primary': {
          'base_url': primaryBaseUrl,
          'api_key': primaryApiKey,
          'model': primaryModel,
        },
        'fallback': {
          'base_url': fallbackBaseUrl,
          'api_key': fallbackApiKey,
          'model': fallbackModel,
        },
        'system_prompt': systemPrompt,
        'intent_capabilities': intentCapabilities,
        'enabled': enabled,
      });
      await refreshAgents();
    });
  }

  Future<void> updateAgent({
    required String id,
    required String name,
    required String protocol,
    required String primaryBaseUrl,
    required String primaryApiKey,
    required String primaryModel,
    String fallbackBaseUrl = '',
    String fallbackApiKey = '',
    String fallbackModel = '',
    String systemPrompt = '',
    bool enabled = true,
    List<String> intentCapabilities = const [
      'chat',
      'generate_questions',
      'build_plan',
    ],
  }) async {
    await _runLoading(() async {
      await _api.updateAIAgent(id, {
        'name': name,
        'protocol': protocol,
        'primary': {
          'base_url': primaryBaseUrl,
          'api_key': primaryApiKey,
          'model': primaryModel,
        },
        'fallback': {
          'base_url': fallbackBaseUrl,
          'api_key': fallbackApiKey,
          'model': fallbackModel,
        },
        'system_prompt': systemPrompt,
        'intent_capabilities': intentCapabilities,
        'enabled': enabled,
      });
      await refreshAgents();
    });
  }

  Future<void> deleteAgent(String id) async {
    await _runLoading(() async {
      await _api.deleteAIAgent(id);
      await refreshAgents();
    });
  }

  Future<void> selectAgent(String agentId) async {
    if (agentId.trim().isEmpty) {
      return;
    }
    _selectedAgentId = agentId.trim();
    notifyListeners();
    await _loadSessions(_selectedAgentId);
  }

  Future<void> createSession({String title = ''}) async {
    if (_selectedAgentId.isEmpty) {
      return;
    }
    await _runLoading(() async {
      final created = await _api.createAIAgentSession(
        _selectedAgentId,
        title: title,
      );
      final current = _sessionsByAgent[_selectedAgentId] ?? [];
      _sessionsByAgent[_selectedAgentId] = [created, ...current];
      _selectedSessionByAgent[_selectedAgentId] = created.id;
      notifyListeners();
      await loadSessionData(created.id);
    });
  }

  Future<void> deleteSession(String sessionId) async {
    if (sessionId.trim().isEmpty) {
      return;
    }
    await _runLoading(() async {
      await _api.deleteAIAgentSession(sessionId.trim());
      await _loadSessions(_selectedAgentId);
    });
  }

  Future<void> selectSession(String sessionId) async {
    if (_selectedAgentId.isEmpty || sessionId.trim().isEmpty) {
      return;
    }
    _selectedSessionByAgent[_selectedAgentId] = sessionId.trim();
    notifyListeners();
    await loadSessionData(sessionId.trim());
  }

  Future<void> loadSessionData(String sessionId) async {
    await _runLoading(() async {
      await Future.wait([_loadMessages(sessionId), _loadArtifacts(sessionId)]);
    });
  }

  Future<void> sendMessage(String content) async {
    if (_selectedAgentId.isEmpty) {
      return;
    }
    final text = content.trim();
    if (text.isEmpty) {
      return;
    }
    final sessionId = selectedSessionIdOf(_selectedAgentId);
    if (sessionId.isEmpty) {
      await createSession(title: 'Chat ${DateTime.now().toIso8601String()}');
    }
    final activeSessionId = selectedSessionIdOf(_selectedAgentId);
    if (activeSessionId.isEmpty) {
      return;
    }
    _sending = true;
    notifyListeners();
    try {
      final result = await _api.sendAISessionMessage(
        activeSessionId,
        content: text,
      );
      final currentMessages = List<AIAgentMessage>.from(
        _messagesBySession[activeSessionId] ?? const <AIAgentMessage>[],
      );
      final exists = currentMessages.any(
        (item) => item.id == result.assistantMessage.id,
      );
      if (!exists) {
        currentMessages.add(result.assistantMessage);
      }
      _messagesBySession[activeSessionId] = currentMessages;
      if (result.artifact != null) {
        final currentArtifacts = List<AIAgentArtifact>.from(
          _artifactsBySession[activeSessionId] ?? const <AIAgentArtifact>[],
        );
        currentArtifacts.removeWhere((item) => item.id == result.artifact!.id);
        currentArtifacts.insert(0, result.artifact!);
        _artifactsBySession[activeSessionId] = currentArtifacts;
      }
      _errorMessage = null;
      notifyListeners();
      await _loadSessions(_selectedAgentId);
      await _loadMessages(activeSessionId);
    } catch (e) {
      _errorMessage = mapErrorToZh(e);
      _logger.error(
        module: 'ai_agent_provider',
        event: 'send.error',
        message: 'send message failed',
        error: e.toString(),
      );
      notifyListeners();
      rethrow;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> confirmAction({
    required String messageId,
    String action = '',
    Map<String, dynamic>? params,
  }) async {
    if (_selectedAgentId.isEmpty) {
      return;
    }
    final sessionId = selectedSessionIdOf(_selectedAgentId);
    if (sessionId.isEmpty) {
      return;
    }
    _sending = true;
    notifyListeners();
    try {
      final result = await _api.confirmAISessionAction(
        sessionId,
        messageId: messageId,
        action: action,
        params: params,
      );
      final currentMessages = List<AIAgentMessage>.from(
        _messagesBySession[sessionId] ?? const <AIAgentMessage>[],
      );
      currentMessages.removeWhere(
        (item) => item.id == result.assistantMessage.id,
      );
      currentMessages.add(result.assistantMessage);
      _messagesBySession[sessionId] = currentMessages;
      if (result.artifact != null) {
        final currentArtifacts = List<AIAgentArtifact>.from(
          _artifactsBySession[sessionId] ?? const <AIAgentArtifact>[],
        );
        currentArtifacts.removeWhere((item) => item.id == result.artifact!.id);
        currentArtifacts.insert(0, result.artifact!);
        _artifactsBySession[sessionId] = currentArtifacts;
      }
      _errorMessage = null;
      notifyListeners();
      await _loadMessages(sessionId);
      await _loadArtifacts(sessionId);
    } catch (e) {
      _errorMessage = mapErrorToZh(e);
      _logger.error(
        module: 'ai_agent_provider',
        event: 'confirm.error',
        message: 'confirm action failed',
        error: e.toString(),
      );
      notifyListeners();
      rethrow;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> importArtifactQuestions(
    String artifactId, {
    required List<int> selectedIndexes,
    String subjectOverride = '',
    int difficultyOverride = 0,
  }) async {
    final result = await _api.importAIArtifactQuestions(
      artifactId,
      selectedIndexes: selectedIndexes,
      subjectOverride: subjectOverride,
      difficultyOverride: difficultyOverride,
    );
    await _refreshCurrentArtifacts();
    return result;
  }

  Future<Map<String, dynamic>> importArtifactPlan(String artifactId) async {
    final result = await _api.importAIArtifactPlan(artifactId);
    await _refreshCurrentArtifacts();
    return result;
  }

  Future<Map<String, dynamic>> compressCurrentSession({
    bool force = false,
    String trigger = 'manual',
  }) async {
    if (_selectedAgentId.isEmpty) {
      return const <String, dynamic>{'status': 'skipped', 'trigger': 'manual'};
    }
    final sessionId = selectedSessionIdOf(_selectedAgentId);
    if (sessionId.isEmpty) {
      return const <String, dynamic>{'status': 'skipped', 'trigger': 'manual'};
    }
    _sending = true;
    notifyListeners();
    try {
      final result = await _api.compressAISessionMessages(
        sessionId,
        force: force,
        trigger: trigger,
      );
      await _loadSessions(_selectedAgentId);
      await _loadMessages(sessionId);
      _errorMessage = null;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = mapErrorToZh(e);
      _logger.error(
        module: 'ai_agent_provider',
        event: 'compress.error',
        message: 'compress session failed',
        error: e.toString(),
      );
      notifyListeners();
      rethrow;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> _refreshCurrentArtifacts() async {
    if (_selectedAgentId.isEmpty) {
      return;
    }
    final sessionId = selectedSessionIdOf(_selectedAgentId);
    if (sessionId.isEmpty) {
      return;
    }
    await _loadArtifacts(sessionId);
  }

  Future<void> _loadSessions(String agentId) async {
    if (agentId.trim().isEmpty) {
      return;
    }
    final sessions = await _api.getAIAgentSessions(agentId);
    _sessionsByAgent[agentId] = sessions;
    if (sessions.isEmpty) {
      _selectedSessionByAgent.remove(agentId);
      notifyListeners();
      return;
    }
    final current = _selectedSessionByAgent[agentId] ?? '';
    if (!sessions.any((item) => item.id == current)) {
      _selectedSessionByAgent[agentId] = sessions.first.id;
    }
    notifyListeners();
    await loadSessionData(_selectedSessionByAgent[agentId]!);
  }

  Future<void> _loadMessages(String sessionId) async {
    final items = await _api.getAISessionMessages(sessionId);
    _messagesBySession[sessionId] = items;
    notifyListeners();
  }

  Future<void> _loadArtifacts(String sessionId) async {
    final items = await _api.getAISessionArtifacts(sessionId);
    _artifactsBySession[sessionId] = items;
    notifyListeners();
  }

  Future<void> _runLoading(Future<void> Function() action) async {
    _loading = true;
    notifyListeners();
    try {
      await action();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = mapErrorToZh(e);
      _logger.error(
        module: 'ai_agent_provider',
        event: 'load.error',
        message: 'ai agent operation failed',
        error: e.toString(),
      );
      notifyListeners();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
