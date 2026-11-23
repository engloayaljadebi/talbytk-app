import 'package:flutter/foundation.dart';

import '../../domain/entities/orders_entity.dart';
import '../../domain/services/order_id_transition_registry.dart';
import '../../domain/usecases/orders_usecase.dart';
import '../state/orders_state.dart';

/// المتحكم المسؤول عن إدارة الطلبيات وحالات واجهتها.
///
/// المهام:
/// - تحميل الطلبيات.
/// - إنشاء طلبية جديدة.
/// - البحث عن طلبية.
/// - تحديث حالة الطلبية عبر طبقات المشروع.
/// - معالجة حالات التحميل والأخطاء.
class OrdersController extends ChangeNotifier {
  OrdersController(
    this._useCase, {
    this.transitionRegistry,
    bool autoLoad = true,
  }) {
    if (autoLoad) {
      loadOrders();
    }
  }

  final OrdersUseCase _useCase;
  final OrderIdTransitionRegistry? transitionRegistry;

  OrdersState state = const OrdersState();
  int _requestGeneration = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    super.dispose();
  }

  /// البحث عن طلبية بواسطة المعرّف مع مراعاة انتقال المعرف المؤقت إلى المعرف النهائي.
  OrderEntity? findOrderById(String orderId) {
    final String effectiveId = transitionRegistry?.resolve(orderId) ?? orderId;

    for (final OrderEntity order in state.orders) {
      if (order.id == effectiveId || order.id == orderId) {
        return order;
      }
    }

    return null;
  }

  /// تحديث حالة الطلبية من خلال:
  ///
  /// Controller → UseCase → Repository → DataSource
  Future<void> loadOrders() async {
    if (_disposed) return;
    final generation = ++_requestGeneration;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearErrorMessage: true,
      clearLoadMoreErrorMessage: true,
    );
    notifyListeners();

    try {
      // Display existing Drift data immediately while page 1 is requested.
      try {
        final cached = await _useCase.getCachedOrdersPage(page: 1);
        if (_disposed || generation != _requestGeneration) return;
        if (cached != null && cached.items.isNotEmpty) {
          state = state.copyWith(
            orders: List<OrderEntity>.unmodifiable(cached.items),
            hasMoreOrders: false,
          );
          notifyListeners();
        }
      } catch (_) {
        if (_disposed || generation != _requestGeneration) return;
        // A cache-read failure must not prevent the remote refresh.
      }
      final page = await _useCase.getOrdersPage(page: 1);
      if (_disposed || generation != _requestGeneration) return;
      state = state.copyWith(
        orders: List<OrderEntity>.unmodifiable(page.items),
        isLoading: false,
        hasMoreOrders: page.hasMore,
        nextPage: 2,
        clearErrorMessage: true,
        clearLoadMoreErrorMessage: true,
      );
    } catch (_) {
      if (_disposed || generation != _requestGeneration) return;
      state = state.copyWith(
        isLoading: false,
        hasMoreOrders: false,
        nextPage: 1,
        errorMessage: 'تعذر تحميل الطلبيات، حاول مرة أخرى',
      );
    }
    notifyListeners();
  }

  Future<void> loadMoreOrders() async {
    if (_disposed ||
        state.isLoading ||
        state.isLoadingMore ||
        !state.hasMoreOrders) {
      return;
    }
    final generation = _requestGeneration;
    final requestedPage = state.nextPage;
    state = state.copyWith(
      isLoadingMore: true,
      clearLoadMoreErrorMessage: true,
    );
    notifyListeners();

    try {
      final page = await _useCase.getOrdersPage(page: requestedPage);
      if (_disposed || generation != _requestGeneration) return;
      if (page.page != requestedPage) {
        throw const FormatException('Unexpected orders page.');
      }
      final ids = state.orders.map((order) => order.id).toSet();
      if (page.items.any((order) => !ids.add(order.id))) {
        throw const FormatException('Duplicate orders across pages.');
      }
      state = state.copyWith(
        orders: List<OrderEntity>.unmodifiable([
          ...state.orders,
          ...page.items,
        ]),
        isLoadingMore: false,
        hasMoreOrders: page.hasMore,
        nextPage: requestedPage + 1,
        clearLoadMoreErrorMessage: true,
      );
    } catch (_) {
      if (_disposed || generation != _requestGeneration) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreErrorMessage: 'تعذر تحميل المزيد من الطلبيات. حاول مرة أخرى.',
      );
    }
    notifyListeners();
  }

  /// إنشاء طلبية جديدة.
  Future<OrderEntity?> createOrder(CreateOrderRequest request) async {
    if (state.isSubmitting) {
      return null;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearErrorMessage: true,
      clearLastCreatedOrder: true,
    );
    notifyListeners();

    try {
      final OrderEntity order = await _useCase.createOrder(request);

      final List<OrderEntity> orders = [
        order,
        ...state.orders.where((OrderEntity item) => item.id != order.id),
      ];

      state = state.copyWith(
        orders: List<OrderEntity>.unmodifiable(orders),
        isSubmitting: false,
        lastCreatedOrder: order,
        clearErrorMessage: true,
      );

      notifyListeners();
      return order;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'تعذر إرسال الطلبية، حاول مرة أخرى',
      );

      notifyListeners();
      return null;
    }
  }
}
