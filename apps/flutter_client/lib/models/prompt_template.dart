class PromptTemplate {
  PromptTemplate({
    required this.key,
    required this.name,
    required this.content,
    required this.variables,
    this.presetPrompt = '',
    this.presetOutputFormatPrompt = '',
    this.customPrompt = '',
    this.outputFormatPrompt = '',
    this.effectivePrompt = '',
    this.effectiveOutputFormatPrompt = '',
    this.segmentOverrides = const {},
  });

  final String key;
  final String name;
  final String content;
  final List<String> variables;
  final String presetPrompt;
  final String presetOutputFormatPrompt;
  final String customPrompt;
  final String outputFormatPrompt;
  final String effectivePrompt;
  final String effectiveOutputFormatPrompt;
  final Map<String, String> segmentOverrides;

  factory PromptTemplate.fromJson(Map<String, dynamic> json) {
    final segmentOverridesRaw = json['segment_overrides'];
    final segmentOverrides = <String, String>{};
    if (segmentOverridesRaw is Map) {
      segmentOverridesRaw.forEach((key, value) {
        segmentOverrides[key.toString()] = value?.toString() ?? '';
      });
    }

    return PromptTemplate(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      variables: ((json['variables'] as List?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      presetPrompt: json['preset_prompt']?.toString() ?? '',
      presetOutputFormatPrompt: json['preset_output_format_prompt']?.toString() ?? '',
      customPrompt: json['custom_prompt']?.toString() ?? '',
      outputFormatPrompt: json['output_format_prompt']?.toString() ?? '',
      effectivePrompt: json['effective_prompt']?.toString() ?? '',
      effectiveOutputFormatPrompt: json['effective_output_format_prompt']?.toString() ?? '',
      segmentOverrides: segmentOverrides,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'content': content,
    'variables': variables,
    'preset_prompt': presetPrompt,
    'preset_output_format_prompt': presetOutputFormatPrompt,
    'custom_prompt': customPrompt,
    'output_format_prompt': outputFormatPrompt,
    'effective_prompt': effectivePrompt,
    'effective_output_format_prompt': effectiveOutputFormatPrompt,
    'segment_overrides': segmentOverrides,
  };
}
