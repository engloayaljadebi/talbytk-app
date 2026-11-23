import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talbytk/features/orders/presentation/providers/order_delivery_status_provider.dart';
import 'package:talbytk/features/orders/presentation/widgets/order_delivery_badge.dart';

void main() {
  const local = 'local-order-123';
  const server = '550e8400-e29b-41d4-a716-446655440000';

  test('maps each durable Outbox status without confusing business state', () {
    expect(
      resolveOrderDeliveryStatus(local, const AsyncData({local: 'pending'})),
      OrderDeliveryStatus.savedLocally,
    );
    expect(
      resolveOrderDeliveryStatus(local, const AsyncData({local: 'retrying'})),
      OrderDeliveryStatus.awaitingRetry,
    );
    expect(
      resolveOrderDeliveryStatus(
        local,
        const AsyncData({local: 'permanent_failure'}),
      ),
      OrderDeliveryStatus.failed,
    );
    expect(
      resolveOrderDeliveryStatus(server, const AsyncData({})),
      OrderDeliveryStatus.sent,
    );
  });

  test('never claims a local order was sent when status is unavailable', () {
    expect(
      resolveOrderDeliveryStatus(local, const AsyncLoading()),
      OrderDeliveryStatus.checking,
    );
    expect(
      resolveOrderDeliveryStatus(local, const AsyncData({})),
      OrderDeliveryStatus.checking,
    );
  });

  testWidgets('permanent failure badge is visible and descriptive', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: OrderDeliveryBadge(status: OrderDeliveryStatus.failed),
          ),
        ),
      ),
    );
    expect(find.text('تعذر الإرسال — الطلب محفوظ على الجهاز'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('order-delivery-failed')),
      findsOneWidget,
    );
  });

  test('labels clearly distinguish local, retry, failure and sent', () {
    expect(OrderDeliveryStatus.savedLocally.label, contains('محفوظ محليًا'));
    expect(OrderDeliveryStatus.awaitingRetry.label, contains('إعادة الإرسال'));
    expect(OrderDeliveryStatus.failed.label, contains('تعذر الإرسال'));
    expect(OrderDeliveryStatus.sent.label, contains('تم الإرسال'));
  });
}
