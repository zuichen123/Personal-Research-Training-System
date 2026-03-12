import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_persist_base.dart';
import 'file_persist_factory_stub.dart'
    if (dart.library.io) 'file_persist_factory_io.dart';
import 'log_level.dart';
import 'log_record.dart';
import 'trace_id.dart';

class AppLogger extends ChangeNotifier {
  AppLogger._();

  static final AppLogger instance = AppLogger._();
  static const String _prefsKey = 'debug_logs_v1';
  static const int _maxInMemory = 2000;
  static const int _maxPersisted = 600;

  final List<LogRecord> _records = <LogRecord>[];
  final LogFilePersist _filePersist = createLogFilePersist();
  SharedPreferences? _prefs;
  bool _initialized = false;
  AppLogLevel _minLevel = kReleaseMode ? AppLogLevel.warn : AppLogLevel.info;

  List<LogRecord> get records => List<LogRecord>.unmodifiable(_records);
  AppLogLevel get minLevel => _minLevel;
  String? get logFilePath => _filePersist.path;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    await _filePersist.init();
    final raw = _prefs?.getStringList(_prefsKey) ?? <String>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        _records.add(LogRecord.fromJson(decoded));
      } catch (_) {
        // ignore malformed historical entries
      }
    }
    _initialized = true;
    if (!kReleaseMode) {
      info(
        module: 'app',
        event: 'logger.init',
        message: '日志系统已初始化',
        data: {
          'loaded_records': _records.length,
          'file_path': _filePersist.path,
        },
      );
    }
  }

  void setMinLevel(AppLogLevel level) {
    _minLevel = level;
    notifyListeners();
  }

  String debug({
    required String module,
    required String event,
    required String message,
    Map<String, dynamic>? data,
  }) {
    return _write(
      level: AppLogLevel.debug,
      module: module,
      event: event,
      message: message,
      data: data,
    );
  }

  String info({
    required String module,
    required String event,
    required String message,
    Map<String, dynamic>? data,
  }) {
    return _write(
      level: AppLogLevel.info,
      module: module,
      event: event,
      message: message,
      data: data,
    );
  }

  String warn({
    required String module,
    required String event,
    required String message,
    Map<String, dynamic>? data,
    String? error,
  }) {
    return _write(
      level: AppLogLevel.warn,
      module: module,
      event: event,
      message: message,
      data: data,
      error: error,
    );
  }

  String error({
    required String module,
    required String event,
    required String message,
    Map<String, dynamic>? data,
    String? error,
    String? stack,
  }) {
    return _write(
      level: AppLogLevel.error,
      module: module,
      event: event,
      message: message,
      data: data,
      error: error,
      stack: stack,
    );
  }

  Future<void> clear() async {
    _records.clear();
    await _prefs?.remove(_prefsKey);
    await _filePersist.clear();
    notifyListeners();
  }

  Future<String> exportText() async {
    final sb = StringBuffer();
    for (final record in _records) {
      sb.writeln(jsonEncode(record.toJson()));
    }
    final fileData = await _filePersist.readAll();
    if (fileData != null && fileData.trim().isNotEmpty) {
      sb.writeln();
      sb.writeln('--- file sink ---');
      sb.writeln(fileData);
    }
    return sb.toString();
  }

  String _write({
    required AppLogLevel level,
    required String module,
    required String event,
    required String message,
    Map<String, dynamic>? data,
    String? error,
    String? stack,
    String? traceId,
  }) {
    final id = traceId ?? newTraceId();
    // In release, default to warn+ only (and allow raising/lowering via settings).
    // Dropping low-level logs avoids excessive JSON encoding + persistence overhead
    // that can cause jank on Android.
    if (level.weight < _minLevel.weight) {
      return id;
    }
    final record = LogRecord(
      ts: DateTime.now(),
      level: level,
      module: module,
      event: event,
      message: message,
      traceId: id,
      data: data,
      error: error,
      stack: stack,
    );
    _records.add(record);
    if (_records.length > _maxInMemory) {
      _records.removeAt(0);
    }
    final encoded = jsonEncode(record.toJson());
    if (!kReleaseMode) {
      debugPrint(encoded);
    }
    _filePersist.appendLine(encoded);
    _persist();
    notifyListeners();
    return id;
  }

  void _persist() {
    final start = _records.length > _maxPersisted
        ? _records.length - _maxPersisted
        : 0;
    final toStore = _records
        .sublist(start)
        .map((e) => jsonEncode(e.toJson()))
        .toList(growable: false);
    _prefs?.setStringList(_prefsKey, toStore);
  }
}
