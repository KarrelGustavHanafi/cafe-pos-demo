import 'dart:async';
import '../../models/business_config.dart';
import '../storage/app_storage.dart';

abstract class BusinessConfigService {
  BusinessConfig get config;
  Stream<BusinessConfig> get configStream;
  Future<void> init();
  Future<void> saveConfig(BusinessConfig newConfig);
  Future<void> resetToDefaults();
}

class LocalBusinessConfigService implements BusinessConfigService {
  final AppStorage _storage;
  static const String _storageKey = 'caffe_business_config';

  BusinessConfig _currentConfig = BusinessConfig.defaultCaffeDemo();
  final _controller = StreamController<BusinessConfig>.broadcast();

  LocalBusinessConfigService(this._storage);

  @override
  BusinessConfig get config => _currentConfig;

  @override
  Stream<BusinessConfig> get configStream => _controller.stream;

  @override
  Future<void> init() async {
    final storedJson = await _storage.getJson(_storageKey);
    if (storedJson != null) {
      try {
        _currentConfig = BusinessConfig.fromJson(storedJson);
      } catch (_) {
        _currentConfig = BusinessConfig.defaultCaffeDemo();
      }
    } else {
      _currentConfig = BusinessConfig.defaultCaffeDemo();
    }
    _controller.add(_currentConfig);
  }

  @override
  Future<void> saveConfig(BusinessConfig newConfig) async {
    _currentConfig = newConfig;
    await _storage.setJson(_storageKey, newConfig.toJson());
    _controller.add(_currentConfig);
  }

  @override
  Future<void> resetToDefaults() async {
    _currentConfig = BusinessConfig.defaultCaffeDemo();
    await _storage.remove(_storageKey);
    _controller.add(_currentConfig);
  }

  void dispose() {
    _controller.close();
  }
}
