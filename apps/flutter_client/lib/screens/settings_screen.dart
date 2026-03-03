import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'debug_log_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _modelController = TextEditingController();
  final _modelFocusNode = FocusNode();
  final _openAIBaseURLController = TextEditingController();
  final _openAIBaseURLFocusNode = FocusNode();
  final _apiKeyController = TextEditingController();
  String _selectedProvider = 'mock';
  bool _providerDirty = false;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _modelController.dispose();
    _modelFocusNode.dispose();
    _openAIBaseURLController.dispose();
    _openAIBaseURLFocusNode.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings_outlined), text: 'AI设置'),
            Tab(icon: Icon(Icons.bug_report), text: '调试日志'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<AppProvider>().fetchAIProviderStatus(force: true),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _aiSettingsBody(context),
          const DebugLogScreen(embedded: true),
        ],
      ),
    );
  }

  Widget _aiSettingsBody(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final status = provider.aiProviderStatus;
    _syncProviderConfig(status);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section(
          title: '模型服务状态',
          icon: Icons.cloud_done_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statusRow('当前生效服务商', status['provider']),
              _statusRow('已配置服务商', status['configured_provider']),
              _statusRow('当前生效模型', status['model']),
              _statusRow('已配置模型', status['configured_model']),
              _statusRow('可用', '${status['ready'] ?? false}'),
              _statusRow('降级到Mock', '${status['fallback'] ?? false}'),
              _statusRow(
                '密钥状态',
                (status['has_api_key'] ?? false) ? '已配置' : '未配置',
              ),
              _statusRow('OpenAI Base URL', status['openai_base_url']),
            ],
          ),
        ),
        _section(
          title: '模型连接配置',
          icon: Icons.tune,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedProvider,
                decoration: const InputDecoration(
                  labelText: '供应商',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'mock', child: Text('mock')),
                  DropdownMenuItem(value: 'openai', child: Text('openai')),
                  DropdownMenuItem(value: 'gemini', child: Text('gemini')),
                  DropdownMenuItem(value: 'claude', child: Text('claude')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedProvider = value;
                    _providerDirty = true;
                  });
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  focusNode: _modelFocusNode,
                  controller: _modelController,
                  decoration: InputDecoration(
                    labelText: '模型名称（自动获取/手动填写）',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      tooltip: '自动获取当前模型',
                      onPressed: () => _autoFetchModel(context, provider),
                      icon: const Icon(Icons.download_outlined),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _autoFetchModel(context, provider),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('自动获取当前模型'),
                ),
              ),
              _input(
                _openAIBaseURLController,
                'OpenAI 兼容 Base URL（可选）',
                focusNode: _openAIBaseURLFocusNode,
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '提示：Base URL 在 provider=openai 时生效。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _apiKeyController,
                  obscureText: !_showApiKey,
                  decoration: InputDecoration(
                    labelText: 'API Token（可选，输入则覆盖当前）',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showApiKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _showApiKey = !_showApiKey),
                    ),
                  ),
                ),
              ),
              const Text(
                '提示：token 不会在状态接口中回显。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _saveProviderConfig(context, provider),
                icon: const Icon(Icons.save),
                label: const Text('保存配置'),
              ),
            ],
          ),
        ),
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '错误：${provider.errorMessage}',
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _statusRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              '${value ?? '-'}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    FocusNode? focusNode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        focusNode: focusNode,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _saveProviderConfig(
    BuildContext context,
    AppProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final token = _apiKeyController.text.trim();
    final model = _modelController.text.trim();
    final baseURL = _openAIBaseURLController.text.trim();
    try {
      await provider.updateAIProviderConfig(
        provider: _selectedProvider,
        apiKey: token.isEmpty ? null : token,
        model: model.isEmpty ? null : model,
        openAIBaseURL: _selectedProvider == 'openai'
            ? (baseURL.isEmpty ? null : baseURL)
            : null,
      );
      _providerDirty = false;
      _apiKeyController.clear();
      if (!mounted) return;
      final updated = provider.aiProviderStatus;
      final activeProvider = (updated['provider'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final configuredProvider = (updated['configured_provider'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final fallback = updated['fallback'] == true;
      if (configuredProvider.isNotEmpty &&
          activeProvider.isNotEmpty &&
          configuredProvider != activeProvider) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '配置已保存（$configuredProvider），但当前生效是 $activeProvider；请检查 API Key/模型是否可用',
            ),
          ),
        );
      } else if (fallback) {
        messenger.showSnackBar(
          const SnackBar(content: Text('配置已保存，但当前处于 fallback 模式')),
        );
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('模型配置已更新')));
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? '更新失败')),
      );
    }
  }

  Future<void> _autoFetchModel(
    BuildContext context,
    AppProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await provider.fetchAIProviderStatus(force: true);
    if (!mounted) return;
    if (provider.errorMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(provider.errorMessage!)));
      return;
    }
    final status = provider.aiProviderStatus;
    final configuredProvider = (status['configured_provider'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final activeProvider = (status['provider'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final configuredModel = (status['configured_model'] ?? '')
        .toString()
        .trim();
    final activeModel = (status['model'] ?? '').toString().trim();
    final model = configuredModel.isNotEmpty ? configuredModel : activeModel;
    if (model.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('未获取到模型名称，请手动填写')));
      return;
    }
    if (model == 'mock-v1' &&
        configuredProvider.isNotEmpty &&
        configuredProvider != 'mock') {
      messenger.showSnackBar(
        const SnackBar(content: Text('当前处于 mock 回退，无法自动获取目标供应商模型，请手动填写')),
      );
      return;
    }
    _modelController.text = model;
    if (configuredProvider.isNotEmpty &&
        activeProvider.isNotEmpty &&
        configuredProvider != activeProvider) {
      messenger.showSnackBar(
        SnackBar(content: Text('已读取已配置模型：$model（当前生效供应商：$activeProvider）')),
      );
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text('已自动获取模型：$model')));
  }

  void _syncProviderConfig(Map<String, dynamic> status) {
    final configuredProvider =
        (status['configured_provider'] ?? status['provider'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (configuredProvider.isNotEmpty &&
        configuredProvider != _selectedProvider &&
        !_providerDirty &&
        (configuredProvider == 'mock' ||
            configuredProvider == 'openai' ||
            configuredProvider == 'gemini' ||
            configuredProvider == 'claude')) {
      _selectedProvider = configuredProvider;
    }
    if (!_modelFocusNode.hasFocus) {
      final model = (status['configured_model'] ?? status['model'] ?? '')
          .toString()
          .trim();
      if (model.isNotEmpty && _modelController.text.trim().isEmpty) {
        _modelController.text = model;
      }
    }
    if (_openAIBaseURLFocusNode.hasFocus) return;
    final baseURL = (status['openai_base_url'] ?? '').toString().trim();
    if (baseURL.isEmpty || _openAIBaseURLController.text.trim() == baseURL) {
      return;
    }
    _openAIBaseURLController.text = baseURL;
  }
}
