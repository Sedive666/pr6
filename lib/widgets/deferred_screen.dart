import 'package:flutter/material.dart';

import 'app_scaffold.dart';

/// Обёртка для раздела, подключённого через `import ... deferred as`.
///
/// Код такого раздела не входит в основной файл сборки и скачивается
/// отдельной частью при первом открытии. Пока часть загружается, виден
/// индикатор; если скачать не удалось (например, пропала связь) — сообщение
/// и кнопка повтора, а не пустой экран.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({
    super.key,
    required this.load,
    required this.builder,
    this.title = 'Загрузка раздела',
  });

  final Future<void> Function() load;
  final WidgetBuilder builder;
  final String title;

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return AppScaffold(
            title: widget.title,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return AppScaffold(
            title: widget.title,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 12),
                  const Text('Не удалось загрузить раздел'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() => _future = widget.load()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }
        return widget.builder(context);
      },
    );
  }
}
