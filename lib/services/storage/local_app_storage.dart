import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_storage.dart';

/// Browser-compatible and cross-platform local persistence implementation of [AppStorage]
/// backed by [SharedPreferences] (window.localStorage on Flutter Web) with seamless
/// in-memory fallback for isolated environments and tests.
class LocalAppStorage implements AppStorage {
  SharedPreferences? _prefs;
  final Map<String, dynamic> _memoryFallback = {};
  bool _initialized = false;

  LocalAppStorage([this._prefs]) {
    if (_prefs != null) {
      _initialized = true;
    }
  }

  bool get isInitialized => _initialized;

  Future<SharedPreferences?> _getPrefs() async {
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      return _prefs;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> init() async {
    await _getPrefs();
    _initialized = true;
  }

  @override
  Future<String?> getString(String key) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      return prefs.getString(key);
    }
    final value = _memoryFallback[key];
    if (value is String) return value;
    return null;
  }

  @override
  Future<void> setString(String key, String value) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      await prefs.setString(key, value);
    } else {
      _memoryFallback[key] = value;
    }
  }

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final prefs = await _getPrefs();
    final raw = prefs != null ? prefs.getString(key) : _memoryFallback[key];
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    final encoded = jsonEncode(value);
    final prefs = await _getPrefs();
    if (prefs != null) {
      await prefs.setString(key, encoded);
    } else {
      _memoryFallback[key] = encoded;
    }
  }

  @override
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      return prefs.getBool(key) ?? defaultValue;
    }
    final value = _memoryFallback[key];
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return defaultValue;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      await prefs.setBool(key, value);
    } else {
      _memoryFallback[key] = value;
    }
  }

  @override
  Future<int?> getInt(String key) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      return prefs.getInt(key);
    }
    final value = _memoryFallback[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  Future<void> setInt(String key, int value) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      await prefs.setInt(key, value);
    } else {
      _memoryFallback[key] = value;
    }
  }

  @override
  Future<void> remove(String key) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      await prefs.remove(key);
    }
    _memoryFallback.remove(key);
  }

  @override
  Future<void> clear() async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      await prefs.clear();
    }
    _memoryFallback.clear();
  }
}
