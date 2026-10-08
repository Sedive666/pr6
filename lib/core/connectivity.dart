import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';

/// Следит за доступностью сервера.
///
/// О пропаже связи сообщает сетевой слой ([reportOffline] из интерсептора
/// в `api_client.dart`). Пока связи нет, монитор сам опрашивает `/__health`
/// и при первом успешном ответе возвращается в состояние «на связи» и
/// оповещает слушателей. Экраны по этому оповещению перезагружают данные,
/// поэтому страницу обновлять не нужно.
class ConnectivityMonitor extends ChangeNotifier {
  ConnectivityMonitor({Dio? probe, this.period = const Duration(seconds: 3)})
    : _probe =
          probe ??
          Dio(
            BaseOptions(
              baseUrl: apiBaseUrl,
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
            ),
          );

  final Dio _probe;
  final Duration period;

  bool _online = true;
  Timer? _timer;

  bool get online => _online;

  /// Сетевой слой не смог достучаться до сервера.
  void reportOffline() {
    if (!_online) return;
    _online = false;
    _timer?.cancel();
    _timer = Timer.periodic(period, (_) => _check());
    notifyListeners();
  }

  /// Любой успешный ответ сервера.
  void reportOnline() {
    if (_online) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _online = true;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  /// Одна проверка живости; вынесена отдельно для тестов.
  @visibleForTesting
  Future<void> check() => _check();

  Future<void> _check() async {
    try {
      await _probe.get('/__health');
      reportOnline();
    } catch (_) {
      // Сервер всё ещё недоступен: ждём следующего тика.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
