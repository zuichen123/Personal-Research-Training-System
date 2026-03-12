import 'package:flutter_test/flutter_test.dart';
import 'package:prts_client/utils/agent_form_utils.dart';

void main() {
  group('AgentFormUtils', () {
    test('loadDefaultProvider returns loader result', () async {
      final result = await AgentFormUtils.loadDefaultProvider(
        () async => <String, dynamic>{'protocol': 'mock'},
      );

      expect(result['protocol'], 'mock');
    });

    test('loadDefaultProvider falls back to empty map on error', () async {
      final result = await AgentFormUtils.loadDefaultProvider(() async {
        throw StateError('boom');
      });

      expect(result, isEmpty);
    });
  });
}
