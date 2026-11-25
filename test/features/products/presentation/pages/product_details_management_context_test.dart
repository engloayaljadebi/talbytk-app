import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talbytk/features/cart/presentation/controllers/cart_controller.dart';
import 'package:talbytk/features/cart/presentation/providers/cart_provider.dart';
import 'package:talbytk/features/products/domain/entities/products_entity.dart';
import 'package:talbytk/features/products/presentation/pages/product_details_page.dart';
import 'package:talbytk/features/supplier_follow/domain/repositories/supplier_follow_repository.dart';
import 'package:talbytk/features/supplier_follow/presentation/providers/supplier_follow_provider.dart';

void main() {
  testWidgets('matching managed Business exposes Product management', (
    tester,
  ) async {
    final container = _createContainer();

    addTearDown(container.dispose);

    const product = ProductEntity(
      id: 'managed-1',
      supplierId: 'business-1',
      supplierName: 'Managed Supplier',
      name: 'Managed Product',
      price: 100,
      imageUrl: '',
      category: 'Tests',
      brand: 'Talbytk',
      isAvailable: true,
      serverVersion: 3,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProductDetailsPage(
            product: product,
            managedBusinessId: 'business-1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byTooltip('إدارة المنتج'), findsOneWidget);
  });

  testWidgets('public Product details do not expose supplier management', (
    tester,
  ) async {
    final container = _createContainer();

    addTearDown(container.dispose);

    const product = ProductEntity(
      id: 'public-1',
      supplierId: 'business-1',
      supplierName: 'Managed Supplier',
      name: 'Public Product',
      price: 100,
      imageUrl: '',
      category: 'Tests',
      brand: 'Talbytk',
      isAvailable: true,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProductDetailsPage(product: product)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byTooltip('إدارة المنتج'), findsNothing);
  });

  testWidgets(
    'public details stay safe even when supplierId matches a real Business ID',
    (tester) async {
      final container = _createContainer();

      addTearDown(container.dispose);

      const product = ProductEntity(
        id: 'public-business-match',
        supplierId: 'real-business-1',
        supplierName: 'Managed Supplier',
        name: 'Public Product',
        price: 100,
        imageUrl: '',
        category: 'Tests',
        brand: 'Talbytk',
        isAvailable: true,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProductDetailsPage(product: product)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip('إدارة المنتج'), findsNothing);
      expect(find.text('Public Product'), findsOneWidget);
    },
  );
}

ProviderContainer _createContainer() {
  return ProviderContainer(
    overrides: [
      supplierFollowRepositoryProvider.overrideWithValue(
        _FakeSupplierFollowRepository(),
      ),
      cartProvider.overrideWith((ref) => CartController()),
    ],
  );
}

final class _FakeSupplierFollowRepository implements SupplierFollowRepository {
  @override
  Future<bool> isFollowing(String businessId) async => false;

  @override
  Future<bool> follow(String businessId) async => true;

  @override
  Future<bool> unfollow(String businessId) async => false;
}
