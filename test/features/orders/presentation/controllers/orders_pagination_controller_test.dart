import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:talbytk/features/orders/domain/entities/orders_entity.dart';
import 'package:talbytk/features/orders/domain/repositories/orders_paginated_reader.dart';
import 'package:talbytk/features/orders/domain/repositories/orders_repository.dart';
import 'package:talbytk/features/orders/domain/usecases/orders_usecase.dart';
import 'package:talbytk/features/orders/presentation/controllers/orders_controller.dart';

void main() {
  test('loads first page and appends next page only on demand', () async {
    final repo = _PagedFakeRepository();
    final controller = OrdersController(OrdersUseCase(repo), autoLoad: false);
    addTearDown(controller.dispose);

    await controller.loadOrders();
    expect(repo.requestedPages, [1]);
    expect(controller.state.orders, hasLength(20));
    expect(controller.state.hasMoreOrders, isTrue);
    expect(controller.state.nextPage, 2);

    await controller.loadMoreOrders();
    expect(repo.requestedPages, [1, 2]);
    expect(controller.state.orders, hasLength(21));
    expect(
      controller.state.orders.map((order) => order.id).toSet(),
      hasLength(21),
    );
    expect(controller.state.hasMoreOrders, isFalse);
    expect(controller.state.isLoadingMore, isFalse);

    await controller.loadMoreOrders();
    expect(repo.requestedPages, [1, 2]);
  });

  test('a failed later page retains the first page and allows retry', () async {
    final repo = _PagedFakeRepository(failPageTwoOnce: true);
    final controller = OrdersController(OrdersUseCase(repo), autoLoad: false);
    addTearDown(controller.dispose);

    await controller.loadOrders();
    await controller.loadMoreOrders();
    expect(controller.state.orders, hasLength(20));
    expect(controller.state.nextPage, 2);
    expect(controller.state.hasMoreOrders, isTrue);
    expect(controller.state.loadMoreErrorMessage, isNotNull);

    await controller.loadMoreOrders();
    expect(controller.state.orders, hasLength(21));
    expect(controller.state.loadMoreErrorMessage, isNull);
  });

  test('a refresh supersedes an in-flight later page', () async {
    final pending = Completer<OrdersPageSlice<OrderEntity>>();
    final repo = _PagedFakeRepository(secondPageCompleter: pending);
    final controller = OrdersController(OrdersUseCase(repo), autoLoad: false);
    addTearDown(controller.dispose);

    await controller.loadOrders();
    final older = controller.loadMoreOrders();
    await controller.loadOrders();
    pending.complete(
      OrdersPageSlice<OrderEntity>(
        items: [_order(20)],
        page: 2,
        lastPage: 2,
        total: 21,
      ),
    );
    await older;
    expect(controller.state.orders, hasLength(20));
    expect(controller.state.nextPage, 2);
    expect(controller.state.isLoadingMore, isFalse);
  });
}

OrderEntity _order(int index) => OrderEntity(
  id: 'order-$index',
  status: OrderStatus.pending,
  items: const [],
  createdAt: DateTime.utc(2026, 11, 1),
);

final class _PagedFakeRepository
    implements OrdersRepository, OrdersPaginatedReader {
  _PagedFakeRepository({
    this.failPageTwoOnce = false,
    this.secondPageCompleter,
  });
  bool failPageTwoOnce;
  final Completer<OrdersPageSlice<OrderEntity>>? secondPageCompleter;
  final List<int> requestedPages = [];

  @override
  Future<OrdersPageSlice<OrderEntity>> getOrdersPage({
    required int page,
  }) async {
    requestedPages.add(page);
    if (page == 1) {
      return OrdersPageSlice<OrderEntity>(
        items: List.generate(20, _order),
        page: 1,
        lastPage: 2,
        total: 21,
      );
    }
    if (failPageTwoOnce) {
      failPageTwoOnce = false;
      throw StateError('Network failed');
    }
    if (secondPageCompleter != null) return secondPageCompleter!.future;
    return OrdersPageSlice<OrderEntity>(
      items: [_order(20)],
      page: 2,
      lastPage: 2,
      total: 21,
    );
  }

  @override
  Future<List<OrderEntity>> getOrders() async => const [];

  @override
  Future<OrderEntity> createOrder(CreateOrderRequest request) async {
    throw UnimplementedError();
  }
}
