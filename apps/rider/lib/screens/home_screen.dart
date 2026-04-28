import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../queries.dart';
import 'available_orders_screen.dart';
import 'active_order_screen.dart';
import 'earnings_screen.dart';
import 'heatmap_screen.dart';
import 'profile_screen.dart';
import '../widgets/sats_chip.dart';
import '../widgets/status_banner.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _available = false;
  String _name = '';
  int _totalSats = 0;
  String? _zoneId;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _name = prefs.getString('rider_name') ?? 'Entregador');
  }

  void _onMeData(Map<String, dynamic> data) {
    final zone = (data['me'] as Map?)?['zone'];
    final zoneId = zone?['_id']?.toString();
    if (zoneId != null && zoneId != _zoneId && mounted) {
      setState(() => _zoneId = zoneId);
    }
  }

  void _startLocationTracking(BuildContext context) {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        final client = GraphQLProvider.of(context).value;
        await client.mutate(MutationOptions(
          document: gql(updateLocationMutation),
          variables: {'lat': pos.latitude, 'lng': pos.longitude},
        ));
      } catch (_) {}
    });
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
  }

  Future<void> _toggleAvailability(BuildContext context, bool current) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (!current && permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final client = GraphQLProvider.of(context).value;
      await client.mutate(MutationOptions(
        document: gql(updateAvailabilityMutation),
        variables: {'available': !current},
      ));
      setState(() => _available = !current);
      if (!current) {
        _startLocationTracking(context);
      } else {
        _stopLocationTracking();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.primary));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(document: gql(meQuery), pollInterval: const Duration(minutes: 5)),
      builder: (meResult, {fetchMore, refetch}) {
        if (meResult.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onMeData(meResult.data!));
        }
    return Query(
      options: QueryOptions(document: gql(riderEarningsQuery), pollInterval: const Duration(minutes: 2)),
      builder: (earningsResult, {fetchMore, refetch}) {
        final earnSats = (earningsResult.data?['myEarnings']?['totalSats'] as num?)?.toInt() ?? _totalSats;
        if (earnSats != _totalSats) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _totalSats = earnSats);
          });
        }
    return Stack(
      children: [
        // Hidden subscription for new delivery notifications
        if (_zoneId != null)
          Offstage(
            offstage: true,
            child: Subscription(
              options: SubscriptionOptions(
                document: gql(newOrderForRiderSub),
                variables: {'zoneId': _zoneId},
              ),
              builder: (result) {
                if (!result.isLoading && result.data != null) {
                  final order = result.data!['newOrderForRider'];
                  if (order != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      NotificationService.showNewDelivery(order);
                    });
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
    Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Olá, ${_name.split(' ').first}! 🏍️'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: SatsChip(sats: _totalSats),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: GestureDetector(
              onTap: () => _toggleAvailability(context, _available),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _available ? AppColors.success : AppColors.textLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(_available ? 'Online' : 'Offline', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
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
                const AvailableOrdersScreen(),
                const ActiveOrderScreen(),
                const HeatMapScreen(),
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
          BottomNavigationBarItem(icon: Icon(Icons.search), activeIcon: Icon(Icons.search), label: 'Disponíveis'),
          BottomNavigationBarItem(icon: Icon(Icons.delivery_dining), activeIcon: Icon(Icons.delivery_dining), label: 'Em Andamento'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), activeIcon: Icon(Icons.bar_chart), label: 'Ganhos'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    ),   // closes Scaffold (2nd Stack child)
    ], // closes Stack.children
    );  // closes Stack
      },
    );  // closes earningsQuery
      },
    );  // closes meQuery
  }
}
