import '../entities/orders_entity.dart';
import '../repositories/orders_repository.dart';
import '../repositories/orders_paginated_reader.dart';

class OrdersUseCase {
  OrdersUseCase(this.repository);

  final OrdersRepository repository;

  Future<List<OrderEntity>> getOrders() {
    return repository.getOrders();
  }

  Future<OrdersPageSlice<OrderEntity>?> getCachedOrdersPage({
    required int page,
  }) {
    if (repository is OrdersCachedPageReader) {
      return (repository as OrdersCachedPageReader).getCachedOrdersPage(
        page: page,
      );
    }
    return Future<OrdersPageSlice<OrderEntity>?>.value(null);
  }

  Future<OrdersPageSlice<OrderEntity>> getOrdersPage({
    required int page,
  }) async {
    if (repository is OrdersPaginatedReader) {
      return (repository as OrdersPaginatedReader).getOrdersPage(page: page);
    }
    // Compatibility for existing test doubles and legacy repositories.
    if (page < 1) throw ArgumentError.value(page, 'page');
    final all = await repository.getOrders();
    const perPage = 20;
    final lastPage = all.isEmpty ? 1 : (all.length + perPage - 1) ~/ perPage;
    if (page > lastPage) throw RangeError.range(page, 1, lastPage);
    final start = (page - 1) * perPage;
    final end = start + perPage < all.length ? start + perPage : all.length;
    return OrdersPageSlice<OrderEntity>(
      items: List<OrderEntity>.unmodifiable(all.sublist(start, end)),
      page: page,
      lastPage: lastPage,
      total: all.length,
    );
  }

  Future<OrderEntity> createOrder(CreateOrderRequest request) {
    return repository.createOrder(request);
  }
}
