import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/cart_model.dart';
import '../../services/queries.dart';
import '../../widgets/restaurant_card.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/sats_chip.dart';
import '../../widgets/status_banner.dart';
import '../restaurant/restaurant_screen.dart';
import '../cart/cart_screen.dart';
import '../order/orders_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String _search = '';

  final List<String> _cuisines = [
    'Todos', 'Pizza', 'Hambúrguer', 'Japonesa', 'Brasileira',
    'Saudável', 'Árabe', 'Italiana', 'Mexicana',
  ];
  String _selectedCuisine = 'Todos';

  @override
  Widget build(BuildContext context) {
    final cartModel = context.watch<CartModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const StatusBanner(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _buildRestaurantsTab(cartModel),
                const OrdersScreen(),
                const ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textLight,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Início'),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: false,
                child: const Icon(Icons.receipt_long_outlined),
              ),
              activeIcon: const Icon(Icons.receipt_long),
              label: 'Pedidos',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
      floatingActionButton: cartModel.itemCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.shopping_bag, color: Colors.white),
              label: Text(
                '${cartModel.itemCount} · ${cartModel.totalSats.toLocaleString()} sats',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  Widget _buildRestaurantsTab(CartModel cart) {
    return CustomScrollView(
      slivers: [
        // App bar
        SliverAppBar(
          backgroundColor: AppColors.cardWhite,
          elevation: 0,
          pinned: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Olá! 👋', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const Text('Para onde vamos hoje?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ],
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: SatsChip(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SearchBarWidget(
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
          ),
        ),

        // Cuisine chips
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: _cuisines.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _cuisines[i];
                final selected = c == _selectedCuisine;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCuisine = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
                    ),
                    child: Text(c, style: TextStyle(
                      color: selected ? Colors.white : AppColors.textGrey,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    )),
                  ),
                );
              },
            ),
          ),
        ),

        // Restaurant list
        Query(
          options: QueryOptions(
            document: gql(restaurantsQuery),
            variables: { 'search': _search.isNotEmpty ? _search : null },
          ),
          builder: (result, {fetchMore, refetch}) {
            if (result.isLoading) {
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => const _ShimmerCard(),
                  childCount: 6,
                ),
              );
            }
            if (result.hasException) {
              return SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(result.exception.toString(), style: const TextStyle(color: AppColors.textGrey)),
                )),
              );
            }
            final restaurants = (result.data?['restaurants'] as List?) ?? [];
            final filtered = _selectedCuisine == 'Todos'
                ? restaurants
                : restaurants.where((r) => (r['cuisines'] as List?)?.contains(_selectedCuisine) == true).toList();

            if (filtered.isEmpty) {
              return const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Nenhum restaurante encontrado', style: TextStyle(color: AppColors.textGrey)),
                )),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => RestaurantCard(
                    restaurant: filtered[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RestaurantScreen(restaurantId: filtered[i]['_id'])),
                    ),
                  ),
                  childCount: filtered.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.shimmer,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

extension on int {
  String toLocaleString() {
    return toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    );
  }
}
