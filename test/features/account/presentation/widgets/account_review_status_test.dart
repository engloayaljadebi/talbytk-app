import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talbytk/features/account/presentation/providers/account_business_approvals_provider.dart';
import 'package:talbytk/features/account/presentation/widgets/account_review_status.dart';

Widget _host(Widget child, {TextDirection direction = TextDirection.rtl}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

const _pendingShopApprovedSupplier = AccountBusinessApproval(
  businessId: 'b1',
  shopStatus: 'pending',
  supplierStatus: 'approved',
  supplierEnabled: true,
);

void main() {
  group('ProfileEditIconButton', () {
    testWidgets('is icon-only, labelled, 48x48 and calls onPressed', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(_host(ProfileEditIconButton(onPressed: () => taps++)));

      expect(find.byTooltip('تعديل الملف الشخصي'), findsOneWidget);
      expect(find.text('تعديل الملف الشخصي'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byType(IconButton));
      expect(taps, 1);
    });
  });

  group('ReviewStatusBar', () {
    testWidgets('shows both roles and refreshes once per tap', (tester) async {
      var refreshes = 0;
      await tester.pumpWidget(
        _host(
          ReviewStatusBar(
            approval: _pendingShopApprovedSupplier,
            isLoading: false,
            hasError: false,
            onRefresh: () => refreshes++,
          ),
        ),
      );

      expect(find.text('العميل: قيد المراجعة'), findsOneWidget);
      expect(find.text('المورد: تمت الموافقة'), findsOneWidget);
      // The long text button is gone; only the icon remains.
      expect(find.text('تحديث حالة المراجعة'), findsNothing);
      expect(find.byTooltip('تحديث حالة المراجعة'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('account-review-refresh')));
      expect(refreshes, 1);
    });

    testWidgets('loading shows an indicator and blocks repeated requests', (
      tester,
    ) async {
      var refreshes = 0;
      await tester.pumpWidget(
        _host(
          ReviewStatusBar(
            approval: _pendingShopApprovedSupplier,
            isLoading: true,
            hasError: false,
            onRefresh: () => refreshes++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('account-review-refresh')), findsNothing);
      // Status stays visible while refreshing.
      expect(find.text('المورد: تمت الموافقة'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('account-review-refresh-loading')),
        warnIfMissed: false,
      );
      expect(refreshes, 0);
    });

    testWidgets('error shows a message and keeps refresh available', (
      tester,
    ) async {
      var refreshes = 0;
      await tester.pumpWidget(
        _host(
          ReviewStatusBar(
            approval: null,
            isLoading: false,
            hasError: true,
            onRefresh: () => refreshes++,
          ),
        ),
      );

      expect(
        find.text('تعذر تحديث حالة المراجعة. حاول مجددًا.'),
        findsOneWidget,
      );
      expect(find.text('لا يوجد طلب اعتماد مسجل'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('account-review-refresh')));
      expect(refreshes, 1);
    });

    testWidgets('empty approval shows the no-request message', (tester) async {
      await tester.pumpWidget(
        _host(
          ReviewStatusBar(
            approval: null,
            isLoading: false,
            hasError: false,
            onRefresh: () {},
          ),
        ),
      );

      expect(find.text('لا يوجد طلب اعتماد مسجل'), findsOneWidget);
    });

    testWidgets('null onRefresh disables the refresh action', (tester) async {
      await tester.pumpWidget(
        _host(
          const ReviewStatusBar(
            approval: null,
            isLoading: false,
            hasError: false,
            onRefresh: null,
          ),
        ),
      );

      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull);
    });

    for (final entry in <String, String>{
      'pending': 'قيد المراجعة',
      'approved': 'تمت الموافقة',
      'rejected': 'مرفوض',
      'revoked': 'تم إلغاء الاعتماد',
      'expired': 'منتهي الصلاحية',
      'something_else': 'حالة غير معروفة',
    }.entries) {
      testWidgets('chip label for ${entry.key}', (tester) async {
        await tester.pumpWidget(
          _host(ReviewStatusChip(roleLabel: 'المورد', status: entry.key)),
        );

        expect(find.text('المورد: ${entry.value}'), findsOneWidget);
      });
    }

    for (final dark in <bool>[false, true]) {
      testWidgets('no overflow at 320dp in RTL (dark: $dark)', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ReviewStatusBar(
                    approval: _pendingShopApprovedSupplier,
                    isLoading: false,
                    hasError: true,
                    onRefresh: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
