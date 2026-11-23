import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talbytk/core/database/app_database.dart';
import 'package:talbytk/features/orders/data/datasources/local/orders_local_datasource.dart';
import 'package:talbytk/features/orders/data/datasources/orders_datasource.dart';
import 'package:talbytk/features/orders/data/models/orders_model.dart';
import 'package:talbytk/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:talbytk/features/orders/domain/entities/orders_entity.dart';
import '../../../../support/legacy_order_test_fence.dart';

void main() {
  group('OrdersRepositoryImpl', () {
    test('creates remotely and persists the server order locally', () async {
      final AppDatabase database = AppDatabase.forTesting(
        NativeDatabase.memory(),
      );

      addTearDown(database.close);

      final localDataSource = OrdersLocalDataSource(
        database,
        sessionFence: createLegacyOrderTestFence(),
      );

      final serverCreatedAt = DateTime.utc(2026, 8, 24, 12);

      final remoteDataSource = _FakeRemoteOrdersDataSource(
        createdOrder: OrderModel(
          id: 'server-order-1',
          status: 'pending',
          createdAt: serverCreatedAt,
          notes: 'Remote order',
          items: const [
            OrderItemModel(
              productId: 'product-1',
              productName: 'Product 1',
              unitPrice: 100,
              quantity: 2,
              supplierId: 'supplier-1',
              supplierName: 'Supplier 1',
            ),
            OrderItemModel(
              productId: 'product-2',
              productName: 'Product 2',
              unitPrice: 200,
              quantity: 1,
              supplierId: 'supplier-2',
              supplierName: 'Supplier 2',
            ),
          ],
        ),
      );

      final repository = OrdersRepositoryImpl(
        localDataSource,
        sessionFence: createLegacyOrderTestFence(),
        remoteDataSource: remoteDataSource,
      );

      final request = CreateOrderRequest(
        supplierIds: const ['supplier-1'],
        notes: 'Remote order',
        items: const [
          OrderItemEntity(
            productId: 'product-1',
            productName: 'Product 1',
            unitPrice: 100,
            quantity: 2,
            supplierId: 'supplier-1',
            supplierName: 'Supplier 1',
          ),
          OrderItemEntity(
            productId: 'product-2',
            productName: 'Product 2',
            unitPrice: 200,
            quantity: 1,
            supplierId: 'supplier-2',
            supplierName: 'Supplier 2',
          ),
        ],
      );

      final OrderEntity created = await repository.createOrder(request);

      expect(remoteDataSource.createRequest, isNotNull);

      expect(created.id, 'server-order-1');
      expect(created.status, OrderStatus.pending);
      expect(created.items, hasLength(2));

      final List<OrderEntity> localOrders = await repository.getOrders();

      expect(localOrders, hasLength(1));
      expect(localOrders.single.id, 'server-order-1');
      expect(localOrders.single.createdAt, serverCreatedAt);

      expect(
        localOrders.single.items.map((item) => item.supplierId).toSet(),
        <String>{'supplier-1', 'supplier-2'},
      );

      final syncOperations = await database
          .select(database.syncOperations)
          .get();

      // النجاح المباشر مع السيرفر لا يجب أن يترك عملية Outbox.
      expect(syncOperations, isEmpty);
    });

    test(
      'queues a local order when remote creation fails due to connectivity',
      () async {
        final AppDatabase database = AppDatabase.forTesting(
          NativeDatabase.memory(),
        );

        addTearDown(database.close);

        final localDataSource = OrdersLocalDataSource(
          database,
          sessionFence: createLegacyOrderTestFence(),
        );

        final remoteDataSource = _FakeRemoteOrdersDataSource(
          createError: DioException(
            requestOptions: RequestOptions(path: '/orders'),
            type: DioExceptionType.connectionError,
            message: 'network unavailable',
          ),
        );

        final repository = OrdersRepositoryImpl(
          localDataSource,
          sessionFence: createLegacyOrderTestFence(),
          remoteDataSource: remoteDataSource,
        );

        final request = CreateOrderRequest(
          supplierIds: const ['supplier-1'],
          notes: 'Offline order',
          items: const [
            OrderItemEntity(
              productId: 'product-1',
              productName: 'Product 1',
              unitPrice: 100,
              quantity: 2,
              supplierId: 'supplier-1',
              supplierName: 'Supplier 1',
            ),
            OrderItemEntity(
              productId: 'product-2',
              productName: 'Product 2',
              unitPrice: 200,
              quantity: 1,
              supplierId: 'supplier-2',
              supplierName: 'Supplier 2',
            ),
          ],
        );

        final OrderEntity created = await repository.createOrder(request);

        final localOrders = await localDataSource.getOrders();

        final syncOperations = await database
            .select(database.syncOperations)
            .get();

        expect(created.id, startsWith('local-order-'));
        expect(created.status, OrderStatus.pending);
        expect(created.items, hasLength(2));

        expect(localOrders, hasLength(1));
        expect(localOrders.single.id, created.id);

        expect(syncOperations, hasLength(1));

        final operation = syncOperations.single;

        expect(operation.id, 'order:create:${created.id}');
        expect(operation.entityType, 'order');
        expect(operation.entityId, created.id);
        expect(operation.operation, 'create');
        expect(operation.attempts, 0);
        expect(operation.lastError, isNull);

        final payload =
            jsonDecode(operation.payloadJson) as Map<String, dynamic>;
        final String firstAttemptKey =
            remoteDataSource.createRequest!.idempotencyKey;

        expect(firstAttemptKey, isNotEmpty);
        expect(payload['idempotencyKey'], firstAttemptKey);

        expect(payload['notes'], 'Offline order');

        final items = payload['items'] as List<dynamic>;

        expect(items, hasLength(2));

        expect(
          items
              .map((item) => (item as Map<String, dynamic>)['supplierId'])
              .toSet(),
          <String>{'supplier-1', 'supplier-2'},
        );
      },
    );

    test('keeps local order queued when server returns HTTP 503', () async {
      final AppDatabase database = AppDatabase.forTesting(
        NativeDatabase.memory(),
      );

      addTearDown(database.close);

      final localDataSource = OrdersLocalDataSource(
        database,
        sessionFence: createLegacyOrderTestFence(),
      );
      final requestOptions = RequestOptions(path: '/orders');

      final remoteError = DioException(
        requestOptions: requestOptions,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 503,
          data: <String, dynamic>{'message': 'Service unavailable'},
        ),
        type: DioExceptionType.badResponse,
        message: 'Service unavailable',
      );

      final remoteDataSource = _FakeRemoteOrdersDataSource(
        createError: remoteError,
      );

      final repository = OrdersRepositoryImpl(
        localDataSource,
        sessionFence: createLegacyOrderTestFence(),
        remoteDataSource: remoteDataSource,
      );

      final OrderEntity created = await repository.createOrder(
        CreateOrderRequest(
          supplierIds: const ['supplier-1'],
          items: const [
            OrderItemEntity(
              productId: 'product-1',
              productName: 'Product 1',
              unitPrice: 100,
              quantity: 1,
              supplierId: 'supplier-1',
              supplierName: 'Supplier 1',
            ),
          ],
        ),
      );

      final localOrders = await localDataSource.getOrders();
      final syncOperations = await database
          .select(database.syncOperations)
          .get();

      expect(created.id, startsWith('local-order-'));
      expect(localOrders, hasLength(1));
      expect(localOrders.single.id, created.id);
      expect(syncOperations, hasLength(1));

      final payload =
          jsonDecode(syncOperations.single.payloadJson) as Map<String, dynamic>;

      expect(remoteDataSource.createRequest, isNotNull);
      expect(
        payload['idempotencyKey'],
        remoteDataSource.createRequest!.idempotencyKey,
      );
    });
    test(
      'initial HTTP 429 respects Retry-After before background sync',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final fence = createLegacyOrderTestFence();
        final local = OrdersLocalDataSource(database, sessionFence: fence);
        final options = RequestOptions(path: '/orders');
        final remote = _FakeRemoteOrdersDataSource(
          createError: DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 429,
              headers: Headers.fromMap({
                'retry-after': ['180'],
              }),
            ),
            type: DioExceptionType.badResponse,
          ),
        );
        final repository = OrdersRepositoryImpl(
          local,
          sessionFence: fence,
          remoteDataSource: remote,
        );
        final before = DateTime.now().toUtc();
        final created = await repository.createOrder(
          CreateOrderRequest(
            supplierIds: const ['supplier-1'],
            items: const [
              OrderItemEntity(
                productId: 'product-1',
                productName: 'Product 1',
                unitPrice: 100,
                quantity: 1,
                supplierId: 'supplier-1',
                supplierName: 'Supplier 1',
              ),
            ],
          ),
        );
        final operations = await database.select(database.syncOperations).get();
        expect(created.id, startsWith('local-order-'));
        expect(operations, hasLength(1));
        expect(operations.single.status, SyncOperationStatuses.retrying);
        expect(operations.single.attempts, 1);
        expect(operations.single.entityId, created.id);
        expect(
          operations.single.nextAttemptAt!.isBefore(
            before.add(const Duration(seconds: 180)),
          ),
          isFalse,
        );
        final payload =
            jsonDecode(operations.single.payloadJson) as Map<String, dynamic>;
        expect(payload['idempotencyKey'], remote.createRequest!.idempotencyKey);
        expect((await local.getOrders()).single.id, created.id);
      },
    );

    test('preserves the local order and Outbox on HTTP 401', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final fence = createLegacyOrderTestFence();
      final local = OrdersLocalDataSource(database, sessionFence: fence);
      final requestOptions = RequestOptions(path: '/orders');
      final remoteError = DioException(
        requestOptions: requestOptions,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );
      final remote = _FakeRemoteOrdersDataSource(createError: remoteError);
      final repository = OrdersRepositoryImpl(
        local,
        sessionFence: fence,
        remoteDataSource: remote,
      );

      await expectLater(
        repository.createOrder(
          CreateOrderRequest(
            supplierIds: const ['supplier-1'],
            items: const [
              OrderItemEntity(
                productId: 'product-1',
                productName: 'Product 1',
                unitPrice: 100,
                quantity: 1,
                supplierId: 'supplier-1',
                supplierName: 'Supplier 1',
              ),
            ],
          ),
        ),
        throwsA(same(remoteError)),
      );

      final orders = await local.getOrders();
      final operations = await database.select(database.syncOperations).get();

      expect(orders, hasLength(1));
      expect(orders.single.id, startsWith('local-order-'));
      expect(operations, hasLength(1));
      expect(operations.single.entityId, orders.single.id);
      expect(operations.single.status, SyncOperationStatuses.pending);
      expect(operations.single.attempts, 0);
      final payload =
          jsonDecode(operations.single.payloadJson) as Map<String, dynamic>;
      expect(payload['idempotencyKey'], remote.createRequest!.idempotencyKey);
    });

    for (final statusCode in <int>[409, 422]) {
      test(
        'retains rejected order as a dead letter on HTTP $statusCode',
        () async {
          final AppDatabase database = AppDatabase.forTesting(
            NativeDatabase.memory(),
          );

          addTearDown(database.close);

          final localDataSource = OrdersLocalDataSource(
            database,
            sessionFence: createLegacyOrderTestFence(),
          );

          final requestOptions = RequestOptions(path: '/orders');

          final remoteError = DioException(
            requestOptions: requestOptions,
            response: Response<dynamic>(
              requestOptions: requestOptions,
              statusCode: statusCode,
              data: <String, dynamic>{'message': 'Order rejected'},
            ),
            type: DioExceptionType.badResponse,
            message: 'Validation failed',
          );

          final remoteDataSource = _FakeRemoteOrdersDataSource(
            createError: remoteError,
          );

          final repository = OrdersRepositoryImpl(
            localDataSource,
            sessionFence: createLegacyOrderTestFence(),
            remoteDataSource: remoteDataSource,
          );

          final request = CreateOrderRequest(
            supplierIds: const ['supplier-1'],
            items: const [
              OrderItemEntity(
                productId: 'product-1',
                productName: 'Product 1',
                unitPrice: 100,
                quantity: 1,
                supplierId: 'supplier-1',
                supplierName: 'Supplier 1',
              ),
            ],
          );

          await expectLater(
            repository.createOrder(request),
            throwsA(same(remoteError)),
          );

          final localOrders = await localDataSource.getOrders();

          final syncOperations = await database
              .select(database.syncOperations)
              .get();

          // Reject the submission without losing the local draft or retrying it.
          expect(localOrders, hasLength(1));
          expect(localOrders.single.id, startsWith('local-order-'));
          expect(localOrders.single.items, hasLength(1));
          expect(syncOperations, hasLength(1));
          final operation = syncOperations.single;
          expect(operation.entityId, localOrders.single.id);
          expect(operation.status, SyncOperationStatuses.permanentFailure);
          expect(operation.attempts, 1);
          expect(operation.lastError, isNotNull);
          expect(operation.nextAttemptAt, isNull);
          final payload =
              jsonDecode(operation.payloadJson) as Map<String, dynamic>;
          expect(
            payload['idempotencyKey'],
            remoteDataSource.createRequest!.idempotencyKey,
          );
        },
      );
    }

    test(
      'does not hide programming failures and keeps durable state',
      () async {
        final AppDatabase database = AppDatabase.forTesting(
          NativeDatabase.memory(),
        );

        addTearDown(database.close);

        final localDataSource = OrdersLocalDataSource(
          database,
          sessionFence: createLegacyOrderTestFence(),
        );

        final remoteError = StateError('Remote create failed');

        final remoteDataSource = _FakeRemoteOrdersDataSource(
          createError: remoteError,
        );

        final repository = OrdersRepositoryImpl(
          localDataSource,
          sessionFence: createLegacyOrderTestFence(),
          remoteDataSource: remoteDataSource,
        );

        final request = CreateOrderRequest(
          supplierIds: const ['supplier-1'],
          items: const [
            OrderItemEntity(
              productId: 'product-1',
              productName: 'Product 1',
              unitPrice: 100,
              quantity: 1,
              supplierId: 'supplier-1',
              supplierName: 'Supplier 1',
            ),
          ],
        );

        await expectLater(
          repository.createOrder(request),
          throwsA(same(remoteError)),
        );

        final localOrders = await localDataSource.getOrders();

        final syncOperations = await database
            .select(database.syncOperations)
            .get();

        expect(localOrders, hasLength(1));
        expect(localOrders.single.id, startsWith('local-order-'));

        expect(syncOperations, hasLength(1));
        expect(syncOperations.single.entityId, localOrders.single.id);

        final payload =
            jsonDecode(syncOperations.single.payloadJson)
                as Map<String, dynamic>;

        expect(remoteDataSource.createRequest, isNotNull);
        expect(
          payload['idempotencyKey'],
          remoteDataSource.createRequest!.idempotencyKey,
        );
      },
    );

    test(
      'supports local-only creation when no remote source is configured',
      () async {
        final AppDatabase database = AppDatabase.forTesting(
          NativeDatabase.memory(),
        );

        addTearDown(database.close);

        final localDataSource = OrdersLocalDataSource(
          database,
          sessionFence: createLegacyOrderTestFence(),
        );

        final repository = OrdersRepositoryImpl(
          localDataSource,
          sessionFence: createLegacyOrderTestFence(),
        );

        final request = CreateOrderRequest(
          supplierIds: const ['supplier-1'],
          items: const [
            OrderItemEntity(
              productId: 'product-1',
              productName: 'Product 1',
              unitPrice: 4500,
              quantity: 2,
              supplierId: 'supplier-1',
              supplierName: 'Supplier 1',
            ),
          ],
        );

        final OrderEntity created = await repository.createOrder(request);

        final List<OrderEntity> orders = await repository.getOrders();

        final syncOperations = await database
            .select(database.syncOperations)
            .get();

        expect(created.status, OrderStatus.pending);
        expect(created.totalQuantity, 2);
        expect(created.totalPrice, 9000);

        expect(created.id, startsWith('local-order-'));

        expect(orders, hasLength(1));
        expect(orders.single.id, created.id);

        // local-only يعني أن الطلب يحتاج مزامنة لاحقًا.
        expect(syncOperations, hasLength(1));

        final operation = syncOperations.single;

        expect(operation.entityType, 'order');
        expect(operation.operation, 'create');
        expect(operation.entityId, created.id);
      },
    );
  });
}

class _FakeRemoteOrdersDataSource implements OrdersDataSource {
  _FakeRemoteOrdersDataSource({this.createdOrder, this.createError});

  final OrderModel? createdOrder;
  final Object? createError;

  CreateOrderModel? createRequest;

  @override
  Future<OrderModel> createOrder(CreateOrderModel request) async {
    createRequest = request;

    final Object? error = createError;

    if (error != null) {
      throw error;
    }

    final OrderModel? order = createdOrder;

    if (order == null) {
      throw StateError('Fake remote order was not configured.');
    }

    return order;
  }

  @override
  Future<List<OrderModel>> getOrders() async {
    final OrderModel? order = createdOrder;

    return order == null ? const <OrderModel>[] : <OrderModel>[order];
  }
}
