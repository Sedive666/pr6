import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoe_store/core/auth_api.dart';
import 'package:shoe_store/core/breakpoints.dart';
import 'package:shoe_store/core/connectivity.dart';
import 'package:shoe_store/models/app_user.dart';
import 'package:shoe_store/state/auth_notifier.dart';
import 'package:shoe_store/widgets/app_scaffold.dart';

import 'app_harness.dart';
import 'fake_api.dart';

void main() {
  group('Точки перелома раскладки', () {
    test('четыре проверяемые ширины попадают в разные раскладки', () {
      expect(layoutOf(360), Layout.compact);
      expect(layoutOf(768), Layout.medium);
      expect(layoutOf(1280), Layout.expanded);
      expect(layoutOf(1920), Layout.large);
    });

    test('граница относится к более широкой раскладке', () {
      expect(layoutOf(599.9), Layout.compact);
      expect(layoutOf(600), Layout.medium);
      expect(layoutOf(1023.9), Layout.medium);
      expect(layoutOf(1024), Layout.expanded);
      expect(layoutOf(1439.9), Layout.expanded);
      expect(layoutOf(1440), Layout.large);
    });

    test('таблица появляется только от 1024, до неё — карточки', () {
      expect(layoutOf(360).showsTable, isFalse);
      expect(layoutOf(768).showsTable, isFalse);
      expect(layoutOf(1280).showsTable, isTrue);
      expect(layoutOf(1920).showsTable, isTrue);
    });

    test('на 768 сетка карточек в две колонки, на 360 — в одну', () {
      expect(layoutOf(360).cardColumns, 1);
      expect(layoutOf(768).cardColumns, 2);
    });
  });

  group('Навигация', () {
    Future<AuthNotifier> as(Role role) async {
      SharedPreferences.setMockInitialValues({});
      return AuthNotifier.signedIn(
        await SharedPreferences.getInstance(),
        AuthApi(),
        testUsers[role]!,
      );
    }

    test('роль видит только свои разделы', () async {
      final client = sectionsFor(await as(Role.client)).map((s) => s.path);
      expect(client, contains('/my/orders'));
      expect(client, contains('/sneakers'));
      expect(client, isNot(contains('/customers')));
      expect(client, isNot(contains('/admin/users')));

      final admin = sectionsFor(await as(Role.admin)).map((s) => s.path);
      expect(admin, contains('/admin/users'));
      expect(admin, contains('/admin/stats'));
      expect(admin, isNot(contains('/my/orders')));
    });

    test('в нижнюю панель попадает открытый раздел, даже не из начала', () {
      final shown = bottomSections(navSections, '/reviews');
      expect(shown.length, 4);
      expect(shown.map((s) => s.path), contains('/reviews'));
      expect(shown.first.path, navSections.first.path);
    });

    test('короткий список разделов помещается в панель целиком', () {
      final few = navSections.take(5).toList();
      expect(bottomSections(few, '/sneakers'), few);
    });
  });

  group('Монитор связи', () {
    test('пропажа связи и самостоятельное восстановление', () async {
      final monitor = ConnectivityMonitor(
        probe: fakeDio(FakeApi()),
        period: const Duration(milliseconds: 10),
      );
      var notifications = 0;
      monitor.addListener(() => notifications++);

      expect(monitor.online, isTrue);
      monitor.reportOffline();
      expect(monitor.online, isFalse);
      expect(notifications, 1);

      // Повторное сообщение о той же пропаже лишних оповещений не даёт.
      monitor.reportOffline();
      expect(notifications, 1);

      await monitor.check();
      expect(monitor.online, isTrue);
      expect(notifications, 2);
      monitor.dispose();
    });

    test(
      'без ответа сервера монитор остаётся в состоянии «нет связи»',
      () async {
        // Адрес, на котором ничего не слушает: проверка живости не проходит.
        final monitor = ConnectivityMonitor(
          probe: offlineProbe(),
          period: const Duration(milliseconds: 10),
        );
        monitor.reportOffline();
        await monitor.check();
        expect(monitor.online, isFalse);
        monitor.dispose();
      },
    );
  });
}
