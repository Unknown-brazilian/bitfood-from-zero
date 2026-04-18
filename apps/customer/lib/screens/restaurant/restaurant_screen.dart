import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../models/cart_model.dart';
import '../../services/queries.dart';

class RestaurantScreen extends StatefulWidget {
  final String restaurantId;
  const RestaurantScreen({super.key, required this.restaurantId});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(restaurantQuery),
        variables: {'id': widget.restaurantId},
      ),
      builder: (result, {fetchMore, refetch}) {
        if (result.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Carregando...')),
            body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (result.hasException) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(result.exception.toString())),
          );
        }

        final r = result.data!['restaurant'];
        final categories = (r['categories'] as List?) ?? [];
        if (_selectedCategory == null && categories.isNotEmpty) {
          _selectedCategory = categories[0]['_id'];
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Header image
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.cardWhite,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.arrow_back, color: AppColors.textDark, size: 20),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: r['image'] != null
                      ? CachedNetworkImage(imageUrl: r['image'], fit: BoxFit.cover)
                      : Container(color: const Color(0xFFFF6900)),
                ),
              ),

              // Restaurant info
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.cardWhite,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      Text(
                        (r['cuisines'] as List?)?.join(' · ') ?? r['shopType'] ?? '',
                        style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _chip(Icons.star, '${(r['reviewData']?['rating'] ?? 0.0).toStringAsFixed(1)}', const Color(0xFFFFA500)),
                          const SizedBox(width: 12),
                          _chip(Icons.access_time, '${r['deliveryTime'] ?? 30} min', AppColors.textGrey),
                          const SizedBox(width: 12),
                          _chip(Icons.electric_bolt, '${r['zone']?['deliveryFee'] ?? 0} sats', AppColors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Category tabs
              if (categories.isNotEmpty)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CategoryTabDelegate(
                    categories: categories,
                    selectedId: _selectedCategory,
                    onSelect: (id) => setState(() => _selectedCategory = id),
                  ),
                ),

              // Foods
              ...categories.where((c) => _selectedCategory == null || c['_id'] == _selectedCategory).map((cat) {
                final foods = (cat['foods'] as List?)?.where((f) => f['isActive'] == true).toList() ?? [];
                return SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: foods.map((food) => _FoodItem(
                      food: food,
                      restaurantId: r['_id'],
                      restaurantName: r['name'],
                      deliveryFee: r['zone']?['deliveryFee'] ?? 0,
                    )).toList(),
                  ),
                );
              }).toList(),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _CategoryTabDelegate extends SliverPersistentHeaderDelegate {
  final List categories;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _CategoryTabDelegate({required this.categories, required this.selectedId, required this.onSelect});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.cardWhite,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = categories[i];
          final selected = c['_id'] == selectedId;
          return GestureDetector(
            onTap: () => onSelect(c['_id']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
              ),
              child: Text(c['title'], style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : AppColors.textGrey,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              )),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(_CategoryTabDelegate old) => old.selectedId != selectedId;
}

class _FoodItem extends StatelessWidget {
  final Map<String, dynamic> food;
  final String restaurantId;
  final String restaurantName;
  final int deliveryFee;

  const _FoodItem({
    required this.food,
    required this.restaurantId,
    required this.restaurantName,
    required this.deliveryFee,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartModel>();
    final price = food['priceSats'] as int? ?? (food['variations'] as List?)?.firstOrNull?['price'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 1),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                if (food['description'] != null) ...[
                  const SizedBox(height: 3),
                  Text(food['description'], style: const TextStyle(fontSize: 12, color: AppColors.textGrey), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.electric_bolt, color: AppColors.orange, size: 13),
                    const SizedBox(width: 2),
                    Text('$price sats', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Image + add button
          SizedBox(
            width: 90,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: food['image'] != null
                      ? CachedNetworkImage(imageUrl: food['image'], width: 90, height: 80, fit: BoxFit.cover)
                      : Container(width: 90, height: 80, color: const Color(0xFFF0F0F0),
                          child: const Icon(Icons.fastfood, color: AppColors.textLight, size: 32)),
                ),
                Positioned(
                  bottom: -8, right: -4,
                  child: GestureDetector(
                    onTap: () {
                      cart.addItem(
                        CartItem(foodId: food['_id'], title: food['title'], image: food['image'], quantity: 1, unitPrice: price),
                        restaurantId,
                        restaurantName,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${food['title']} adicionado'),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    child: Container(
                      width: 32, height: 32,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
