import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Transport state is independent of the supplier/business order lifecycle.
enum OrderDeliveryStatus { savedLocally, awaitingRetry, failed, sent, checking }

extension OrderDeliveryStatusPresentation on OrderDeliveryStatus {
  String get label => switch (this) {
    OrderDeliveryStatus.savedLocally => 'محفوظ محليًا — بانتظار الإرسال',
    OrderDeliveryStatus.awaitingRetry => 'بانتظار إعادة الإرسال',
    OrderDeliveryStatus.failed => 'تعذر الإرسال — الطلب محفوظ على الجهاز',
    OrderDeliveryStatus.sent => 'تم الإرسال للخادم',
    OrderDeliveryStatus.checking => 'جارٍ التحقق من حالة الإرسال',
  };
}

/// Watches only this authenticated user's order:create Outbox operations.
/// Drift emits a new snapshot after retry, failure, or successful deletion.
final orderDeliveryOperationsProvider =
    StreamProvider.autoDispose<Map<String, String>>((ref) {
      final authState = ref.watch(
        authProvider.select((controller) => controller.state),
      );
      final ownerUserId = authState.isAuthenticated ? authState.user?.id : null;
      if (ownerUserId == null) {
        return Stream.value(const <String, String>{});
      }

      final database = ref.watch(appDatabaseProvider);
      return (database.select(database.syncOperations)..where(
            (table) =>
                table.entityType.equals('order') &
                table.operation.equals('create') &
                table.ownerUserId.equals(ownerUserId),
          ))
          .watch()
          .map(
            (operations) => Map<String, String>.unmodifiable({
              for (final operation in operations)
                operation.entityId: operation.status,
            }),
          );
    });

/// Never report a temporary local order as sent merely because its Outbox
/// operation is missing or the database stream has not loaded yet.
OrderDeliveryStatus resolveOrderDeliveryStatus(
  String orderId,
  AsyncValue<Map<String, String>> operations,
) {
  if (!orderId.startsWith('local-')) {
    return OrderDeliveryStatus.sent;
  }

  final statuses = operations.asData?.value;
  if (statuses == null) {
    return OrderDeliveryStatus.checking;
  }

  return switch (statuses[orderId]) {
    SyncOperationStatuses.pending => OrderDeliveryStatus.savedLocally,
    SyncOperationStatuses.retrying => OrderDeliveryStatus.awaitingRetry,
    SyncOperationStatuses.permanentFailure => OrderDeliveryStatus.failed,
    _ => OrderDeliveryStatus.checking,
  };
}
