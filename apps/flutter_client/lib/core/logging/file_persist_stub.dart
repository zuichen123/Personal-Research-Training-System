import 'file_persist_base.dart';

class NoopLogFilePersist extends LogFilePersist {
  @override
  String? get path => null;
}
