import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shoe_store/core/api_client.dart';

class FakeApi implements HttpClientAdapter {
  final Map<String, List<Map<String, dynamic>>> data = {
    'brands': [
      {
        'id': 1,
        'name': 'Nike',
        'country': 'США',
        'foundedYear': 1964,
        'deletedAt': null,
      },
      {
        'id': 2,
        'name': 'Adidas',
        'country': 'Германия',
        'foundedYear': 1949,
        'deletedAt': null,
      },
    ],
    'categories': [
      {
        'id': 1,
        'name': 'Беговые',
        'description': 'Для бега',
        'deletedAt': null,
      },
      {
        'id': 3,
        'name': 'Повседневные',
        'description': 'На каждый день',
        'deletedAt': null,
      },
    ],
    'series': [
      {
        'id': 1,
        'name': 'Air Max',
        'brandId': 1,
        'country': 'США',
        'launchYear': 1987,
        'deletedAt': null,
      },
      {
        'id': 5,
        'name': 'Ultraboost',
        'brandId': 2,
        'country': 'Германия',
        'launchYear': 2015,
        'deletedAt': null,
      },
    ],
    'sneakers': [
      {
        'id': 1,
        'name': 'Nike Air Max 90',
        'sku': 'CN8490-002',
        'year': 2020,
        'price': 14990,
        'brandId': 1,
        'seriesIds': [1],
        'categoryIds': [3],
        'stockTotal': 12,
        'stockAvailable': 7,
        'deletedAt': null,
      },
      {
        'id': 2,
        'name': 'Adidas Ultraboost 22',
        'sku': 'GX5459',
        'year': 2022,
        'price': 17990,
        'brandId': 2,
        'seriesIds': [5],
        'categoryIds': [1],
        'stockTotal': 10,
        'stockAvailable': 6,
        'deletedAt': null,
      },
    ],
    'customers': [],
    'orders': [],
    'reviews': [],
  };

  final List<RequestOptions> requests = [];

  /// Пока задано, ответы ждут завершения: так виджет-тест успевает увидеть
  /// состояние загрузки, которое иначе проскакивает за один кадр.
  Completer<void>? gate;

  /// Сколько следующих ответов отдать ошибкой сервера. Нужно, чтобы
  /// проверить не только появление состояния ошибки, но и восстановление
  /// по кнопке «Повторить».
  int failures = 0;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (gate != null) await gate!.future;
    if (failures > 0) {
      failures--;
      return _json(500, {'message': 'Сервер временно недоступен'});
    }
    final q = options.queryParameters;
    if (q['__fail'] != null) {
      return _json(int.tryParse('${q['__fail']}') ?? 500, {
        'message': 'Ошибка вызвана намеренно параметром __fail',
      });
    }

    final parts = options.uri.path
        .split('/')
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length < 2 || parts.first != 'api') {
      return _json(404, {'message': 'Ресурс не найден'});
    }
    if (parts.length == 2 && parts[1] == '__health') {
      return _json(200, {'ok': true});
    }
    final rows = data[parts[1]];
    if (rows == null) return _json(404, {'message': 'Ресурс не найден'});

    if (parts.length == 3) {
      final id = int.tryParse(parts[2]);
      final row = rows.where((e) => e['id'] == id).firstOrNull;
      return row == null
          ? _json(404, {'message': 'Объект не найден'})
          : _json(200, row);
    }

    if (options.method == 'POST') {
      final body = Map<String, dynamic>.from(options.data as Map);
      body['id'] =
          rows.fold<int>(0, (m, e) => e['id'] as int > m ? e['id'] as int : m) +
          1;
      rows.add(body);
      return _json(201, body);
    }

    final search = '${q['search'] ?? ''}'.toLowerCase();
    final found = rows
        .where(
          (e) =>
              search.isEmpty ||
              '${e['name'] ?? e['text'] ?? ''}'.toLowerCase().contains(search),
        )
        .toList();
    final size = int.tryParse('${q['size'] ?? 10}') ?? 10;
    final page = int.tryParse('${q['page'] ?? 1}') ?? 1;
    final from = (page - 1) * size;
    return _json(200, {
      'items': from >= found.length
          ? []
          : found.sublist(from, (from + size).clamp(0, found.length)),
      'page': page,
      'size': size,
      'total': found.length,
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio([FakeApi? api]) {
  final dio = buildDio();
  dio.httpClientAdapter = api ?? FakeApi();
  return dio;
}

/// Транспорт, направленный в порт, где ничего не слушает: так в тестах
/// воспроизводится полностью недоступный сервер.
Dio offlineProbe() => Dio(
  BaseOptions(
    baseUrl: 'http://127.0.0.1:9/api',
    connectTimeout: const Duration(milliseconds: 200),
  ),
);
