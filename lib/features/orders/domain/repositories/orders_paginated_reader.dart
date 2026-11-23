import '../entities/orders_entity.dart';

/// A page of orders from a single logical refresh.
final class OrdersPageSlice<T> {
  const OrdersPageSlice({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int lastPage;
  final int total;
  bool get hasMore => page < lastPage;
}

/// Optional capability: legacy OrdersRepository implementations still work.
abstract interface class OrdersPaginatedReader {
  Future<OrdersPageSlice<OrderEntity>> getOrdersPage({required int page});
}

/// Optional local-first read that never performs network reconciliation.
abstract interface class OrdersCachedPageReader {
  Future<OrdersPageSlice<OrderEntity>> getCachedOrdersPage({required int page});
}
