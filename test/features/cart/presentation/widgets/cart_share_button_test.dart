import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'package:talbytk/features/cart/presentation/controllers/cart_controller.dart';
import 'package:talbytk/features/cart/presentation/providers/cart_provider.dart';
import 'package:talbytk/features/cart/presentation/widgets/cart_share_button.dart';

Future<CartController> createTestCart() async {
  final cart = CartController();

  await cart.ready;

  cart.addManualItem(
    name: 'سكر',
    unitPrice: 1200,
    quantity: 2,
    unit: 'كيس',
    note: 'تسليم عاجل',
  );

  return cart;
}

Future<void> pumpShareButton(
  WidgetTester tester,
  ProviderContainer container,
  CartShareHandler handler,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [CartShareButton(onShare: handler)]),
        ),
      ),
    ),
  );
}

void main() {
  group('CartShareButton integration', () {
    testWidgets('shares Arabic cart text using ShareParams', (tester) async {
      final cart = await createTestCart();

      final container = ProviderContainer(
        overrides: [cartProvider.overrideWith((ref) => cart)],
      );

      addTearDown(container.dispose);

      ShareParams? captured;

      await pumpShareButton(tester, container, (params) async {
        captured = params;

        return const ShareResult('shared', ShareResultStatus.success);
      });

      await tester.tap(find.byTooltip('مشاركة الطلبية'));
      await tester.pumpAndSettle();

      expect(find.text('مشاركة الطلبية'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'مشاركة'));

      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.text, contains('سكر'));
      expect(captured!.text, contains('الكمية: 2'));
      expect(captured!.files, isNull);
      expect(captured!.uri, isNull);
    });

    testWidgets('shares generated PDF with correct MIME and filename', (
      tester,
    ) async {
      final cart = await createTestCart();

      final container = ProviderContainer(
        overrides: [cartProvider.overrideWith((ref) => cart)],
      );

      addTearDown(container.dispose);

      ShareParams? captured;

      await pumpShareButton(tester, container, (params) async {
        captured = params;

        return const ShareResult('shared', ShareResultStatus.success);
      });

      await tester.tap(find.byTooltip('مشاركة الطلبية'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('مشاركة كملف PDF'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'مشاركة'));

      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.files, hasLength(1));

      expect(captured!.fileNameOverrides, ['order-list.pdf']);

      final file = captured!.files!.single;

      expect(file.mimeType, 'application/pdf');

      final bytes = await file.readAsBytes();

      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    });

    testWidgets('shows error when the sharing handler fails', (tester) async {
      final cart = await createTestCart();

      final container = ProviderContainer(
        overrides: [cartProvider.overrideWith((ref) => cart)],
      );

      addTearDown(container.dispose);

      await pumpShareButton(tester, container, (params) async {
        throw StateError('Simulated sharing failure');
      });

      await tester.tap(find.byTooltip('مشاركة الطلبية'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'مشاركة'));

      await tester.pumpAndSettle();

      expect(find.text('تعذر فتح المشاركة. حاول مرة أخرى.'), findsOneWidget);
    });
  });
}
