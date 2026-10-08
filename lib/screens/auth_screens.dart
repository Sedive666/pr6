import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../models/validators.dart';
import '../state/auth_notifier.dart';

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.storefront_outlined, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text, {this.icon = Icons.error_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

String _message(Object e) => switch (e) {
  ValidationException(:final errors) when errors.isNotEmpty =>
    errors.values.join('\n'),
  ApiException(:final message) => message,
  _ => 'Не удалось выполнить запрос: $e',
};

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthNotifier>().login(
        _login.text.trim(),
        _password.text,
      );
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    return _AuthCard(
      title: 'Вход в магазин',
      children: [
        if (auth.endReason != null)
          _ErrorText(auth.endReason!, icon: Icons.timer_off_outlined),
        if (from != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Войдите, чтобы открыть $from',
              textAlign: TextAlign.center,
            ),
          ),
        if (_error != null) _ErrorText(_error!),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _login,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Логин',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: notEmpty('Введите логин'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _hidden,
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _hidden ? 'Показать пароль' : 'Скрыть пароль',
                    icon: Icon(
                      _hidden ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  ),
                ),
                validator: notEmpty('Введите пароль'),
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Войти'),
        ),
        TextButton(
          onPressed: () => context.go('/register'),
          child: const Text('Нет учётной записи? Зарегистрироваться'),
        ),
        const SizedBox(height: 8),
        Text(
          'Учебные записи: admin/admin123, manager/manager123, client/client123',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _login, _password, _repeat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthNotifier>().register(
        _login.text.trim(),
        _password.text,
        _name.text.trim(),
      );
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _AuthCard(
      title: 'Регистрация покупателя',
      children: [
        if (_error != null) _ErrorText(_error!),
        Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Имя'),
                validator: notEmpty('Укажите имя'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _login,
                decoration: const InputDecoration(labelText: 'Логин'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Придумайте логин';
                  if (!RegExp(r'^[A-Za-z0-9_.-]{3,20}$').hasMatch(value)) {
                    return '3–20 латинских букв, цифр или знаков _ . -';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Пароль'),
                validator: strongPassword,
              ),
              const SizedBox(height: 8),
              for (final (label, ok) in passwordRules)
                Row(
                  children: [
                    Icon(
                      ok(_password.text)
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: ok(_password.text) ? Colors.green : scheme.outline,
                      semanticLabel: ok(_password.text)
                          ? 'выполнено'
                          : 'не выполнено',
                    ),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _repeat,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Повтор пароля'),
                onFieldSubmitted: (_) => _submit(),
                validator: (v) =>
                    v == _password.text ? null : 'Пароли не совпадают',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Зарегистрироваться'),
        ),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Уже есть учётная запись? Войти'),
        ),
      ],
    );
  }
}
