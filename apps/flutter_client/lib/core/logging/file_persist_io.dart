import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'file_persist_stub.dart';

class _IOPersist extends LogFilePersist {
  File? _file;
  String? _path;

  @override
  String? get path => _path;

  @override
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _path = '${logDir.path}/flutter_client.log';
    _file = File(_path!);
    if (!await _file!.exists()) {
      await _file!.create(recursive: true);
    }
  }

  @override
  Future<void> appendLine(String line) async {
    if (_file == null) {
      return;
    }
    await _file!.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }

  @override
  Future<String?> readAll() async {
    if (_file == null || !await _file!.exists()) {
      return null;
    }
    return _file!.readAsString();
  }

  @override
  Future<void> clear() async {
    if (_file == null) {
      return;
    }
    await _file!.writeAsString('', mode: FileMode.write, flush: true);
  }
}

LogFilePersist createLogFilePersist() => _IOPersist();
