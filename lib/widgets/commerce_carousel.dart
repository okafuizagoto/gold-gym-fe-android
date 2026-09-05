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
                borderRadius: BorderRadius.circular(16),
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
                  // FittedBox: kalau slide dipersempit (HP landscape /
                  // enlargeCenterPage mengecilkan slide samping), isi
                  // diskalakan turun alih-alih meluap ke bawah.
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: LayoutBuilder(
                      builder: (context, constraints) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(slide.icon,
                                  size: height < 170 ? 30 : 40,
                                  color: Colors.white),
                              SizedBox(height: height < 170 ? 6 : 12),
                              Text(
                                slide.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: height < 170 ? 18 : 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                slide.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
