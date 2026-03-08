import '../models/ai_agent_chat.dart';
import 'agent_form_utils.dart';
import 'agent_prompt_sections.dart';

class AgentEndpointFormInitialData {
  const AgentEndpointFormInitialData({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;
}

class AgentFormInitialData {
  const AgentFormInitialData({
    required this.name,
    required this.protocol,
    required this.primary,
    required this.fallback,
    required this.systemPrompt,
    required this.systemPromptSections,
    required this.enabled,
  });

  static const defaultProtocol = 'openai_compatible';
  static const defaultPrimaryModel = 'gpt-4o-mini';
  static const defaultPrimaryBaseUrl = 'https://api.openai.com/v1';

  final String name;
  final String protocol;
  final AgentEndpointFormInitialData primary;
  final AgentEndpointFormInitialData fallback;
  final String systemPrompt;
  final Map<String, String> systemPromptSections;
  final bool enabled;

  String promptSection(String key) => systemPromptSections[key] ?? '';

  factory AgentFormInitialData.resolve({
    AIAgentSummary? agent,
    required Map<String, dynamic> draft,
    required Map<String, dynamic> defaultProvider,
    AIAgentSummary? template,
  }) {
    if (agent != null) {
      return AgentFormInitialData.fromAgent(agent);
    }
    return AgentFormInitialData.fromDraft(
      draft: draft,
      defaultProvider: defaultProvider,
      template: template,
    );
  }

  factory AgentFormInitialData.fromAgent(AIAgentSummary agent) {
    final systemPrompt = agent.systemPrompt.trim();
    return AgentFormInitialData(
      name: agent.name.trim(),
      protocol: AgentFormUtils.firstNonEmpty([
        agent.protocol,
      ], fallback: defaultProtocol),
      primary: AgentEndpointFormInitialData(
        baseUrl: agent.primary.baseUrl.trim(),
        apiKey: '',
        model: AgentFormUtils.firstNonEmpty([
          agent.primary.model,
        ], fallback: defaultPrimaryModel),
      ),
      fallback: AgentEndpointFormInitialData(
        baseUrl: agent.fallback.baseUrl.trim(),
        apiKey: '',
        model: agent.fallback.model.trim(),
      ),
      systemPrompt: systemPrompt,
      systemPromptSections: AgentPromptSections.split(systemPrompt),
      enabled: agent.enabled,
    );
  }

  factory AgentFormInitialData.fromDraft({
    required Map<String, dynamic> draft,
    required Map<String, dynamic> defaultProvider,
    AIAgentSummary? template,
  }) {
    final defaultPrimary =
        (defaultProvider['primary'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final systemPrompt = AgentFormUtils.firstNonEmpty([
      _asText(draft['system_prompt']),
      template?.systemPrompt ?? '',
    ]);
    return AgentFormInitialData(
      name: _asText(draft['name']).trim(),
      protocol: AgentFormUtils.firstNonEmpty([
        _asText(draft['protocol']),
        _asText(defaultProvider['protocol']),
        template?.protocol ?? '',
      ], fallback: defaultProtocol),
      primary: AgentEndpointFormInitialData(
        baseUrl: AgentFormUtils.firstNonEmpty([
          _asText(draft['primary_base_url']),
          _asText(defaultPrimary['base_url']),
          template?.primary.baseUrl ?? '',
        ], fallback: defaultPrimaryBaseUrl),
        apiKey: AgentFormUtils.firstNonEmpty([
          _asText(draft['primary_api_key']),
          _asText(defaultPrimary['api_key']),
          template?.primary.apiKey ?? '',
        ]),
        model: AgentFormUtils.firstNonEmpty([
          _asText(draft['primary_model']),
          _asText(defaultPrimary['model']),
          template?.primary.model ?? '',
        ], fallback: defaultPrimaryModel),
      ),
      fallback: AgentEndpointFormInitialData(
        baseUrl: AgentFormUtils.firstNonEmpty([
          _asText(draft['fallback_base_url']),
          template?.fallback.baseUrl ?? '',
        ]),
        apiKey: AgentFormUtils.firstNonEmpty([
          _asText(draft['fallback_api_key']),
          template?.fallback.apiKey ?? '',
        ]),
        model: AgentFormUtils.firstNonEmpty([
          _asText(draft['fallback_model']),
          template?.fallback.model ?? '',
        ]),
      ),
      systemPrompt: systemPrompt,
      systemPromptSections: AgentPromptSections.split(systemPrompt),
      enabled: AgentFormUtils.asBool(
        draft['enabled'],
        fallback: template?.enabled ?? true,
      ),
    );
  }

  static String _asText(dynamic value) => (value ?? '').toString().trim();
}
