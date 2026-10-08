import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exceptions.dart';
import '../repositories/entity_repository.dart';
import 'app_scaffold.dart';
import 'field_spec.dart';

class EntityFormScreen extends StatefulWidget {
  const EntityFormScreen({
    super.key,
    required this.id,
    required this.title,
    required this.listPath,
    required this.fields,
    required this.load,
    required this.save,
  });

  final int? id;
  final String title;
  final String listPath;
  final List<FieldSpec> Function(FormValues values) fields;
  final Future<FormValues?> Function(int id) load;
  final Future<void> Function(FormValues values) save;

  bool get isEditing => id != null;

  @override
  State<EntityFormScreen> createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _values = FormValues();
  final _fieldErrors = <String, String>{};
  final _sections = <String, bool>{};

  bool _ready = false;
  bool _dirty = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _prepare() async {
    if (widget.isEditing) {
      final loaded = await widget.load(widget.id!);
      if (!mounted) return;
      if (loaded == null) {
        setState(() {
          _ready = true;
          _loadError = 'Запись ${widget.id} не найдена';
        });
        return;
      }
      _values.text.addAll(loaded.text);
      _values.choice.addAll(loaded.choice);
      _values.textChoice.addAll(loaded.textChoice);
      _values.multi.addAll(loaded.multi);
    }
    for (final field in _flatten(widget.fields(_values))) {
      if (field is TextFieldSpec) {
        _controllers[field.name] = TextEditingController(
          text: _values.text[field.name] ?? '',
        );
      }
    }
    for (final field in widget.fields(_values)) {
      if (field is SectionSpec && field.optional) {
        _sections[field.name] =
            _sections[field.name] ??
            field.fields.any((f) => (_values.text[f.name] ?? '').isNotEmpty);
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  Iterable<FieldSpec> _flatten(List<FieldSpec> fields) sync* {
    for (final field in fields) {
      if (field is SectionSpec) {
        yield* _flatten(field.fields);
      } else {
        yield field;
      }
    }
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty || _saving) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text('Изменения в форме не сохранены. Покинуть страницу?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Уйти без сохранения'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _submit() async {
    setState(_fieldErrors.clear);
    if (!_formKey.currentState!.validate()) return;

    for (final key in _controllers.keys) {
      _values.text[key] = _controllers[key]!.text;
    }
    for (final entry in _sections.entries) {
      if (!entry.value) {
        final section = widget
            .fields(_values)
            .whereType<SectionSpec>()
            .firstWhere((s) => s.name == entry.key);
        for (final f in section.fields) {
          _values.text.remove(f.name);
          _values.textChoice.remove(f.name);
        }
      }
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.save(_values);
      if (!mounted) return;
      _dirty = false;
      messenger.showSnackBar(const SnackBar(content: Text('Запись сохранена')));
      _leave();
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldErrors.addAll(e.errors);
      });
      _formKey.currentState!.validate();
    } on FieldException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldErrors[e.field] = e.message;
      });
      _formKey.currentState!.validate();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    }
  }

  void _leave() =>
      context.canPop() ? context.pop() : context.go(widget.listPath);

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing
        ? 'Изменение: ${widget.title}'
        : 'Новая запись: ${widget.title}';

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) {
          _dirty = false;
          _leave();
        }
      },
      child: AppScaffold(
        title: title,
        body: !_ready
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(child: Text(_loadError!))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: _touch,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final field in widget.fields(_values))
                            _buildField(field),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _saving ? null : _submit,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              widget.isEditing ? 'Сохранить' : 'Создать',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () async {
                                    if (await _confirmLeave() && mounted) {
                                      _dirty = false;
                                      _leave();
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Отмена'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Имя первого текстового поля формы: оно получает фокус при открытии,
  /// чтобы можно было сразу печатать, не беря мышь.
  String? get _firstTextField {
    for (final f in widget.fields(_values)) {
      if (f is TextFieldSpec) return f.name;
    }
    return null;
  }

  Widget _buildField(FieldSpec field) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: switch (field) {
      TextFieldSpec f => _text(f),
      DropdownFieldSpec f => _dropdown(f),
      TextDropdownFieldSpec f => _textDropdown(f),
      MultiSelectFieldSpec f => _multiSelect(f),
      SectionSpec f => _section(f),
    },
  );

  Widget _text(TextFieldSpec f) {
    return TextFormField(
      controller: _controllers[f.name],
      autofocus: f.name == _firstTextField,
      keyboardType: f.numeric
          ? TextInputType.number
          : (f.multiline ? TextInputType.multiline : TextInputType.text),
      inputFormatters: f.numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      maxLines: f.multiline ? 4 : 1,
      // Enter в однострочном поле переходит к следующему, в последнем —
      // отправляет форму.
      textInputAction: f.multiline
          ? TextInputAction.newline
          : TextInputAction.next,
      onFieldSubmitted: f.multiline ? null : (_) => _nextOrSubmit(),
      decoration: fieldDecoration(f.label, hint: f.hint),
      validator: (v) => _fieldErrors[f.name] ?? f.validator?.call(v),
    );
  }

  void _nextOrSubmit() {
    final scope = FocusScope.of(context);
    if (scope.nextFocus()) return;
    if (!_saving) _submit();
  }

  List<DropdownEntry> _entries(
    List<DropdownEntry> Function(FormValues) options,
    bool Function(FormValues, DropdownEntry)? filter,
  ) {
    for (final key in _controllers.keys) {
      _values.text[key] = _controllers[key]!.text;
    }
    final all = options(_values);
    return filter == null ? all : all.where((e) => filter(_values, e)).toList();
  }

  Widget _dropdown(DropdownFieldSpec f) {
    final entries = _entries(f.options, f.filter);
    final value = entries.any((e) => e.id == _values.choice[f.name])
        ? _values.choice[f.name]
        : null;
    return DropdownButtonFormField<int>(
      key: ValueKey('${f.name}-${entries.length}-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: fieldDecoration(f.label),
      items: [
        for (final e in entries)
          DropdownMenuItem(value: e.id, child: Text(e.label)),
      ],
      onChanged: (v) {
        setState(() {
          _values.choice[f.name] = v;
          _fieldErrors.remove(f.name);
        });
        _touch();
      },
      validator: (v) => _fieldErrors[f.name] ?? f.validator?.call(v),
    );
  }

  Widget _textDropdown(TextDropdownFieldSpec f) {
    final value = f.options.contains(_values.textChoice[f.name])
        ? _values.textChoice[f.name]
        : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('${f.name}-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: fieldDecoration(f.label),
      items: [
        for (final e in f.options) DropdownMenuItem(value: e, child: Text(e)),
      ],
      onChanged: (v) {
        setState(() => _values.textChoice[f.name] = v);
        _touch();
      },
      validator: (v) => _fieldErrors[f.name] ?? f.validator?.call(v),
    );
  }

  Widget _multiSelect(MultiSelectFieldSpec f) {
    final entries = _entries(f.options, f.filter);
    final allowed = entries.map((e) => e.id).toSet();
    final current = (_values.multi[f.name] ?? const <int>[])
        .where(allowed.contains)
        .toList();
    _values.multi[f.name] = current;

    return FormField<List<int>>(
      key: ValueKey('${f.name}-${entries.length}'),
      initialValue: current,
      validator: (v) =>
          _fieldErrors[f.name] ?? f.validator?.call(v ?? const []),
      builder: (field) => InputDecorator(
        decoration: fieldDecoration(f.label, error: field.errorText),
        child: entries.isEmpty
            ? Text(
                f.hint ?? 'Нет доступных значений',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in entries)
                    FilterChip(
                      label: Text(e.label),
                      selected: field.value!.contains(e.id),
                      onSelected: (_) {
                        final next = [...field.value!];
                        next.contains(e.id)
                            ? next.remove(e.id)
                            : next.add(e.id);
                        field.didChange(next);
                        setState(() {
                          _values.multi[f.name] = next;
                          _fieldErrors.remove(f.name);
                        });
                        _touch();
                      },
                    ),
                ],
              ),
      ),
    );
  }

  Widget _section(SectionSpec f) {
    final enabled = !f.optional || (_sections[f.name] ?? false);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    f.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (f.optional)
                  Switch(
                    value: enabled,
                    onChanged: (v) {
                      setState(() => _sections[f.name] = v);
                      _touch();
                    },
                  ),
              ],
            ),
            if (f.optional && !enabled)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  f.enabledLabel ?? 'Не оформлена',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            if (enabled) ...[
              const SizedBox(height: 12),
              for (final nested in f.fields) _buildField(nested),
            ],
          ],
        ),
      ),
    );
  }
}
