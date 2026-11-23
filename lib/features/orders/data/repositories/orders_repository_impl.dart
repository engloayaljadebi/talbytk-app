import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/entities/orders_entity.dart';
import '../../../auth/domain/services/account_session_fence.dart';
import '../../domain/repositories/orders_repository.dart';
import '../../domain/repositories/orders_paginated_reader.dart';
import '../datasources/local/orders_local_datasource.dart';
import '../datasources/orders_datasource.dart';
import '../datasources/remote/orders_remote_datasource.dart';
import '../mappers/orders_mapper.dart';
import '../models/orders_model.dart';
import '../sync/order_retry_policy.dart';
import 'package:uuid/uuid.dart';

class OrdersRepositoryImpl
    implements OrdersRepository, OrdersPaginatedReader, OrdersCachedPageReader {
  OrdersRepositoryImpl(
    this.localDataSource, {
    required this._sessionFence,
    this.remoteDataSource,
  });

  final OrdersLocalDataSource localDataSource;
  final OrdersDataSource? remoteDataSource;
  final AccountSessionFence _sessionFence;

  bool _usingLocalPaging = false;
  int _pagingEpoch = 0;
  int _nextPage = 1;
  int? _expectedTotal;
  int? _expectedLastPage;
  final List<OrderModel> _serverPageBuffer = <OrderModel>[];
  final Set<String> _serverSeenIds = <String>{};

  @override
  Future<OrdersPageSlice<OrderEntity>> getCachedOrdersPage({
    required int page,
  }) async {
    final lease = _sessionFence.capture();
    lease.ensureCurrent();
    final result = await localDataSource.getOrdersPage(page: page);
    lease.ensureCurrent();
    return OrdersPageSlice<OrderEntity>(
      items: List<OrderEntity>.unmodifiable(
        result.items.map(OrdersMapper.toEntity),
      ),
      page: result.page,
      lastPage: result.lastPage,
      total: result.total,
    );
  }

  /// Fetch one page, never reconcile a partial server snapshot as complete.
  @override
  Future<OrdersPageSlice<OrderEntity>> getOrdersPage({
    required int page,
  }) async {
    if (page < 1) throw ArgumentError.value(page, 'page');
    final lease = _sessionFence.capture();
    if (page == 1) {
      _pagingEpoch++;
      _nextPage = 1;
      _usingLocalPaging = false;
      _expectedTotal = null;
      _expectedLastPage = null;
      _serverPageBuffer.clear();
      _serverSeenIds.clear();
    }
    final epoch = _pagingEpoch;
    if (page != _nextPage) {
      throw StateError('Orders pages must be requested sequentially.');
    }

    final remote = remoteDataSource;
    if (remote is! OrdersRemoteDataSource || _usingLocalPaging) {
      return _readLocalPage(page, lease, epoch);
    }

    try {
      lease.ensureCurrent();
      final result = await remote.getOrdersPage(page: page);
      lease.ensureCurrent();
      if (epoch != _pagingEpoch) {
        throw StateError('Orders refresh superseded by a newer refresh.');
      }
      if (_expectedTotal != null &&
          (_expectedTotal != result.total ||
              _expectedLastPage != result.lastPage)) {
        throw const FormatException('Orders pagination changed mid-refresh.');
      }
      final newIds = <String>{};
      for (final order in result.items) {
        if (_serverSeenIds.contains(order.id) || !newIds.add(order.id)) {
          throw const FormatException('Duplicate order across pages.');
        }
      }
      final candidate = [..._serverPageBuffer, ...result.items];

      final pending = page == 1
          ? await localDataSource.getPendingCreateOrders()
          : const <OrderModel>[];
      lease.ensureCurrent();
      if (epoch != _pagingEpoch) {
        throw StateError('Orders refresh superseded by a newer refresh.');
      }
      if (!result.hasMore) {
        if (candidate.length != result.total) {
          throw const FormatException('Incomplete orders pagination snapshot.');
        }
        lease.ensureCurrent();
        await localDataSource.replaceServerSnapshotPreservingPendingCreates(
          List<OrderModel>.unmodifiable(candidate),
        );
        lease.ensureCurrent();
      }
      _expectedTotal ??= result.total;
      _expectedLastPage ??= result.lastPage;
      _serverSeenIds.addAll(newIds);
      _serverPageBuffer.addAll(result.items);
      _nextPage = page + 1;
      lease.ensureCurrent();
      if (epoch != _pagingEpoch) {
        throw StateError('Orders refresh superseded by a newer refresh.');
      }
      final pageIds = result.items.map((item) => item.id).toSet();
      return OrdersPageSlice<OrderEntity>(
        items: List<OrderEntity>.unmodifiable([
          ...pending
              .where((item) => !pageIds.contains(item.id))
              .map(OrdersMapper.toEntity),
          ...result.items.map(OrdersMapper.toEntity),
        ]),
        page: page,
        lastPage: result.lastPage,
        total: result.total,
      );
    } catch (error) {
      lease.ensureCurrent();
      if (epoch != _pagingEpoch) rethrow;
      if (page == 1 && _shouldUseLocalReadFallback(error)) {
        _usingLocalPaging = true;
        return _readLocalPage(page, lease, epoch);
      }
      rethrow;
    }
  }

  Future<OrdersPageSlice<OrderEntity>> _readLocalPage(
    int page,
    AccountSessionLease lease,
    int epoch,
  ) async {
    lease.ensureCurrent();
    final result = await localDataSource.getOrdersPage(page: page);
    lease.ensureCurrent();
    if (epoch != _pagingEpoch) {
      throw StateError('Orders refresh superseded by a newer refresh.');
    }
    _nextPage = page + 1;
    return OrdersPageSlice<OrderEntity>(
      items: List<OrderEntity>.unmodifiable(
        result.items.map(OrdersMapper.toEntity),
      ),
      page: result.page,
      lastPage: result.lastPage,
      total: result.total,
    );
  }

  @override
  Future<List<OrderEntity>> getOrders() async {
    final lease = _sessionFence.capture();
    final remote = remoteDataSource;

    if (remote != null) {
      try {
        lease.ensureCurrent();

        final remoteOrders = await remote.getOrders();

        lease.ensureCurrent();

        await localDataSource.replaceServerSnapshotPreservingPendingCreates(
          remoteOrders,
        );

        lease.ensureCurrent();
      } catch (error) {
        lease.ensureCurrent();

        if (!_shouldUseLocalReadFallback(error)) {
          rethrow;
        }
      }
    }

    lease.ensureCurrent();

    final models = await localDataSource.getOrders();

    lease.ensureCurrent();

    return List<OrderEntity>.unmodifiable(models.map(OrdersMapper.toEntity));
  }

  @override
  Future<OrderEntity> createOrder(CreateOrderRequest request) async {
    final lease = _sessionFence.capture();

    final CreateOrderModel createModel = OrdersMapper.toCreateModel(
      request,
    ).copyWith(idempotencyKey: Uuid().v4());

    lease.ensureCurrent();

    // Durable local Order + Outbox before attempting the network.
    final localOrder = await localDataSource.createOrder(createModel);

    // An account switch here must prevent the first remote attempt.
    lease.ensureCurrent();

    final remote = remoteDataSource;

    if (remote == null) {
      lease.ensureCurrent();
      return OrdersMapper.toEntity(localOrder);
    }

    final operationId = 'order:create:${localOrder.id}';

    late final OrderModel remoteOrder;

    try {
      lease.ensureCurrent();

      remoteOrder = await remote.createOrder(createModel);

      lease.ensureCurrent();
    } catch (error) {
      // Invalidation must never become an offline success result.
      lease.ensureCurrent();

      if (_shouldRemainQueued(error)) {
        // The first foreground attempt is also subject to Retry-After.
        // Otherwise the periodic outbox worker could immediately retry a 429.
        if (error is DioException &&
            (error.response?.statusCode == 429 ||
                error.response?.statusCode == 503)) {
          try {
            await localDataSource.markCreateSyncRetry(
              operationId: operationId,
              attempts: 1,
              error: error,
              nextAttemptAt: OrderRetryPolicy.nextAttemptAt(
                error: error,
                attempts: 1,
              ),
            );
          } catch (_) {
            // The durable pending operation already exists. A failed retry
            // metadata update must not lose it or hide a session switch.
            lease.ensureCurrent();
          }
          lease.ensureCurrent();
        }
        return OrdersMapper.toEntity(localOrder);
      }

      if (_isDefinitiveRemoteRejection(error)) {
        // A rejected request is not an offline success, but deleting the
        // durable draft loses the customer's items and recipient selection.
        // Keep the Outbox as a non-retryable dead letter for inspection.
        await localDataSource.markCreateSyncPermanentFailure(
          operationId: operationId,
          attempts: 1,
          error: error,
        );

        lease.ensureCurrent();
      }

      // Preserve local state for unknown or ambiguous outcomes.
      rethrow;
    }

    try {
      lease.ensureCurrent();

      await localDataSource.completeCreateSync(
        localOrderId: localOrder.id,
        operationId: operationId,
        remoteOrder: remoteOrder,
      );

      lease.ensureCurrent();

      return OrdersMapper.toEntity(remoteOrder);
    } catch (_) {
      // Preserve idempotent replay for a reconciliation failure,
      // but do not hide a change of authenticated account.
      lease.ensureCurrent();

      return OrdersMapper.toEntity(localOrder);
    }
  }

  bool _shouldUseLocalReadFallback(Object error) {
    if (_isConnectivityFailure(error)) {
      return true;
    }

    if (error is! DioException || error.type != DioExceptionType.badResponse) {
      return false;
    }

    final int? statusCode = error.response?.statusCode;

    if (statusCode == null) {
      return false;
    }

    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  bool _shouldRemainQueued(Object error) {
    if (_isConnectivityFailure(error)) {
      return true;
    }

    if (error is! DioException || error.type != DioExceptionType.badResponse) {
      return false;
    }

    final int? statusCode = error.response?.statusCode;

    if (statusCode == null) {
      return false;
    }

    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  bool _isDefinitiveRemoteRejection(Object error) {
    if (error is! DioException || error.type != DioExceptionType.badResponse) {
      return false;
    }

    final int? statusCode = error.response?.statusCode;

    if (statusCode == null) {
      return false;
    }

    // Authentication expiry is not a definitive rejection of the order.
    // Preserve its durable Outbox operation for replay after re-authentication.
    return statusCode >= 400 &&
        statusCode < 500 &&
        statusCode != 401 &&
        statusCode != 408 &&
        statusCode != 429;
  }

  bool _isConnectivityFailure(Object error) {
    if (error is! DioException) {
      return false;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;

      case DioExceptionType.unknown:
        return error.error is SocketException;

      default:
        return false;
    }
  }
}
