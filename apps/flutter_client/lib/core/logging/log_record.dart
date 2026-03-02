import 'log_level.dart';

class LogRecord {
  LogRecord({
    required this.ts,
    required this.level,
    required this.module,
    required this.event,
    required this.message,
    required this.traceId,
    this.data,
    this.error,
    this.stack,
  });

  final DateTime ts;
  final AppLogLevel level;
  final String module;
  final String event;
  final String message;
  final String traceId;
  final Map<String, dynamic>? data;
  final String? error;
  final String? stack;

  Map<String, dynamic> toJson() {
    return {
      'ts': ts.toIso8601String(),
      'level': level.label,
      'module': module,
      'event': event,
      'message': message,
      'trace_id': traceId,
      'data': data,
      'error': error,
      'stack': stack,
    };
  }

  factory LogRecord.fromJson(Map<String, dynamic> json) {
    final levelRaw = json['level']?.toString().toUpperCase() ?? 'INFO';
    final level = AppLogLevel.values.firstWhere(
      (e) => e.label == levelRaw,
      orElse: () => AppLogLevel.info,
    );
    return LogRecord(
      ts: DateTime.tryParse(json['ts']?.toString() ?? '') ?? DateTime.now(),
      level: level,
      module: json['module']?.toString() ?? 'unknown',
      event: json['event']?.toString() ?? 'unknown',
      message: json['message']?.toString() ?? '',
      traceId: json['trace_id']?.toString() ?? '',
      data: (json['data'] as Map?)?.cast<String, dynamic>(),
      error: json['error']?.toString(),
      stack: json['stack']?.toString(),
    );
  }
}
