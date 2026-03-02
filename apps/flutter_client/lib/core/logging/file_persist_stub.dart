abstract class LogFilePersist {
  String? get path;

  Future<void> init() async {}

  Future<void> appendLine(String line) async {}

  Future<String?> readAll() async => null;

  Future<void> clear() async {}
}

class _NoopPersist extends LogFilePersist {
  @override
  String? get path => null;
}

LogFilePersist createLogFilePersist() => _NoopPersist();
