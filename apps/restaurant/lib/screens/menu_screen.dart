import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../theme.dart';
import '../queries.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(document: gql(myRestaurantQuery), fetchPolicy: FetchPolicy.cacheAndNetwork),
      builder: (result, {fetchMore, refetch}) {
        final categories = (result.data?['myRestaurant']?['categories'] as List?) ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {},
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Adicionar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          body: RefreshIndicator(
            onRefresh: () async => refetch!(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Cardápio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 16),
                ...categories.map((cat) => _CategorySection(category: cat)),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  final Map<String, dynamic> category;
  const _CategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    final foods = (category['foods'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(category['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        ),
        ...foods.map((food) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    Row(children: [
                      const Icon(Icons.electric_bolt, color: AppColors.orange, size: 13),
                      const SizedBox(width: 2),
                      Text('${food['priceSats'] ?? 0} sats', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ]),
                  ],
                ),
              ),
              Switch(
                value: food['isActive'] == true,
                onChanged: (_) {},
                activeColor: AppColors.primary,
              ),
            ],
          ),
        )),
        const SizedBox(height: 8),
      ],
    );
  }
}
