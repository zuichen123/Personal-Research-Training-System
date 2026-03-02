import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/logging/app_logger.dart';
import '../core/logging/log_level.dart';
import '../core/logging/log_record.dart';

class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  final logger = AppLogger.instance;
  final searchController = TextEditingController();
  AppLogLevel selectedLevel = AppLogLevel.debug;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: logger,
      builder: (context, _) {
        final records = _filtered(logger.records);
        return Scaffold(
          appBar: AppBar(
            title: const Text('调试日志'),
            actions: [
              IconButton(icon: const Icon(Icons.copy_all), onPressed: _copyAll),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _exportFile,
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: _clearLogs,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              labelText: '搜索日志',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<AppLogLevel>(
                          value: selectedLevel,
                          items: AppLogLevel.values
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedLevel = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '共 ${logger.records.length} 条，筛选后 ${records.length} 条\n日志文件：${logger.logFilePath ?? "不可用"}',
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: records.isEmpty
                    ? const Center(child: Text('暂无日志'))
                    : ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final item = records[index];
                          return ListTile(
                            dense: true,
                            leading: Text(item.level.label),
                            title: Text('${item.module}:${item.event}'),
                            subtitle: Text(
                              '${item.ts.toIso8601String()}\n${item.message}\ntrace=${item.traceId}',
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<LogRecord> _filtered(List<LogRecord> records) {
    final keyword = searchController.text.trim().toLowerCase();
    return records
        .where((record) {
          if (record.level.weight < selectedLevel.weight) {
            return false;
          }
          if (keyword.isEmpty) {
            return true;
          }
          final text = jsonEncode(record.toJson()).toLowerCase();
          return text.contains(keyword);
        })
        .toList(growable: false)
        .reversed
        .toList();
  }

  Future<void> _copyAll() async {
    final content = await logger.exportText();
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日志已复制到剪贴板')));
    }
  }

  Future<void> _exportFile() async {
    final content = await logger.exportText();
    await FileSaver.instance.saveFile(
      name: 'self_study_debug_logs',
      bytes: Uint8List.fromList(utf8.encode(content)),
      ext: 'log',
      mimeType: MimeType.text,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日志导出成功')));
    }
  }

  Future<void> _clearLogs() async {
    await logger.clear();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日志已清空')));
    }
  }
}
