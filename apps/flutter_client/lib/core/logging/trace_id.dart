import 'package:uuid/uuid.dart';

final Uuid _uuid = const Uuid();

String newTraceId() => _uuid.v4();
