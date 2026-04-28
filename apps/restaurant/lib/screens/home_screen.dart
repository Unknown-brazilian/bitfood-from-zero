import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../queries.dart';
import 'orders_screen.dart';
import 'earnings_screen.dart';
import 'menu_screen.dart';
import 'profile_screen.dart';
import '../widgets/sats_chip.dart';
import '../widgets/status_banner.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _isAvailable = false;
  String _restaurantName = '';
  int _totalSats = 0;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _restaurantName = prefs.getString('restaurant_name') ?? 'Restaurante');
  }

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(myRestaurantQuery),
        pollInterval: const Duration(seconds: 30),
      ),
      builder: (result, {fetchMore, refetch}) {
        if (!result.isLoading && result.data?['myRestaurant'] != null) {
          final r = result.data!['myRestaurant'];
          if (_isAvailable != (r['isAvailable'] == true)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() => _isAvailable = r['isAvailable'] == true);
            });
          }
        }

        return Query(
          options: QueryOptions(document: gql(myEarningsQuery), pollInterval: const Duration(minutes: 2)),
          builder: (earningsResult, {fetchMore, refetch}) {
            final earnSats = (earningsResult.data?['myEarnings']?['totalSats'] as num?)?.toInt() ?? _totalSats;
            if (earnSats != _totalSats) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _totalSats = earnSats);
              });
            }
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(_restaurantName),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: SatsChip(sats: _totalSats),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Mutation(
                  options: MutationOptions(document: gql(toggleAvailableMutation)),
                  builder: (runMutation, mutResult) {
                    return GestureDetector(
                      onTap: () async {
                        await runMutation({}).networkResult;
                        refetch!();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isAvailable ? AppColors.success : AppColors.textLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(_isAvailable ? 'Aberto' : 'Fechado', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              const StatusBanner(),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    const OrdersScreen(),
                    const MenuScreen(),
                    const EarningsScreen(),
                    ProfileScreen(onLogout: widget.onLogout),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textLight,
            backgroundColor: AppColors.cardWhite,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
              BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_outlined), activeIcon: Icon(Icons.restaurant_menu), label: 'Cardápio'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Ganhos'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
        );
          },
        );
      },
    );
  }
}
