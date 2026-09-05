import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

/// Satu slide banner bernuansa jual-beli/pasar (gradient + ikon commerce).
class CommerceSlide {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const CommerceSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}

/// Carousel banner bernuansa jual-beli/pasar untuk dashboard Okejual.
/// Menggantikan foto gym lama dengan grafik commerce (toko, belanja, pasar)
/// yang digambar langsung oleh Flutter — tidak perlu file gambar eksternal.
class CommerceCarousel extends StatelessWidget {
  final double height;
  final Duration autoPlayDuration;

  const CommerceCarousel({
    super.key,
    this.height = 200,
    this.autoPlayDuration = const Duration(seconds: 3),
  });

  static const List<CommerceSlide> _slides = [
    CommerceSlide(
      icon: Icons.storefront,
      title: 'Jualan Lebih Mudah',
      subtitle: 'Kelola toko & penjualan dalam satu aplikasi',
      gradient: [Color(0xFF267BE4), Color(0xFF6DBAB9)],
    ),
    CommerceSlide(
      icon: Icons.shopping_cart,
      title: 'Belanja Cepat',
      subtitle: 'Transaksi pembeli praktis dan real-time',
      gradient: [Color(0xFFF2994A), Color(0xFFF2C94C)],
    ),
    CommerceSlide(
      icon: Icons.storefront_outlined,
      title: 'Ramaikan Pasar',
      subtitle: 'Semua outlet penjual dalam genggaman',
      gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CarouselSlider(
      options: CarouselOptions(
        height: height,
        autoPlay: true,
        autoPlayInterval: autoPlayDuration,
        enlargeCenterPage: true,
        viewportFraction: 0.9,
      ),
      items: _slides.map((slide) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: slide.gradient,
                ),
              ),
              child: Stack(
                children: [
                  // ikon besar transparan sebagai latar
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Icon(
                      slide.icon,
                      size: 140,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(slide.icon, size: 40, color: Colors.white),
                        const SizedBox(height: 12),
                        Text(
                          slide.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          slide.subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
