import 'package:flutter/foundation.dart' hide Category;

import '../models/brand.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/entity.dart';
import '../models/list_query.dart';
import '../models/order.dart';
import '../models/page_result.dart';
import '../models/queries.dart';
import '../models/review.dart';
import '../models/series.dart';
import '../models/sneaker.dart';
import '../repositories/entity_repository.dart';

enum LoadStatus { idle, loading, success, error }

typedef SneakerListNotifier = ListNotifier<Sneaker, SneakerQuery>;
typedef SeriesListNotifier = ListNotifier<Series, SeriesQuery>;
typedef BrandListNotifier = ListNotifier<Brand, BrandQuery>;
typedef CategoryListNotifier = ListNotifier<Category, CategoryQuery>;
typedef CustomerListNotifier = ListNotifier<Customer, CustomerQuery>;
typedef OrderListNotifier = ListNotifier<Order, OrderQuery>;
typedef ReviewListNotifier = ListNotifier<Review, ReviewQuery>;

class ListNotifier<T extends Entity, Q extends ListQuery<Q>>
    extends ChangeNotifier {
  ListNotifier(this.repository, this._query);

  final EntityRepository<T, Q> repository;
  Q _query;
  PageResult<T> _result = PageResult<T>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};
  int _ticket = 0;

  Q get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<void> load() async {
    final ticket = ++_ticket;
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final result = await repository.find(_query);
      if (ticket != _ticket) return;
      _result = result;
      _status = LoadStatus.success;
    } catch (e) {
      if (ticket != _ticket) return;
      _result = PageResult<T>.empty();
      _error = 'Не удалось загрузить список: $e';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> applyQuery(Q next) async {
    // После ошибки повторный переход по тому же адресу обязан перезагрузить
    // список, иначе экран навсегда остаётся в состоянии ошибки.
    if (next.sameAs(_query) &&
        _status != LoadStatus.idle &&
        _status != LoadStatus.error) {
      return;
    }
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(int id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    notifyListeners();
  }

  void setSelection(Iterable<int> ids, bool value) {
    value ? _selected.addAll(ids) : _selected.removeAll(ids);
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  Future<int> deleteSelected() async {
    final count = await repository.deleteMany(_selected.toList());
    _selected.clear();
    await load();
    return count;
  }

  Future<T?> findById(int id) => repository.findById(id);

  Future<List<T>> options() => repository.all();

  Future<T> save(T item) async {
    final saved = item.id > 0
        ? await repository.update(item)
        : await repository.create(item);
    await load();
    return saved;
  }

  Future<void> softDelete(int id) async {
    await repository.softDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> hardDelete(int id) async {
    await repository.hardDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> restore(int id) async {
    await repository.restore(id);
    await load();
  }
}
