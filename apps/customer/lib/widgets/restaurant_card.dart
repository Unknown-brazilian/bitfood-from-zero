import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final VoidCallback onTap;

  const RestaurantCard({super.key, required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rating = (restaurant['reviewData']?['rating'] ?? 0.0) as num;
    final reviews = restaurant['reviewData']?['reviews'] ?? 0;
    final deliveryFee = restaurant['zone']?['deliveryFee'] ?? 0;
    final isAvailable = restaurant['isAvailable'] == true;

    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  restaurant['image'] != null
                      ? CachedNetworkImage(
                          imageUrl: restaurant['image'],
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(height: 140, color: AppColors.shimmer),
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                  if (!isAvailable)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Text('FECHADO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restaurant['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(
                    (restaurant['cuisines'] as List?)?.join(' · ') ?? restaurant['shopType'] ?? '',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFFA500), size: 14),
                      const SizedBox(width: 2),
                      Text('${rating.toStringAsFixed(1)} ($reviews)', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, color: AppColors.textLight, size: 14),
                      const SizedBox(width: 2),
                      Text('${restaurant['deliveryTime'] ?? 30} min', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      const SizedBox(width: 12),
                      const Icon(Icons.electric_bolt, color: AppColors.orange, size: 14),
                      const SizedBox(width: 2),
                      Text('${_formatSats(deliveryFee)} sats', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        height: 140,
        color: const Color(0xFFF0F0F0),
        child: const Center(child: Icon(Icons.restaurant, color: AppColors.textLight, size: 40)),
      );

  String _formatSats(int sats) {
    return sats.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  }
}
