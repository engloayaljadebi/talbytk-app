import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talbytk/core/database/app_database.dart';
import 'package:talbytk/core/network/generated_api_client.dart';
import 'package:talbytk/features/orders/data/datasources/local/orders_local_datasource.dart';
import 'package:talbytk/features/orders/data/datasources/remote/orders_remote_datasource.dart';
import 'package:talbytk/features/orders/data/models/orders_model.dart';
import 'package:talbytk/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:talbytk/features/orders/domain/usecases/orders_usecase.dart';
import 'package:talbytk/features/orders/presentation/controllers/orders_controller.dart';

import '../../../support/legacy_order_test_fence.dart';

void main() {
  group(
    'REL-03 orders pagination integration (Dio -> Drift -> controller)',
    () {
      test(
        '45 orders load in 3 requests; only a complete snapshot replaces cache',
        () async {
          final harness = _Harness(
            orders: List.generate(45, (index) => _orderJson(index)),
          );
          addTearDown(harness.dispose);
          await harness.local.saveOrder(_cachedOrder('old-server-history'));

          final controller = harness.controller;
          await controller.loadOrders();
          expect(harness.adapter.requestedPages, [1]);
          expect(controller.state.orders, hasLength(20));
          expect(controller.state.hasMoreOrders, isTrue);
          expect(
            (await harness.local.getOrders()).single.id,
            'old-server-history',
          );

          await controller.loadMoreOrders();
          expect(harness.adapter.requestedPages, [1, 2]);
          expect(controller.state.orders, hasLength(40));
          expect(
            (await harness.local.getOrders()).single.id,
            'old-server-history',
          );

          await controller.loadMoreOrders();
          expect(harness.adapter.requestedPages, [1, 2, 3]);
          expect(controller.state.orders, hasLength(45));
          expect(controller.state.hasMoreOrders, isFalse);
          expect(
            controller.state.orders.map((o) => o.id).toSet(),
            hasLength(45),
          );
          expect(
            (await harness.local.getOrders()).map((o) => o.id).toSet(),
            controller.state.orders.map((o) => o.id).toSet(),
          );
          expect(
            (await harness.local.getOrders()).any(
              (o) => o.id == 'old-server-history',
            ),
            isFalse,
          );
          await controller.loadMoreOrders();
          expect(harness.adapter.requestedPages, [1, 2, 3]);
        },
      );

      test(
        '503 on page 2 retains cache, preserves UI, and retries same page',
        () async {
          final harness = _Harness(
            orders: List.generate(21, (index) => _orderJson(index)),
            transientFailures: {2: 1},
          );
          addTearDown(harness.dispose);
          await harness.local.saveOrder(_cachedOrder('cached-before-failure'));

          await harness.controller.loadOrders();
          await harness.controller.loadMoreOrders();
          expect(harness.controller.state.orders, hasLength(20));
          expect(harness.controller.state.nextPage, 2);
          expect(harness.controller.state.hasMoreOrders, isTrue);
          expect(harness.controller.state.loadMoreErrorMessage, isNotNull);
          expect(
            (await harness.local.getOrders()).single.id,
            'cached-before-failure',
          );

          await harness.controller.loadMoreOrders();
          expect(harness.adapter.requestedPages, [1, 2, 2]);
          expect(harness.controller.state.orders, hasLength(21));
          expect(harness.controller.state.loadMoreErrorMessage, isNull);
          expect((await harness.local.getOrders()), hasLength(21));
        },
      );

      test(
        '503 on page 1 uses only local Drift pages, without remote page 2',
        () async {
          final harness = _Harness(orders: const [], transientFailures: {1: 1});
          addTearDown(harness.dispose);
          for (var index = 0; index < 21; index++) {
            await harness.local.saveOrder(_cachedOrder('cached-$index', index));
          }

          await harness.controller.loadOrders();
          expect(harness.controller.state.orders, hasLength(20));
          expect(harness.controller.state.hasMoreOrders, isTrue);
          await harness.controller.loadMoreOrders();
          expect(harness.controller.state.orders, hasLength(21));
          expect(harness.controller.state.hasMoreOrders, isFalse);
          expect(harness.adapter.requestedPages, [1]);
          expect(await harness.local.getOrders(), hasLength(21));
        },
      );

      test(
        'pending local create and its Outbox survive final reconciliation',
        () async {
          final harness = _Harness(
            orders: List.generate(21, (index) => _orderJson(index)),
          );
          addTearDown(harness.dispose);
          final pending = await harness.local.createOrder(
            CreateOrderModel(
              idempotencyKey: '11111111-1111-4111-8111-111111111111',
              supplierIds: const ['supplier-1'],
              items: const [
                OrderItemModel(
                  productId: 'product-local',
                  productName: 'Offline pending product',
                  unitPrice: 10,
                  quantity: 1,
                  supplierId: 'supplier-1',
                  supplierName: 'Supplier 1',
                ),
              ],
            ),
          );
          await harness.local.saveOrder(_cachedOrder('stale-server-history'));

          await harness.controller.loadOrders();
          expect(
            harness.controller.state.orders.any((o) => o.id == pending.id),
            isTrue,
          );
          await harness.controller.loadMoreOrders();
          final persisted = await harness.local.getOrders();
          expect(persisted.map((o) => o.id).toSet(), {
            ...List.generate(21, (i) => 'server-$i'),
            pending.id,
          });
          expect(
            (await harness.database
                    .select(harness.database.syncOperations)
                    .get())
                .single
                .entityId,
            pending.id,
          );
          expect(
            harness.controller.state.orders.map((o) => o.id).toSet(),
            persisted.map((o) => o.id).toSet(),
          );
        },
      );

      test(
        'auth token changes during later page: cache stays untouched',
        () async {
          final harness = _Harness(
            orders: List.generate(21, (index) => _orderJson(index)),
            switchTokenOnPage: 2,
          );
          addTearDown(harness.dispose);
          await harness.local.saveOrder(_cachedOrder('private-cache'));

          await harness.controller.loadOrders();
          await harness.controller.loadMoreOrders();
          expect(harness.controller.state.orders, hasLength(20));
          expect(harness.controller.state.loadMoreErrorMessage, isNotNull);
          expect((await harness.local.getOrders()).single.id, 'private-cache');
          expect(harness.adapter.requestedPages, [1, 2]);
        },
      );
    },
  );
}

class _Harness {
  _Harness({
    required List<Map<String, dynamic>> orders,
    Map<int, int> transientFailures = const {},
    int? switchTokenOnPage,
  }) {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final fence = createLegacyOrderTestFence();
    local = OrdersLocalDataSource(database, sessionFence: fence);
    client = GeneratedApiClient.create(baseUrl: 'http://localhost/api/v1')
      ..setAccessToken('test-token');
    adapter = _PagingAdapter(
      orders: orders,
      transientFailures: Map.of(transientFailures),
      onFetch: (page) {
        if (page == switchTokenOnPage) {
          client.setAccessToken('different-account-token');
        }
      },
    );
    client.client.dio.httpClientAdapter = adapter;
    final repository = OrdersRepositoryImpl(
      local,
      sessionFence: fence,
      remoteDataSource: OrdersRemoteDataSource(generatedApiClient: client),
    );
    controller = OrdersController(OrdersUseCase(repository), autoLoad: false);
  }

  late final AppDatabase database;
  late final OrdersLocalDataSource local;
  late final GeneratedApiClient client;
  late final _PagingAdapter adapter;
  late final OrdersController controller;

  Future<void> dispose() async {
    controller.dispose();
    await database.close();
  }
}

final class _PagingAdapter implements HttpClientAdapter {
  _PagingAdapter({
    required this.orders,
    required this.transientFailures,
    required this.onFetch,
  });

  final List<Map<String, dynamic>> orders;
  final Map<int, int> transientFailures;
  final void Function(int page) onFetch;
  final List<int> requestedPages = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final page = int.parse(options.uri.queryParameters['page']!);
    expect(options.uri.path, '/api/v1/orders');
    expect(options.uri.queryParameters['per_page'], '20');
    requestedPages.add(page);
    onFetch(page);
    final failures = transientFailures[page] ?? 0;
    if (failures > 0) {
      transientFailures[page] = failures - 1;
      return _jsonResponse({'message': 'temporary error'}, 503);
    }
    const perPage = 20;
    final start = (page - 1) * perPage;
    final end = start + perPage < orders.length
        ? start + perPage
        : orders.length;
    return _jsonResponse({
      'data': orders.sublist(start, end),
      'meta': {
        'current_page': page,
        'last_page': orders.isEmpty ? 1 : (orders.length + 19) ~/ 20,
        'per_page': perPage,
        'total': orders.length,
      },
    }, 200);
  }

  ResponseBody _jsonResponse(Object body, int status) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _orderJson(int index) => {
  'id': 'server-$index',
  'status': 'pending',
  'aggregate_status': 'pending_responses',
  'notes': 'REL-03 integration test',
  'created_at': DateTime.utc(
    2026,
    11,
    1,
  ).add(Duration(seconds: index)).toIso8601String(),
  'updated_at': '2026-11-01T00:00:00Z',
  'items': <Object>[],
};

OrderModel _cachedOrder(String id, [int seconds = 0]) => OrderModel(
  id: id,
  status: 'pending',
  items: const [],
  createdAt: DateTime.utc(2026, 10, 1).add(Duration(seconds: seconds)),
);
