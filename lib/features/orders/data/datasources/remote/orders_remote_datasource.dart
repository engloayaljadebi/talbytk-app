import 'package:built_collection/built_collection.dart';
import 'package:talbytk_api/talbytk_api.dart';

import '../../../../../core/network/generated_api_client.dart';
import '../../dto/orders_dto.dart';
import '../../mappers/orders_mapper.dart';
import '../../models/orders_model.dart';
import '../../../domain/repositories/orders_paginated_reader.dart';
import '../orders_datasource.dart';

class OrdersRemoteDataSource implements OrdersDataSource {
  const OrdersRemoteDataSource({required this.generatedApiClient});

  final GeneratedApiClient generatedApiClient;

  static const int ordersPerPage = 20;

  /// Fetch exactly one server page; no local data is mutated here.
  Future<OrdersPageSlice<OrderModel>> getOrdersPage({required int page}) async {
    if (page < 1) {
      throw ArgumentError.value(page, 'page', 'Page must be positive.');
    }

    final authExtra = generatedApiClient.captureOrderAuthExtra();
    generatedApiClient.ensureProtectedRequestAuthCurrent(authExtra);

    final response = await generatedApiClient.getJsonAuthenticated(
      path: '/orders?page=$page&per_page=$ordersPerPage',
    );
    generatedApiClient.ensureProtectedRequestAuthCurrent(authExtra);

    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Orders page must be a JSON object.');
    }

    final rawData = payload['data'];
    final rawMeta = payload['meta'];
    if (rawData is! List || rawMeta is! Map<String, dynamic>) {
      throw const FormatException('Orders pagination data/meta missing.');
    }

    final currentPage = rawMeta['current_page'];
    final lastPage = rawMeta['last_page'];
    final perPage = rawMeta['per_page'];
    final total = rawMeta['total'];

    if (currentPage is! int ||
        currentPage != page ||
        lastPage is! int ||
        lastPage < 1 ||
        perPage is! int ||
        perPage != ordersPerPage ||
        total is! int ||
        total < 0 ||
        lastPage != (total == 0 ? 1 : (total + perPage - 1) ~/ perPage)) {
      throw const FormatException('Inconsistent orders pagination meta.');
    }

    final expectedPageCount = page < lastPage
        ? ordersPerPage
        : total - (page - 1) * ordersPerPage;
    if (rawData.length != expectedPageCount) {
      throw const FormatException('Incomplete orders pagination page.');
    }

    final orders = <OrderModel>[];
    final seenIds = <String>{};
    for (final rawOrder in rawData) {
      if (rawOrder is! Map<String, dynamic>) {
        throw const FormatException('Order must be a JSON object.');
      }

      final aggregateStatus = rawOrder['aggregate_status'];
      if (aggregateStatus is! String || aggregateStatus.isEmpty) {
        throw const FormatException('Order aggregate_status missing.');
      }

      final order = OrdersMapper.toModel(
        OrderDto.fromJson(rawOrder),
      ).copyWith(aggregateStatus: aggregateStatus);
      OrdersMapper.toEntity(order); // Reject unknown lifecycle values.
      if (!seenIds.add(order.id)) {
        throw const FormatException('Duplicate order within page.');
      }
      orders.add(order);
    }

    generatedApiClient.ensureProtectedRequestAuthCurrent(authExtra);
    return OrdersPageSlice<OrderModel>(
      items: List<OrderModel>.unmodifiable(orders),
      page: page,
      lastPage: lastPage,
      total: total,
    );
  }

  /// Compatibility path: full snapshots are required by legacy reconciliation.
  @override
  Future<List<OrderModel>> getOrders() async {
    final authExtra = generatedApiClient.captureOrderAuthExtra();
    final orders = <OrderModel>[];
    final seenOrderIds = <String>{};
    int? expectedTotal;
    int? expectedLastPage;

    for (var page = 1; ; page++) {
      generatedApiClient.ensureProtectedRequestAuthCurrent(authExtra);
      final result = await getOrdersPage(page: page);
      generatedApiClient.ensureProtectedRequestAuthCurrent(authExtra);

      if (expectedTotal != null &&
          (expectedTotal != result.total ||
              expectedLastPage != result.lastPage)) {
        throw const FormatException('Orders pagination changed mid-refresh.');
      }
      expectedTotal ??= result.total;
      expectedLastPage ??= result.lastPage;

      for (final order in result.items) {
        if (!seenOrderIds.add(order.id)) {
          throw const FormatException('Duplicate order across pages.');
        }
        orders.add(order);
      }
      if (!result.hasMore) break;
    }

    generatedApiClient.ensureProtectedRequestAuthCurrent(authExtra);
    if (orders.length != expectedTotal) {
      throw const FormatException('Incomplete orders pagination snapshot.');
    }
    return List<OrderModel>.unmodifiable(orders);
  }

  @override
  Future<OrderModel> createOrder(CreateOrderModel request) async {
    final String idempotencyKey = request.idempotencyKey.trim();

    if (idempotencyKey.isEmpty) {
      throw ArgumentError.value(
        request.idempotencyKey,
        'idempotencyKey',
        'Create order requires an idempotency key.',
      );
    }

    final apiRequest = CreateOrderRequest((builder) {
      final notes = request.notes.trim();

      if (notes.isNotEmpty) {
        builder.notes = notes;
      }

      builder.supplierIds.replace(BuiltList<String>(request.supplierIds));

      builder.items.replace(
        BuiltList<CreateOrderRequestItemsInner>(
          request.items.map(
            (item) => CreateOrderRequestItemsInner((itemBuilder) {
              itemBuilder.quantity = item.quantity;

              if (item.isManual) {
                itemBuilder
                  ..itemType = CreateOrderRequestItemsInnerItemTypeEnum.manual
                  ..name = item.productName
                  ..unitPrice = item.unitPrice
                  ..unit = item.unit
                  ..note = item.note;
                return;
              }

              final productId = item.productId;
              final supplierId = item.supplierId;

              if (item.itemType != 'catalog' ||
                  productId == null ||
                  productId.trim().isEmpty ||
                  supplierId == null ||
                  supplierId.trim().isEmpty) {
                throw const FormatException(
                  'A catalog order item requires a product and supplier.',
                );
              }

              // Preserve the catalog request shape for idempotent retries.
              itemBuilder
                ..productId = productId
                ..expectedUnitPrice = item.unitPrice
                ..expectedSupplierId = supplierId;
            }),
          ),
        ),
      );
    });

    final response = await generatedApiClient.orders.orderStore(
      idempotencyKey: idempotencyKey,
      createOrderRequest: apiRequest,
      extra: generatedApiClient.captureOrderAuthExtra(),
    );

    final responseBody = response.data;

    if (responseBody == null) {
      throw StateError('Create order response does not contain data.');
    }

    return _mapOrderResource(responseBody.data);
  }

  OrderModel _mapOrderResource(OrderResource resource) {
    final createdAt = resource.createdAt;

    if (createdAt == null) {
      throw const FormatException(
        'Order response does not contain created_at.',
      );
    }

    return OrderModel(
      id: resource.id,
      status: resource.status,
      aggregateStatus: _aggregateStatusToDataValue(resource.aggregateStatus),
      notes: resource.notes ?? '',
      createdAt: createdAt,
      items: resource.items
          .map(
            (item) => OrderItemModel(
              productId: item.productId,
              productName: item.productName,
              unitPrice: double.parse(item.unitPrice),
              quantity: item.quantity,
              supplierId: item.supplierId,
              supplierName: item.supplierName ?? '',
              imageUrl: item.imageUrl ?? '',
              itemType: item.itemType,
              unit: item.unit,
              note: item.note,
            ),
          )
          .toList(growable: false),
    );
  }

  String _aggregateStatusToDataValue(OrderAggregateStatus status) {
    if (status == OrderAggregateStatus.pendingResponses) {
      return 'pending_responses';
    }

    if (status == OrderAggregateStatus.responsesReceived) {
      return 'responses_received';
    }

    if (status == OrderAggregateStatus.suppliersSelected) {
      return 'suppliers_selected';
    }

    if (status == OrderAggregateStatus.inFulfillment) {
      return 'in_fulfillment';
    }

    if (status == OrderAggregateStatus.partiallyCompleted) {
      return 'partially_completed';
    }

    if (status == OrderAggregateStatus.completed) {
      return 'completed';
    }

    if (status == OrderAggregateStatus.cancelled) {
      return 'cancelled';
    }

    if (status == OrderAggregateStatus.expired) {
      return 'expired';
    }

    throw FormatException(
      'Unsupported generated aggregate order status: $status',
    );
  }
}
