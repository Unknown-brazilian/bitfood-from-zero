import 'dart:math';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../theme.dart';
import '../queries.dart';

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  bool _towardHomeActive = false;
  bool _activating = false;
  double? _riderLat;
  double? _riderLng;
  String? _towardHomeError;

  double _bearing(double lat1, double lon1, double lat2, double lon2) {
    final l1 = lat1 * pi / 180;
    final l2 = lat2 * pi / 180;
    final dl = (lon2 - lon1) * pi / 180;
    final y = sin(dl) * cos(l2);
    final x = cos(l1) * sin(l2) - sin(l1) * cos(l2) * cos(dl);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  bool _isTowardHome(Map<String, dynamic> order, double homeLat, double homeLng) {
    final delLoc = order['deliveryAddress']?['location'];
    if (delLoc == null || _riderLat == null) return false;
    final dlat = (delLoc['lat'] as num?)?.toDouble();
    final dlng = (delLoc['lng'] as num?)?.toDouble();
    if (dlat == null || dlng == null) return false;
    final toHome     = _bearing(_riderLat!, _riderLng!, homeLat, homeLng);
    final toDelivery = _bearing(_riderLat!, _riderLng!, dlat, dlng);
    var diff = (toDelivery - toHome).abs();
    if (diff > 180) diff = 360 - diff;
    return diff <= 60;
  }

  Future<void> _activate(Map<String, dynamic>? me) async {
    final homeLocMap = me?['homeLocation'] as Map?;
    if (homeLocMap == null) {
      setState(() => _towardHomeError = 'Defina seu endereço de casa no perfil primeiro.');
      return;
    }

    setState(() { _activating = true; _towardHomeError = null; });
    try {
      // Request GPS
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        setState(() { _towardHomeError = 'Permissão de localização negada.'; _activating = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);

      // Enforce 8h cooldown on backend
      final client = GraphQLProvider.of(context).value;
      final res = await client.mutate(MutationOptions(
        document: gql(activateTowardHomeMutation),
      ));
      if (res.hasException) throw res.exception!;

      setState(() {
        _riderLat = pos.latitude;
        _riderLng = pos.longitude;
        _towardHomeActive = true;
        _activating = false;
      });
    } catch (e) {
      final msg = e.toString()
          .replaceAll(RegExp(r'OperationException.*?:\s?'), '')
          .trim();
      setState(() { _towardHomeError = msg; _activating = false; });
    }
  }

  void _deactivate() => setState(() {
    _towardHomeActive = false;
    _towardHomeError = null;
    _riderLat = null;
    _riderLng = null;
  });

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(meQuery),
        fetchPolicy: FetchPolicy.cacheFirst,
        pollInterval: const Duration(minutes: 5),
      ),
      builder: (meResult, {fetchMore, refetch}) {
        final me = meResult.data?['me'] as Map<String, dynamic>?;
        final homeLocMap = me?['homeLocation'] as Map?;
        final homeLat = (homeLocMap?['lat'] as num?)?.toDouble();
        final homeLng = (homeLocMap?['lng'] as num?)?.toDouble();
        final hasHome = me?['homeAddress'] != null;

        return Query(
          options: QueryOptions(
            document: gql(availableOrdersQuery),
            fetchPolicy: FetchPolicy.networkOnly,
            pollInterval: const Duration(seconds: 10),
          ),
          builder: (result, {fetchMore, refetch}) {
            List<Map<String, dynamic>> orders =
                ((result.data?['availableOrders'] as List?) ?? [])
                    .cast<Map<String, dynamic>>();

            if (_towardHomeActive && _riderLat != null && homeLat != null) {
              orders = orders
                  .where((o) => _isTowardHome(o, homeLat, homeLng!))
                  .toList();
            }

            return Column(
              children: [
                _TowardHomeBar(
                  active: _towardHomeActive,
                  activating: _activating,
                  hasHome: hasHome,
                  error: _towardHomeError,
                  onActivate: () => _activate(me),
                  onDeactivate: _deactivate,
                ),
                Expanded(
                  child: _buildList(orders, result.isLoading, refetch!),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildList(
      List<Map<String, dynamic>> orders, bool loading, Refetch refetch) {
    if (loading && orders.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text(
              _towardHomeActive
                  ? 'Nenhum pedido em direção a casa'
                  : 'Nenhum pedido disponível',
              style:
                  const TextStyle(fontSize: 16, color: AppColors.textGrey),
            ),
            const SizedBox(height: 4),
            Text(
              _towardHomeActive
                  ? 'Tente desativar o filtro'
                  : 'Fique online para receber pedidos',
              style: const TextStyle(color: AppColors.textLight),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => refetch(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (_, i) =>
            _AvailableOrderCard(order: orders[i], onAccepted: refetch),
      ),
    );
  }
}

class _TowardHomeBar extends StatelessWidget {
  final bool active;
  final bool activating;
  final bool hasHome;
  final String? error;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;

  const _TowardHomeBar({
    required this.active,
    required this.activating,
    required this.hasHome,
    required this.error,
    required this.onActivate,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: AppColors.cardWhite,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (active) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.home, size: 14, color: Color(0xFF388E3C)),
                    SizedBox(width: 6),
                    Text('Em direção a casa',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E7D32))),
                  ]),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Filtro ativo',
                      style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ),
                IconButton(
                  onPressed: onDeactivate,
                  icon: const Icon(Icons.close, size: 18,
                      color: AppColors.textGrey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Desativar filtro',
                ),
              ] else ...[
                const Expanded(
                  child: Text('Pedidos disponíveis',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                ),
                if (activating)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                else
                  TextButton.icon(
                    onPressed: onActivate,
                    icon: const Icon(Icons.home_outlined,
                        size: 16, color: AppColors.primary),
                    label: const Text('Ir p/ casa',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.primary)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (error != null)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF0F0),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(error!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.primary)),
          ),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }
}

class _AvailableOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onAccepted;

  const _AvailableOrderCard(
      {required this.order, required this.onAccepted});

  @override
  Widget build(BuildContext context) {
    final deliveryFee = order['deliveryFee'] as int? ?? 0;
    final items = (order['items'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                          color: Color(0xFFFFF0F0),
                          shape: BoxShape.circle),
                      child: const Center(
                          child: Text('🍽️',
                              style: TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order['restaurant']?['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textDark)),
                          Text(
                              order['restaurant']?['address'] ?? '',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(children: [
                          const Icon(Icons.electric_bolt,
                              color: AppColors.orange, size: 14),
                          Text(
                              '${deliveryFee.toLocaleString()} sats',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textDark)),
                        ]),
                        const Text('sua comissão',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textGrey)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 16),
                Text(
                    items
                        .map((i) =>
                            '${i['quantity']}x ${i['title']}')
                        .join(', '),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textGrey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                          order['deliveryAddress']?['address'] ?? '',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border:
                  Border(top: BorderSide(color: AppColors.divider)),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Mutation(
              options: MutationOptions(
                  document: gql(acceptDeliveryMutation)),
              builder: (runMutation, result) => TextButton(
                onPressed: result?.isLoading == true
                    ? null
                    : () async {
                        await runMutation(
                                {'orderId': order['_id']})
                            .networkResult;
                        onAccepted();
                      },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.success,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: result?.isLoading == true
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.success))
                    : const Text('Aceitar Entrega ✓',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on int {
  String toLocaleString() => toString()
      .replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
