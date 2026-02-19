import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class ImageCarousel extends StatelessWidget {
  final List<String> images;
  final double height;
  final Duration autoPlayDuration;

  const ImageCarousel({
    super.key,
    required this.images,
    this.height = 200,
    this.autoPlayDuration = const Duration(seconds: 3),
  });

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
      items: images.map((imagePath) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) {
                    // Fallback to placeholder
                  },
                ),
              ),
              child: imagePath.isEmpty
                  ? const Center(
                      child: Icon(Icons.image, size: 50, color: Colors.grey),
                    )
                  : null,
            );
          },
        );
      }).toList(),
    );
  }
}
