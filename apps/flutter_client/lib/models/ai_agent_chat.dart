class AIAgentConfig {
  AIAgentConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  factory AIAgentConfig.fromJson(Map<String, dynamic> json) {
    return AIAgentConfig(
      baseUrl: json['base_url']?.toString() ?? '',
      apiKey: json['api_key']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'base_url': baseUrl,
    'api_key': apiKey,
    'model': model,
  };
}

class AIAgentSummary {
  AIAgentSummary({
    required this.id,
    required this.name,
    required this.protocol,
    required this.primary,
    required this.fallback,
    required this.systemPrompt,
    required this.intentCapabilities,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String protocol;
  final AIAgentConfig primary;
  final AIAgentConfig fallback;
  final String systemPrompt;
  final List<String> intentCapabilities;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AIAgentSummary.fromJson(Map<String, dynamic> json) {
    return AIAgentSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      protocol: json['protocol']?.toString() ?? 'openai_compatible',
      primary: AIAgentConfig.fromJson(
        (json['primary'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      fallback: AIAgentConfig.fromJson(
        (json['fallback'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      systemPrompt: json['system_prompt']?.toString() ?? '',
      intentCapabilities:
          ((json['intent_capabilities'] as List?) ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList(growable: false),
      enabled: json['enabled'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AIAgentSession {
  AIAgentSession({
    required this.id,
    required this.agentId,
    required this.title,
    required this.lastMessageAt,
    required this.summaryUpdatedAt,
    required this.summaryMessageCount,
    required this.contextSummaryMeta,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
  });

  final String id;
  final String agentId;
  final String title;
  final DateTime? lastMessageAt;
  final DateTime? summaryUpdatedAt;
  final int summaryMessageCount;
  final Map<String, dynamic> contextSummaryMeta;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  factory AIAgentSession.fromJson(Map<String, dynamic> json) {
    return AIAgentSession(
      id: json['id']?.toString() ?? '',
      agentId: json['agent_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      lastMessageAt: DateTime.tryParse(
        json['last_message_at']?.toString() ?? '',
      ),
      summaryUpdatedAt: DateTime.tryParse(
        json['summary_updated_at']?.toString() ?? '',
      ),
      summaryMessageCount:
          (json['summary_message_count'] as num?)?.toInt() ?? 0,
      contextSummaryMeta:
          (json['context_summary_meta'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      archivedAt: DateTime.tryParse(json['archived_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'agent_id': agentId,
    'title': title,
    'last_message_at': lastMessageAt?.toIso8601String(),
    'summary_updated_at': summaryUpdatedAt?.toIso8601String(),
    'summary_message_count': summaryMessageCount,
    'context_summary_meta': contextSummaryMeta,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'archived_at': archivedAt?.toIso8601String(),
  };
}

class AIAgentIntent {
  AIAgentIntent({
    required this.action,
    required this.confidence,
    required this.reason,
    required this.params,
  });

  final String action;
  final double confidence;
  final String reason;
  final Map<String, dynamic> params;

  factory AIAgentIntent.fromJson(Map<String, dynamic> json) {
    return AIAgentIntent(
      action: json['action']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      reason: json['reason']?.toString() ?? '',
      params:
          (json['params'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
    );
  }
}

class AIAgentPendingConfirmation {
  AIAgentPendingConfirmation({
    required this.action,
    required this.prompt,
    required this.params,
    required this.createdAt,
  });

  final String action;
  final String prompt;
  final Map<String, dynamic> params;
  final DateTime? createdAt;

  factory AIAgentPendingConfirmation.fromJson(Map<String, dynamic> json) {
    return AIAgentPendingConfirmation(
      action: json['action']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      params:
          (json['params'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class AIAgentMessage {
  AIAgentMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.intent,
    required this.pendingConfirmation,
    required this.providerUsed,
    required this.modelUsed,
    required this.fallbackUsed,
    required this.latencyMs,
    required this.artifactId,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String role;
  final String content;
  final AIAgentIntent? intent;
  final AIAgentPendingConfirmation? pendingConfirmation;
  final String providerUsed;
  final String modelUsed;
  final bool fallbackUsed;
  final int latencyMs;
  final String artifactId;
  final DateTime createdAt;

  factory AIAgentMessage.fromJson(Map<String, dynamic> json) {
    return AIAgentMessage(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      intent: json['intent'] is Map
          ? AIAgentIntent.fromJson(
              (json['intent'] as Map).cast<String, dynamic>(),
            )
          : null,
      pendingConfirmation: json['pending_confirmation'] is Map
          ? AIAgentPendingConfirmation.fromJson(
              (json['pending_confirmation'] as Map).cast<String, dynamic>(),
            )
          : null,
      providerUsed: json['provider_used']?.toString() ?? '',
      modelUsed: json['model_used']?.toString() ?? '',
      fallbackUsed: json['fallback_used'] == true,
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
      artifactId: json['artifact_id']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AIAgentArtifact {
  AIAgentArtifact({
    required this.id,
    required this.sessionId,
    required this.messageId,
    required this.type,
    required this.payload,
    required this.importStatus,
    required this.createdAt,
    required this.importedAt,
  });

  final String id;
  final String sessionId;
  final String messageId;
  final String type;
  final Map<String, dynamic> payload;
  final String importStatus;
  final DateTime createdAt;
  final DateTime? importedAt;

  factory AIAgentArtifact.fromJson(Map<String, dynamic> json) {
    return AIAgentArtifact(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      messageId: json['message_id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      payload:
          (json['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      importStatus: json['import_status']?.toString() ?? 'pending',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      importedAt: DateTime.tryParse(json['imported_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'message_id': messageId,
    'type': type,
    'payload': payload,
    'import_status': importStatus,
    'created_at': createdAt.toIso8601String(),
    'imported_at': importedAt?.toIso8601String(),
  };
}

class AISendMessageResult {
  AISendMessageResult({
    required this.assistantMessage,
    required this.intent,
    required this.pendingConfirmation,
    required this.artifact,
  });

  final AIAgentMessage assistantMessage;
  final AIAgentIntent intent;
  final AIAgentPendingConfirmation? pendingConfirmation;
  final AIAgentArtifact? artifact;

  factory AISendMessageResult.fromJson(Map<String, dynamic> json) {
    return AISendMessageResult(
      assistantMessage: AIAgentMessage.fromJson(
        (json['assistant_message'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      intent: AIAgentIntent.fromJson(
        (json['intent'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      pendingConfirmation: json['pending_confirmation'] is Map
          ? AIAgentPendingConfirmation.fromJson(
              (json['pending_confirmation'] as Map).cast<String, dynamic>(),
            )
          : null,
      artifact: json['artifact'] is Map
          ? AIAgentArtifact.fromJson(
              (json['artifact'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}
