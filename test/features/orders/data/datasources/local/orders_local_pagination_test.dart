import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talbytk/core/database/app_database.dart';
import 'package:talbytk/features/orders/data/datasources/local/orders_local_datasource.dart';
import 'package:talbytk/features/orders/data/models/orders_model.dart';
import '../../../../../support/legacy_order_test_fence.dart';

void main() {
  test('local pagination returns 20 then 1 without deleting history', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final local = OrdersLocalDataSource(
      database,
      sessionFence: createLegacyOrderTestFence(),
    );
    for (var i = 0; i < 21; i++) {
      await local.saveOrder(
        OrderModel(
          id: 'order-$i',
          status: 'pending',
          items: const [],
          createdAt: DateTime.utc(2026, 11, 1).add(Duration(seconds: i)),
        ),
      );
    }
    final first = await local.getOrdersPage(page: 1);
    final second = await local.getOrdersPage(page: 2);
    expect(first.items, hasLength(20));
    expect(second.items, hasLength(1));
    expect(first.total, 21);
    expect(first.hasMore, isTrue);
    expect(second.hasMore, isFalse);
    expect(
      [...first.items, ...second.items].map((o) => o.id).toSet(),
      hasLength(21),
    );
    expect(await local.getOrders(), hasLength(21));
  });
}
