import 'package:flutter/foundation.dart';

import 'native_bridge.dart';

enum UpdateStatus { idle, checking, upToDate, available, failed, installing }

class UpdateController extends ChangeNotifier {
  UpdateController._();

  static final instance = UpdateController._();

  UpdateStatus _status = UpdateStatus.idle;
  UpdateInfo? _update;
  String _currentVersion = '';

  UpdateStatus get status => _status;
  UpdateInfo? get update => _update;
  String get currentVersion => _currentVersion;
  bool get busy => _status == UpdateStatus.checking || _status == UpdateStatus.installing;

  Future<void> check() async {
    if (busy) return;
    _set(UpdateStatus.checking);
    try {
      if (_currentVersion.isEmpty) _currentVersion = await NativeBridge.appVersion();
      _update = await NativeBridge.checkUpdate();
      _set(_update == null ? UpdateStatus.upToDate : UpdateStatus.available);
    } catch (_) {
      _set(_update == null ? UpdateStatus.failed : UpdateStatus.available);
    }
  }

  Future<InstallResult> install() async {
    if (_update == null || busy) return InstallResult.failed;
    _set(UpdateStatus.installing);
    try {
      return await NativeBridge.installUpdate();
    } catch (_) {
      return InstallResult.failed;
    } finally {
      _set(UpdateStatus.available);
    }
  }

  void _set(UpdateStatus status) {
    _status = status;
    notifyListeners();
  }
}
