import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talbytk/features/home/presentation/widgets/banner_slider.dart';

void main() {
  testWidgets('BannerSlider preserves the products CTA', (tester) async {
    var openedProducts = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BannerSlider(
            onExploreProducts: () {
              openedProducts = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('اكتشف المنتجات المتاحة لمتجرك'), findsOneWidget);

    expect(find.text('استكشف المنتجات'), findsOneWidget);

    await tester.tap(find.text('استكشف المنتجات'));
    await tester.pump();

    expect(openedProducts, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('BannerSlider automatically shows Yemen Mobile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BannerSlider(onExploreProducts: () {})),
      ),
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('يمن موبايل'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'https://yemenmobile.com.ye/uploads/images/202410/image_753x_67183d0a346a0.webp',
        ),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('BannerSlider automatically reaches the third ad', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BannerSlider(onExploreProducts: () {})),
      ),
    );

    // First automatic transition: slide 1 -> slide 2
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 600));

    // Second automatic transition: slide 2 -> slide 3
    await tester.pump(const Duration(milliseconds: 4400));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byKey(
        const ValueKey(
          'https://yemenmobile.com.ye/uploads/images/202410/image_753x_67183ca456e19.webp',
        ),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
