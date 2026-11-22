import '../../domain/entities/orders_entity.dart';

/// حالة واجهة الطلبات.
///
/// تحتوي على:
/// - قائمة الطلبيات.
/// - حالة التحميل.
/// - حالة إرسال طلبية جديدة.
/// - معرّف الطلبية التي يتم تحديث حالتها.
/// - رسالة الخطأ.
/// - آخر طلبية تم إنشاؤها.
class OrdersState {
  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.isLoadingMore = false,
    this.hasMoreOrders = false,
    this.nextPage = 1,
    this.loadMoreErrorMessage,
    this.errorMessage,
    this.lastCreatedOrder,
  });

  /// جميع الطلبيات الحالية.
  final List<OrderEntity> orders;

  /// هل يتم تحميل قائمة الطلبيات؟
  final bool isLoading;

  /// هل يتم إرسال طلبية جديدة؟
  final bool isSubmitting;

  final bool isLoadingMore;
  final bool hasMoreOrders;
  final int nextPage;
  final String? loadMoreErrorMessage;

  /// معرّف الطلبية التي يتم تحديث حالتها حاليًا.
  ///
  /// تكون القيمة null عندما لا توجد عملية تحديث.

  /// رسالة الخطأ الحالية.
  final String? errorMessage;

  /// آخر طلبية تم إنشاؤها.
  final OrderEntity? lastCreatedOrder;

  /// هل توجد عملية تحديث لحالة طلبية؟
  /// إنشاء نسخة جديدة من الحالة مع تعديل القيم المطلوبة فقط.
  OrdersState copyWith({
    List<OrderEntity>? orders,
    bool? isLoading,
    bool? isSubmitting,
    bool? isLoadingMore,
    bool? hasMoreOrders,
    int? nextPage,
    String? loadMoreErrorMessage,
    bool clearLoadMoreErrorMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    OrderEntity? lastCreatedOrder,
    bool clearLastCreatedOrder = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreOrders: hasMoreOrders ?? this.hasMoreOrders,
      nextPage: nextPage ?? this.nextPage,
      loadMoreErrorMessage: clearLoadMoreErrorMessage
          ? null
          : loadMoreErrorMessage ?? this.loadMoreErrorMessage,

      // حذف معرّف الطلبية بعد انتهاء عملية التحديث.
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,

      // حذف آخر طلبية عند بدء عملية إنشاء جديدة.
      lastCreatedOrder: clearLastCreatedOrder
          ? null
          : lastCreatedOrder ?? this.lastCreatedOrder,
    );
  }
}
