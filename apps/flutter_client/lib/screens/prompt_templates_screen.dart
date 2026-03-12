import 'package:flutter/material.dart';
import '../models/prompt_template.dart';
import '../services/api_service.dart';

class PromptTemplatesScreen extends StatefulWidget {
  const PromptTemplatesScreen({super.key});

  @override
  State<PromptTemplatesScreen> createState() => _PromptTemplatesScreenState();
}

class _PromptTemplatesScreenState extends State<PromptTemplatesScreen> {
  List<PromptTemplate> _templates = [];
  List<PromptTemplate> _filtered = [];
  bool _loading = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    try {
      final api = ApiService();
      final templates = await api.listPromptTemplates();
      setState(() {
        _templates = templates;
        _filtered = templates;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _filterTemplates(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _templates
          : _templates.where((t) =>
              t.name.toLowerCase().contains(query.toLowerCase()) ||
              t.key.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  Future<void> _reload() async {
    try {
      final api = ApiService();
      await api.reloadPromptTemplates();
      await _loadTemplates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模板已重新加载')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重新加载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('提示词模板'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: '重新加载',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: '搜索模板',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterTemplates,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('暂无模板'))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final template = _filtered[index];
                          return ListTile(
                            title: Text(template.name),
                            subtitle: Text(template.key),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showDetail(template),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showDetail(PromptTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TemplateDetailScreen(template: template),
      ),
    );
  }
}

class _TemplateDetailScreen extends StatefulWidget {
  const _TemplateDetailScreen({required this.template});

  final PromptTemplate template;

  @override
  State<_TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends State<_TemplateDetailScreen> {
  late TextEditingController _contentController;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.template.content);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ApiService();
      await api.updatePromptTemplate(
        widget.template.key,
        {'content': _contentController.text},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        setState(() => _editing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.name),
        actions: [
          if (_editing)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              onPressed: _saving ? null : _save,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Key: ${widget.template.key}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          if (widget.template.variables.isNotEmpty) ...[
            const Text('变量:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: widget.template.variables.map((v) => Chip(label: Text(v))).toList(),
            ),
            const SizedBox(height: 16),
          ],
          const Text('内容:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_editing)
            TextField(
              controller: _contentController,
              maxLines: 20,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入模板内容...',
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                widget.template.content,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
    );
  }
}
