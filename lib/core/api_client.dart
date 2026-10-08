import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../state/auth_notifier.dart';
import 'api_exceptions.dart';
import 'config.dart';
import 'connectivity.dart';

Dio buildDio({AuthNotifier? auth, ConnectivityMonitor? monitor}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final delay = Uri.base.queryParameters['__delay'];
        if (delay != null) {
          options.queryParameters = {
            ...options.queryParameters,
            '__delay': delay,
          };
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint(
            '[API] ${response.requestOptions.method} '
            '${response.requestOptions.uri} → ${response.statusCode}',
          );
        }
        // Любой ответ сервера — признак, что связь есть.
        monitor?.reportOnline();
        final status = response.statusCode ?? 0;
        if (status >= 400) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
      onError: (error, handler) {
        if (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout) {
          monitor?.reportOffline();
        }
        if (kDebugMode) {
          debugPrint(
            '[API] ${error.requestOptions.method} ${error.requestOptions.uri} '
            'сбой ${error.type} → ${error.response?.statusCode ?? '—'}',
          );
        }
        return handler.next(error);
      },
    ),
  );

  if (auth != null) dio.interceptors.add(AuthInterceptor(dio, auth));
  dio.interceptors.add(RetryInterceptor(dio));
  return dio;
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._auth);

  final Dio _dio;
  final AuthNotifier _auth;

  static const _retried = 'auth_retried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _auth.accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        options.path.contains('/auth/') ||
        !_auth.isAuthenticated) {
      return handler.next(err);
    }
    if (options.extra[_retried] == true) {
      await _auth.logout(reason: 'Сессия недействительна, войдите заново');
      return handler.next(err);
    }
    if (!await _auth.refreshTokens()) return handler.next(err);

    if (kDebugMode) debugPrint('[AUTH] повтор ${options.uri}');
    options.extra = {...options.extra, _retried: true};
    try {
      return handler.resolve(await _dio.fetch(options));
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}

class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.attempts = retryAttempts});

  final Dio _dio;
  final int attempts;

  static const _key = 'retry';

  bool _retryable(DioException e) =>
      e.requestOptions.method.toUpperCase() == 'GET' &&
      (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final done = (err.requestOptions.extra[_key] as int?) ?? 0;
    if (!_retryable(err) || done >= attempts - 1) {
      return handler.next(err);
    }

    final next = done + 1;
    await Future.delayed(retryPause * (1 << done));
    if (kDebugMode) {
      debugPrint(
        '[API] повтор $next из ${attempts - 1}: ${err.requestOptions.uri}',
      );
    }

    final options = err.requestOptions;
    options.extra = {...options.extra, _key: next};
    try {
      final response = await _dio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
