import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lightweight environment configuration manager for Neki.
/// Seamlessly loads keys from:
/// 1. `.env` file (parsed at runtime in development, desktop, and tests)
/// 2. Compile-time `--dart-define-from-file=.env` or `--dart-define=KEY=VAL`
/// 3. System `Platform.environment`
class Env {
  Env._();

  static final Map<String, String> _values = {};
  static bool _initialized = false;

  /// Initializes the environment configuration.
  /// Safe to call multiple times or during app startup.
  static Future<void> init({bool force = false}) async {
    if (_initialized && !force && _values.isNotEmpty) return;
    _initialized = true;

    // 1. Try reading local .env file on non-web platforms
    if (!kIsWeb) {
      try {
        final candidates = [
          '.env',
          '/Users/test/neki/.env',
        ];
        for (final path in candidates) {
          final file = File(path);
          if (await file.exists()) {
            final content = await file.readAsString();
            _parse(content);
            if (_values.isNotEmpty) break;
          }
        }
      } catch (_) {}
    }

    // 2. Try reading from asset bundle if bundled as an asset
    try {
      final content = await rootBundle.loadString('.env');
      _parse(content);
    } catch (_) {}
  }

  /// Parses a .env format string into key-value pairs.
  static void _parse(String content) {
    final lines = const LineSplitter().convert(content);
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eqIndex = line.indexOf('=');
      if (eqIndex > 0) {
        final key = line.substring(0, eqIndex).trim();
        var val = line.substring(eqIndex + 1).trim();
        // Remove enclosing quotes
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }
        if (key.isNotEmpty && !_values.containsKey(key)) {
          _values[key] = val;
        }
      }
    }
  }

  /// Dynamically retrieves an environment variable.
  static String? get(String key) {
    if (_values.containsKey(key) && _values[key]!.isNotEmpty) {
      return _values[key];
    }
    if (!kIsWeb) {
      try {
        final pVal = Platform.environment[key];
        if (pVal != null && pVal.isNotEmpty) return pVal;
      } catch (_) {}
    }
    return null;
  }

  /// Groq API key getter
  static String? get groqApiKey {
    const compileTimeKey = String.fromEnvironment('GROQ_API_KEY');
    if (compileTimeKey.isNotEmpty) return compileTimeKey;
    return get('GROQ_API_KEY');
  }

  /// Supabase URL getter
  static String? get supabaseUrl {
    const compileTimeUrl = String.fromEnvironment('SUPABASE_URL');
    if (compileTimeUrl.isNotEmpty) return compileTimeUrl;
    return get('SUPABASE_URL');
  }

  /// Supabase Anon Key getter
  static String? get supabaseAnonKey {
    const compileTimeKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (compileTimeKey.isNotEmpty) return compileTimeKey;
    return get('SUPABASE_ANON_KEY');
  }
}
