import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../theme.dart';
import '../queries.dart';

class AvailableOrdersScreen extends StatelessWidget {
  const AvailableOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(availableOrdersQuery),
        fetchPolicy: FetchPolicy.networkOnly,
        pollInterval: const Duration(seconds: 10),
      ),
      builder: (result, {fetchMore, refetch}) {
        final orders = (result.data?['availableOrders'] as List?) ?? [];

        if (result.isLoading && orders.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: AppColors.textLight),
                SizedBox(height: 12),
                Text('Nenhum pedido disponível', style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
                SizedBox(height: 4),
                Text('Fique online para receber pedidos', style: TextStyle(color: AppColors.textLight)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => refetch!(),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (_, i) => _AvailableOrderCard(order: orders[i], onAccepted: refetch!),
          ),
        );
      },
    );
  }
}

class _AvailableOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onAccepted;

  const _AvailableOrderCard({required this.order, required this.onAccepted});

  @override
  Widget build(BuildContext context) {
    final total = order['total'] as int? ?? 0;
    final deliveryFee = order['deliveryFee'] as int? ?? 0;
    final items = (order['items'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
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
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: Color(0xFFFFF0F0), shape: BoxShape.circle),
                      child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order['restaurant']?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
                          Text(order['restaurant']?['address'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(children: [
                          const Icon(Icons.electric_bolt, color: AppColors.orange, size: 14),
                          Text('${deliveryFee.toLocaleString()} sats', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
                        ]),
                        const Text('sua comissão', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 16),
                // Items
                Text(items.map((i) => '${i['quantity']}x ${i['title']}').join(', '),
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                // Delivery address
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(order['deliveryAddress']?['address'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Accept button
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Mutation(
              options: MutationOptions(document: gql(acceptDeliveryMutation)),
              builder: (runMutation, result) => TextButton(
                onPressed: result?.isLoading == true ? null : () async {
                  await runMutation({'orderId': order['_id']}).networkResult;
                  onAccepted();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: result?.isLoading == true
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success))
                    : const Text('Aceitar Entrega ✓', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on int {
  String toLocaleString() => toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
