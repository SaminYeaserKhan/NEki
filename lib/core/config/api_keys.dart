import 'package:shared_preferences/shared_preferences.dart';
import 'env.dart';

/// Centralized API and AI engine configuration for Neki.
/// Allows free-tier cloud integrations (such as Groq Whisper Large-v3)
/// with seamless local on-device fallbacks.
class ApiKeys {
  ApiKeys._();

  static const String _groqKeyPrefKey = 'neki_groq_api_key';

  /// In-memory or default developer key for testing.
  /// Free tier keys can be generated at https://console.groq.com (no credit card required).
  static String? _inMemoryGroqKey;

  /// Default public free-tier developmental key if configured.
  static const String defaultGroqApiKey = '';

  /// Sets or updates the Groq API key at runtime (persisted in SharedPreferences).
  static Future<void> setGroqApiKey(String apiKey) async {
    _inMemoryGroqKey = apiKey.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_inMemoryGroqKey!.isEmpty) {
      await prefs.remove(_groqKeyPrefKey);
    } else {
      await prefs.setString(_groqKeyPrefKey, _inMemoryGroqKey!);
    }
  }

  /// Retrieves the active Groq API key.
  static Future<String?> getGroqApiKey() async {
    if (_inMemoryGroqKey != null && _inMemoryGroqKey!.isNotEmpty) {
      return _inMemoryGroqKey;
    }
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_groqKeyPrefKey);
    if (savedKey != null && savedKey.isNotEmpty) {
      _inMemoryGroqKey = savedKey;
      return savedKey;
    }
    var envKey = Env.groqApiKey;
    if (envKey == null || envKey.isEmpty) {
      await Env.init();
      envKey = Env.groqApiKey;
    }
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }
    if (defaultGroqApiKey.isNotEmpty) {
      return defaultGroqApiKey;
    }
    return null;
  }

  /// Synchronously returns whether an in-memory, .env, or default Groq key is available.
  static bool hasGroqKey() {
    return (_inMemoryGroqKey != null && _inMemoryGroqKey!.isNotEmpty) ||
        (Env.groqApiKey != null && Env.groqApiKey!.isNotEmpty) ||
        defaultGroqApiKey.isNotEmpty;
  }

  static const String _promptBiasPrefKey = 'neki_groq_prompt_bias';
  static bool? _inMemoryPromptBias;

  /// Whether Whisper prompt conditioning is enabled.
  /// Defaults to false (strict acoustic mode to detect misarticulations like Qaf vs Kaf).
  static Future<bool> isPromptBiasEnabled() async {
    if (_inMemoryPromptBias != null) return _inMemoryPromptBias!;
    final prefs = await SharedPreferences.getInstance();
    _inMemoryPromptBias = prefs.getBool(_promptBiasPrefKey) ?? false;
    return _inMemoryPromptBias!;
  }

  /// Updates prompt bias setting.
  static Future<void> setPromptBiasEnabled(bool enabled) async {
    _inMemoryPromptBias = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptBiasPrefKey, enabled);
  }
}

