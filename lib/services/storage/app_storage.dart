abstract class AppStorage {
  Future<void> init();
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<Map<String, dynamic>?> getJson(String key);
  Future<void> setJson(String key, Map<String, dynamic> value);
  Future<bool> getBool(String key, {bool defaultValue = false});
  Future<void> setBool(String key, bool value);
  Future<int?> getInt(String key);
  Future<void> setInt(String key, int value);
  Future<void> remove(String key);
  Future<void> clear();
}
