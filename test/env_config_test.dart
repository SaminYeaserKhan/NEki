import 'package:flutter_test/flutter_test.dart';
import 'package:neki/core/config/api_keys.dart';
import 'package:neki/core/config/env.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Env & ApiKeys Configuration Tests', () {
    test('Env loads and parses .env file or environment variables', () async {
      await Env.init();

      // Check generic lookup does not crash
      final nonExistent = Env.get('NON_EXISTENT_KEY_12345');
      expect(nonExistent, isNull);
    });

    test('ApiKeys prioritizes user-defined in-memory and shared_prefs key', () async {
      // 1. Initially without custom key
      await ApiKeys.setGroqApiKey('');
      
      // 2. Setting key via runtime API (e.g. from in-app settings dialog)
      await ApiKeys.setGroqApiKey('gsk_test_mock_key_abc123');
      expect(await ApiKeys.getGroqApiKey(), equals('gsk_test_mock_key_abc123'));
      expect(ApiKeys.hasGroqKey(), isTrue);

      // 3. Resetting/clearing runtime key
      await ApiKeys.setGroqApiKey('');
      final activeKey = await ApiKeys.getGroqApiKey();
      // If .env has GROQ_API_KEY, it falls back to that; otherwise null
      expect(activeKey == null || activeKey == Env.groqApiKey, isTrue);
    });

    test('Env successfully loads GROQ_API_KEY from .env', () async {
      await Env.init(force: true);
      expect(Env.groqApiKey, isNotNull);
      expect(Env.groqApiKey!.startsWith('gsk_'), isTrue);
      expect(await ApiKeys.getGroqApiKey(), equals(Env.groqApiKey));
      expect(ApiKeys.hasGroqKey(), isTrue);
    });
  });
}
