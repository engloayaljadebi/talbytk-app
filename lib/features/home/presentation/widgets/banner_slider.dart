import 'dart:async';

import 'package:flutter/material.dart';

class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key, required this.onExploreProducts});

  final VoidCallback onExploreProducts;

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  static const _pageCount = 3;
  static const _imageUrl =
      'https://yemenmobile.com.ye/uploads/images/202410/image_753x_67183d0a346a0.webp';

  static const _imageUrl3 =
      'https://yemenmobile.com.ye/uploads/images/202410/image_753x_67183ca456e19.webp';

  final PageController _pageController = PageController();

  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }

      final nextPage = (_currentPage + 1) % _pageCount;

      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _currentPage == 0
        ? Colors.white
        : const Color(0xFF9B1B37);

    final inactiveColor = _currentPage == 0
        ? const Color(0x99FFFFFF)
        : const Color(0x559B1B37);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: SizedBox(
          height: 142,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView(
                  key: const ValueKey('home-ad-page-view'),
                  controller: _pageController,
                  onPageChanged: (index) {
                    if (!mounted) return;
                    setState(() => _currentPage = index);
                  },
                  children: [
                    _ProductsBannerSlide(
                      onExploreProducts: widget.onExploreProducts,
                    ),
                    const _YemenMobileBannerSlide(imageUrl: _imageUrl),
                    const _YemenMobileBannerSlide(imageUrl: _imageUrl3),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 7,
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pageCount,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: _currentPage == index ? 17 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? activeColor
                                : inactiveColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductsBannerSlide extends StatelessWidget {
  const _ProductsBannerSlide({required this.onExploreProducts});

  final VoidCallback onExploreProducts;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE53935),
      child: InkWell(
        onTap: onExploreProducts,
        child: SizedBox.expand(
          child: Stack(
            children: [
              PositionedDirectional(
                start: 18,
                top: 23,
                bottom: 18,
                child: SizedBox(
                  width: 175,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اكتشف المنتجات المتاحة لمتجرك',
                        textAlign: TextAlign.start,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.4,
                            ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton(
                          onPressed: onExploreProducts,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 35),
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFE53935),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'استكشف المنتجات',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                end: 18,
                top: 18,
                bottom: 18,
                child: Opacity(
                  opacity: 0.96,
                  child: Image.asset(
                    'assets/icon/logo.png',
                    width: 82,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.storefront_outlined,
                      size: 52,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YemenMobileBannerSlide extends StatelessWidget {
  const _YemenMobileBannerSlide({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PositionedDirectional(
            start: 18,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'يمن موبايل',
                    style: TextStyle(
                      color: Color(0xFF9B1B37),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'إعلان',
                    style: TextStyle(color: Color(0xFF777777), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            end: 8,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 130,
              child: Image.network(
                imageUrl,
                key: ValueKey(imageUrl),
                fit: BoxFit.contain,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.image_not_supported_outlined,
                  color: Color(0xFF9B1B37),
                  size: 45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
