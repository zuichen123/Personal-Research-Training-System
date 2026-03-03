import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/resource.dart';
import '../providers/app_provider.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final resources = provider.resources;
    final loading = provider.isSectionLoading(DataSection.resources);

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习资料'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchResources(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchResources(force: true),
        child: _buildBody(provider, resources, loading, context),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _uploadResource(context),
        icon: const Icon(Icons.upload_file),
        label: const Text('上传'),
      ),
    );
  }

  Widget _buildBody(
    AppProvider provider,
    List<ResourceMaterial> resources,
    bool loading,
    BuildContext context,
  ) {
    if (loading && resources.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && resources.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Center(child: Text('加载失败：${provider.errorMessage}')),
        ],
      );
    }

    if (resources.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 64),
          Center(
            child: Column(
              children: [
                Icon(Icons.folder_open,
                    size: 64,
                    color: Colors.blueGrey.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                const Text('暂无上传资料',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('点击右下角按钮上传你的第一份资料',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: resources.length,
      itemBuilder: (context, index) {
        final r = resources[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const Icon(
              Icons.insert_drive_file,
              color: Colors.blueGrey,
            ),
            title: Text(
              r.filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('分类:${r.category}  大小:${r.sizeBytes} bytes'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'download') {
                  await _download(context, r.id);
                } else if (value == 'delete') {
                  await context.read<AppProvider>().deleteResource(r.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'download', child: Text('下载')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadResource(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final picked = await FilePicker.platform.pickFiles(withData: false);
    if (!context.mounted) {
      return;
    }
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.single.path == null) {
      return;
    }
    final filePath = picked.files.single.path!;
    final categoryController = TextEditingController(text: 'general');
    final tagsController = TextEditingController(text: '学习');
    final questionIdController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('上传资料'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(filePath, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              _input(categoryController, '分类'),
              _input(tagsController, '标签(逗号分隔)'),
              _input(questionIdController, '关联题目ID(可选)'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await provider.uploadResource(
                    filePath: filePath,
                    category: categoryController.text.trim(),
                    tags: tagsController.text.trim(),
                    questionId: questionIdController.text.trim(),
                  );
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text('上传失败：$e')));
                  }
                }
              },
              child: const Text('上传'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _download(BuildContext context, String id) async {
    try {
      final provider = context.read<AppProvider>();
      final file = await provider.downloadResource(id);
      await FileSaver.instance.saveFile(
        name: file.filename.split('.').first,
        fileExtension: file.filename.contains('.')
            ? file.filename.split('.').last
            : 'bin',
        bytes: Uint8List.fromList(file.bytes),
        mimeType: MimeType.other,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('下载成功')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下载失败：$e')));
      }
    }
  }

  Widget _input(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
