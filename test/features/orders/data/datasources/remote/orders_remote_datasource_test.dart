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

import '../../../../../support/legacy_order_test_fence.dart';

void main() {
  group('OrdersRemoteDataSource', () {
    test(
      'loads a complete paginated snapshot and maps aggregate status',
      () async {
        final adapter = _RecordingHttpClientAdapter(
          responseBody: _orderIndexEnvelope(),
        );

        final generatedApiClient = GeneratedApiClient.create(
          baseUrl: 'http://localhost/api/v1',
        );

        generatedApiClient.setAccessToken('test-only-order-token');
        generatedApiClient.client.dio.httpClientAdapter = adapter;

        final dataSource = OrdersRemoteDataSource(
          generatedApiClient: generatedApiClient,
        );

        final orders = await dataSource.getOrders();

        final requestOptions = adapter.requestOptions;

        expect(requestOptions, isNotNull);
        expect(requestOptions!.method, 'GET');
        expect(requestOptions.uri.path, '/api/v1/orders');
        expect(requestOptions.uri.queryParameters['page'], '1');
        expect(requestOptions.uri.queryParameters['per_page'], '20');

        expect(orders, hasLength(1));

        final order = orders.single;

        expect(order.id, 'order-1');
        expect(order.status, 'pending');
        expect(order.aggregateStatus, 'responses_received');
        expect(order.createdAt, DateTime.parse('2026-08-04T00:00:00Z'));

        expect(order.items, hasLength(1));
        expect(order.items.single.productId, 'product-1');
        expect(order.items.single.supplierId, 'supplier-1');
        expect(order.items.single.imageUrl, '');
      },
    );

    test('accepts an empty paginated order list', () async {
      final adapter = _RecordingHttpClientAdapter(
        responseBody: {
          'data': <Object>[],
          'meta': _pageMeta(page: 1, total: 0),
        },
      );
      final client = GeneratedApiClient.create(
        baseUrl: 'http://localhost/api/v1',
      )..setAccessToken('test-only-order-token');
      client.client.dio.httpClientAdapter = adapter;

      final orders = await OrdersRemoteDataSource(
        generatedApiClient: client,
      ).getOrders();

      expect(orders, isEmpty);
      expect(adapter.requests, hasLength(1));
    });

    test(
      'loads all pages exactly once without losing historical orders',
      () async {
        final firstPage = List.generate(
          20,
          (index) => _orderJson(
            aggregateStatus: 'pending_responses',
            id: 'order-$index',
          ),
        );
        final secondPage = [
          _orderJson(aggregateStatus: 'completed', id: 'order-20'),
        ];
        final adapter = _RecordingHttpClientAdapter(
          responseBody: const <String, Object?>{},
          pageResponses: {
            1: {'data': firstPage, 'meta': _pageMeta(page: 1, total: 21)},
            2: {'data': secondPage, 'meta': _pageMeta(page: 2, total: 21)},
          },
        );
        final client = GeneratedApiClient.create(
          baseUrl: 'http://localhost/api/v1',
        )..setAccessToken('test-only-order-token');
        client.client.dio.httpClientAdapter = adapter;

        final orders = await OrdersRemoteDataSource(
          generatedApiClient: client,
        ).getOrders();

        expect(orders, hasLength(21));
        expect(orders.map((order) => order.id).toSet(), hasLength(21));
        expect(orders.last.aggregateStatus, 'completed');
        expect(
          adapter.requests.map(
            (request) => request.uri.queryParameters['page'],
          ),
          ['1', '2'],
        );
      },
    );

    test('rejects a duplicate order across pages', () async {
      final firstPage = List.generate(
        20,
        (index) => _orderJson(
          aggregateStatus: 'pending_responses',
          id: 'order-$index',
        ),
      );
      final adapter = _RecordingHttpClientAdapter(
        responseBody: const <String, Object?>{},
        pageResponses: {
          1: {'data': firstPage, 'meta': _pageMeta(page: 1, total: 21)},
          2: {
            'data': [_orderJson(aggregateStatus: 'completed', id: 'order-0')],
            'meta': _pageMeta(page: 2, total: 21),
          },
        },
      );
      final client = GeneratedApiClient.create(
        baseUrl: 'http://localhost/api/v1',
      )..setAccessToken('test-only-order-token');
      client.client.dio.httpClientAdapter = adapter;

      await expectLater(
        OrdersRemoteDataSource(generatedApiClient: client).getOrders(),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an unknown aggregate status before reconciliation', () async {
      final adapter = _RecordingHttpClientAdapter(
        responseBody: {
          'data': [_orderJson(aggregateStatus: 'unrecognized_status')],
          'meta': _pageMeta(page: 1, total: 1),
        },
      );
      final client = GeneratedApiClient.create(
        baseUrl: 'http://localhost/api/v1',
      )..setAccessToken('test-only-order-token');
      client.client.dio.httpClientAdapter = adapter;

      await expectLater(
        OrdersRemoteDataSource(generatedApiClient: client).getOrders(),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'rejects an incomplete page rather than returning a partial snapshot',
      () async {
        final adapter = _RecordingHttpClientAdapter(
          responseBody: {
            'data': [_orderJson(aggregateStatus: 'pending_responses')],
            'meta': _pageMeta(page: 1, total: 21),
          },
        );
        final client = GeneratedApiClient.create(
          baseUrl: 'http://localhost/api/v1',
        )..setAccessToken('test-only-order-token');
        client.client.dio.httpClientAdapter = adapter;

        await expectLater(
          OrdersRemoteDataSource(generatedApiClient: client).getOrders(),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('failed second page leaves cached orders untouched', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final fence = createLegacyOrderTestFence();
      final local = OrdersLocalDataSource(database, sessionFence: fence);
      await local.saveOrder(
        OrderModel(
          id: 'cached-history',
          status: 'pending',
          createdAt: DateTime.utc(2026, 8, 1),
          items: const [],
        ),
      );

      final firstPage = List.generate(
        20,
        (index) => _orderJson(
          aggregateStatus: 'pending_responses',
          id: 'new-order-$index',
        ),
      );
      final adapter = _RecordingHttpClientAdapter(
        responseBody: const <String, Object?>{},
        pageResponses: {
          1: {'data': firstPage, 'meta': _pageMeta(page: 1, total: 21)},
          2: {'message': 'temporary failure'},
        },
        pageStatuses: const {2: 503},
      );
      final client = GeneratedApiClient.create(
        baseUrl: 'http://localhost/api/v1',
      )..setAccessToken('test-only-order-token');
      client.client.dio.httpClientAdapter = adapter;
      final repo = OrdersRepositoryImpl(
        local,
        sessionFence: fence,
        remoteDataSource: OrdersRemoteDataSource(generatedApiClient: client),
      );

      final result = await repo.getOrders();
      final persisted = await local.getOrders();

      expect(result.map((order) => order.id), ['cached-history']);
      expect(persisted.map((order) => order.id), ['cached-history']);
      expect(adapter.requests, hasLength(2));
    });

    test('rejects account change during pagination', () async {
      final firstPage = List.generate(
        20,
        (index) => _orderJson(
          aggregateStatus: 'pending_responses',
          id: 'order-$index',
        ),
      );
      final client = GeneratedApiClient.create(
        baseUrl: 'http://localhost/api/v1',
      )..setAccessToken('original-account-token');
      final adapter = _RecordingHttpClientAdapter(
        responseBody: {
          'data': firstPage,
          'meta': _pageMeta(page: 1, total: 21),
        },
        onFetch: (_) => client.setAccessToken('other-account-token'),
      );
      client.client.dio.httpClientAdapter = adapter;

      await expectLater(
        OrdersRemoteDataSource(generatedApiClient: client).getOrders(),
        throwsA(isA<StateError>()),
      );
      expect(adapter.requests, hasLength(1));
    });

    test(
      'lazy pages do not delete cached history before the final page',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final fence = createLegacyOrderTestFence();
        final local = OrdersLocalDataSource(database, sessionFence: fence);
        await local.saveOrder(
          OrderModel(
            id: 'cached-history',
            status: 'pending',
            createdAt: DateTime.utc(2026, 8, 1),
            items: const [],
          ),
        );
        final adapter = _RecordingHttpClientAdapter(
          responseBody: const <String, Object?>{},
          pageResponses: {
            1: {
              'data': List.generate(
                20,
                (i) => _orderJson(
                  aggregateStatus: 'pending_responses',
                  id: 'new-$i',
                ),
              ),
              'meta': _pageMeta(page: 1, total: 21),
            },
            2: {
              'data': [_orderJson(aggregateStatus: 'completed', id: 'new-20')],
              'meta': _pageMeta(page: 2, total: 21),
            },
          },
        );
        final client = GeneratedApiClient.create(
          baseUrl: 'http://localhost/api/v1',
        )..setAccessToken('test-only-order-token');
        client.client.dio.httpClientAdapter = adapter;
        final repo = OrdersRepositoryImpl(
          local,
          sessionFence: fence,
          remoteDataSource: OrdersRemoteDataSource(generatedApiClient: client),
        );

        final first = await repo.getOrdersPage(page: 1);
        expect(first.items, hasLength(20));
        expect(first.hasMore, isTrue);
        expect((await local.getOrders()).map((o) => o.id), ['cached-history']);
        expect(adapter.requests, hasLength(1));

        final second = await repo.getOrdersPage(page: 2);
        expect(second.items, hasLength(1));
        expect(second.hasMore, isFalse);
        expect(
          (await local.getOrders()).map((o) => o.id).toSet(),
          hasLength(21),
        );
        expect(
          (await local.getOrders()).any((o) => o.id == 'cached-history'),
          isFalse,
        );
        expect(adapter.requests, hasLength(2));
      },
    );

    test('failed lazy page 2 retains cached history', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final fence = createLegacyOrderTestFence();
      final local = OrdersLocalDataSource(database, sessionFence: fence);
      await local.saveOrder(
        OrderModel(
          id: 'cached-history',
          status: 'pending',
          createdAt: DateTime.utc(2026, 8, 1),
          items: const [],
        ),
      );
      final adapter = _RecordingHttpClientAdapter(
        responseBody: const <String, Object?>{},
        pageResponses: {
          1: {
            'data': List.generate(
              20,
              (i) => _orderJson(
                aggregateStatus: 'pending_responses',
                id: 'new-$i',
              ),
            ),
            'meta': _pageMeta(page: 1, total: 21),
          },
          2: {'message': 'temporary failure'},
        },
        pageStatuses: const {2: 503},
      );
      final client = GeneratedApiClient.create(
        baseUrl: 'http://localhost/api/v1',
      )..setAccessToken('test-only-order-token');
      client.client.dio.httpClientAdapter = adapter;
      final repo = OrdersRepositoryImpl(
        local,
        sessionFence: fence,
        remoteDataSource: OrdersRemoteDataSource(generatedApiClient: client),
      );
      await repo.getOrdersPage(page: 1);
      await expectLater(
        repo.getOrdersPage(page: 2),
        throwsA(isA<DioException>()),
      );
      expect((await local.getOrders()).map((o) => o.id), ['cached-history']);
    });

    test(
      'posts catalog and manual items with their exact API fields',
      () async {
        final adapter = _RecordingHttpClientAdapter(
          responseBody: _orderStoreEnvelope(),
        );

        final generatedApiClient = GeneratedApiClient.create(
          baseUrl: 'http://localhost/api/v1',
        );

        generatedApiClient.setAccessToken('test-only-order-token');
        generatedApiClient.client.dio.httpClientAdapter = adapter;

        final dataSource = OrdersRemoteDataSource(
          generatedApiClient: generatedApiClient,
        );

        final request = CreateOrderModel(
          supplierIds: const ['supplier-1'],
          idempotencyKey: '550e8400-e29b-41d4-a716-446655440000',
          items: const [
            OrderItemModel(
              productId: 'product-1',
              productName: 'Fast charger',
              unitPrice: 4500,
              quantity: 2,
              supplierId: 'supplier-1',
              supplierName: 'Supplier 1',
            ),
            OrderItemModel(
              itemType: 'manual',
              productId: null,
              productName: 'Bulk rice',
              unitPrice: 12.5,
              quantity: 3,
              supplierId: null,
              supplierName: '',
              unit: 'kg',
              note: 'Unopened bags',
            ),
          ],
          notes: 'Call before delivery',
        );

        final created = await dataSource.createOrder(request);

        final requestOptions = adapter.requestOptions;

        expect(requestOptions, isNotNull);
        expect(requestOptions!.method, 'POST');
        expect(requestOptions.path, '/orders');

        expect(
          requestOptions.headers['Idempotency-Key'],
          '550e8400-e29b-41d4-a716-446655440000',
        );

        expect(requestOptions.data, {
          'items': [
            {
              'product_id': 'product-1',
              'quantity': 2,
              'expected_unit_price': 4500.0,
              'expected_supplier_id': 'supplier-1',
            },
            {
              'item_type': 'manual',
              'name': 'Bulk rice',
              'unit_price': 12.5,
              'quantity': 3,
              'unit': 'kg',
              'note': 'Unopened bags',
            },
          ],
          'notes': 'Call before delivery',
          'supplier_ids': ['supplier-1'],
        });

        expect(created.id, 'order-1');
        expect(created.aggregateStatus, 'pending_responses');
        expect(created.items, hasLength(1));

        final item = created.items.single;

        expect(item.productId, 'product-1');
        expect(item.supplierName, 'Supplier 1');
        expect(item.imageUrl, '');
      },
    );
  });
}

Map<String, dynamic> _orderIndexEnvelope() {
  return {
    'data': [_orderJson(aggregateStatus: 'responses_received')],
    'meta': _pageMeta(page: 1, total: 1),
  };
}

Map<String, dynamic> _pageMeta({required int page, required int total}) {
  return {
    'current_page': page,
    'last_page': total == 0 ? 1 : (total + 19) ~/ 20,
    'per_page': 20,
    'total': total,
  };
}

Map<String, dynamic> _orderStoreEnvelope() {
  return {'data': _orderJson(aggregateStatus: 'pending_responses')};
}

Map<String, dynamic> _orderJson({
  required String aggregateStatus,
  String id = 'order-1',
}) {
  return {
    'id': id,
    'status': 'pending',
    'aggregate_status': aggregateStatus,
    'notes': 'Call before delivery',
    'created_at': '2026-08-04T00:00:00Z',
    'updated_at': '2026-08-04T00:00:00Z',
    'items': [
      {
        'id': 'order-item-1',
        'item_type': 'catalog',
        'unit': null,
        'note': null,
        'product_id': 'product-1',
        'product_name': 'Fast charger',
        'unit_price': '4500.00',
        'quantity': 2,
        'supplier_id': 'supplier-1',
        'supplier_name': 'Supplier 1',
        'image_url': null,
      },
    ],
  };
}

final class _RecordingHttpClientAdapter implements HttpClientAdapter {
  _RecordingHttpClientAdapter({
    required this.responseBody,
    this.pageResponses,
    this.pageStatuses,
    this.onFetch,
  });

  final Object responseBody;
  final Map<int, Object>? pageResponses;
  final Map<int, int>? pageStatuses;
  final void Function(RequestOptions)? onFetch;

  RequestOptions? requestOptions;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestOptions = options;
    requests.add(options);
    onFetch?.call(options);
    final page = int.tryParse(options.uri.queryParameters['page'] ?? '1') ?? 1;
    final body = pageResponses?[page] ?? responseBody;

    return ResponseBody.fromString(
      jsonEncode(body),
      pageStatuses?[page] ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
