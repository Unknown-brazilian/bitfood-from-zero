import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../theme.dart';
import '../queries.dart';

class ActiveOrderScreen extends StatelessWidget {
  const ActiveOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(riderOrdersQuery),
        variables: {'status': 'ASSIGNED'},
        fetchPolicy: FetchPolicy.networkOnly,
        pollInterval: const Duration(seconds: 8),
      ),
      builder: (result, {fetchMore, refetch}) {
        final orders = (result.data?['riderOrders']?['orders'] as List?) ?? [];
        final outerRefetch = refetch;

        // Also check PICKED orders
        return Query(
          options: QueryOptions(
            document: gql(riderOrdersQuery),
            variables: {'status': 'PICKED'},
            fetchPolicy: FetchPolicy.networkOnly,
          ),
          builder: (pickedResult, {fetchMore, refetch}) {
            final pickedOrders = (pickedResult.data?['riderOrders']?['orders'] as List?) ?? [];
            final all = [...orders, ...pickedOrders];
            final pickedRefetch = refetch;

            if (all.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delivery_dining_outlined, size: 64, color: AppColors.textLight),
                    SizedBox(height: 12),
                    Text('Nenhuma entrega em andamento', style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Aceite pedidos na aba "Disponíveis"', style: TextStyle(color: AppColors.textLight)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: all.length,
              itemBuilder: (_, i) => _ActiveOrderCard(order: all[i], onUpdate: () {
                outerRefetch?.call();
                pickedRefetch?.call();
              }),
            );
          },
        );
      },
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onUpdate;

  const _ActiveOrderCard({required this.order, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final status = order['orderStatus'] as String;
    final total = order['total'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status == 'ASSIGNED' ? AppColors.orange : AppColors.success, width: 1.5),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'ASSIGNED' ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status == 'ASSIGNED' ? '🔴 Ir buscar' : '🟢 Em entrega',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: status == 'ASSIGNED' ? AppColors.orange : AppColors.success,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text('#${order['orderId']}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontFamily: 'monospace')),
                  ],
                ),
                const SizedBox(height: 12),

                // Pickup
                _LocationRow(
                  icon: Icons.restaurant,
                  color: AppColors.orange,
                  title: 'Retirada',
                  address: order['restaurant']?['name'] ?? '',
                  sub: order['restaurant']?['address'] ?? '',
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 13),
                  child: Container(width: 2, height: 20, color: AppColors.divider),
                ),

                // Delivery
                _LocationRow(
                  icon: Icons.location_on,
                  color: AppColors.primary,
                  title: 'Entrega',
                  address: order['user']?['name'] ?? '',
                  sub: order['deliveryAddress']?['address'] ?? '',
                ),
                const SizedBox(height: 12),

                // Contact
                if (order['user']?['phone'] != null)
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 6),
                      Text(order['user']['phone'], style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),

                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Comissão de entrega', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                    Row(children: [
                      const Icon(Icons.electric_bolt, color: AppColors.orange, size: 14),
                      const SizedBox(width: 2),
                      Text('${(order['deliveryFee'] as int? ?? 0).toLocaleString()} sats', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    ]),
                  ],
                ),
              ],
            ),
          ),

          // Action button
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Mutation(
              options: MutationOptions(
                document: gql(status == 'ASSIGNED' ? markPickedMutation : markDeliveredMutation),
              ),
              builder: (runMutation, result) => TextButton(
                onPressed: result?.isLoading == true ? null : () async {
                  await runMutation({'orderId': order['_id']}).networkResult;
                  onUpdate();
                },
                style: TextButton.styleFrom(
                  foregroundColor: status == 'ASSIGNED' ? AppColors.orange : AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: result?.isLoading == true
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        status == 'ASSIGNED' ? 'Confirmar Retirada 📦' : 'Confirmar Entrega ✅',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String address;
  final String sub;

  const _LocationRow({required this.icon, required this.color, required this.title, required this.address, required this.sub});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                Text(address, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                if (sub.isNotEmpty)
                  Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      );
}

extension on int {
  String toLocaleString() => toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
