import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/queries.dart';
import 'order_detail_screen.dart';

const _statusLabels = {
  'PENDING': 'Aguardando pagamento',
  'PAID': 'Pago',
  'ACCEPTED': 'Aceito',
  'PREPARING': 'Em preparo',
  'READY': 'Pronto',
  'ASSIGNED': 'Entregador a caminho',
  'PICKED': 'Retirado',
  'DELIVERING': 'Em entrega',
  'DELIVERED': 'Entregue',
  'CANCELLED': 'Cancelado',
  'REJECTED': 'Rejeitado',
};

const _statusColors = {
  'PENDING': Color(0xFFFF9800),
  'PAID': Color(0xFF2196F3),
  'ACCEPTED': Color(0xFF2196F3),
  'PREPARING': Color(0xFFFF6900),
  'READY': Color(0xFF9C27B0),
  'ASSIGNED': Color(0xFF3F51B5),
  'PICKED': Color(0xFF00BCD4),
  'DELIVERING': Color(0xFF00BCD4),
  'DELIVERED': AppColors.success,
  'CANCELLED': AppColors.textLight,
  'REJECTED': AppColors.primary,
};

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Meus Pedidos')),
      body: Query(
        options: QueryOptions(
          document: gql(myOrdersQuery),
          fetchPolicy: FetchPolicy.cacheAndNetwork,
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final orders = (result.data?['myOrders']?['orders'] as List?) ?? [];
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textLight),
                  SizedBox(height: 12),
                  Text('Nenhum pedido ainda', style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Faça seu primeiro pedido!', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => refetch!(),
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final o = orders[i];
                final status = o['orderStatus'] as String;
                final color = _statusColors[status] ?? AppColors.textGrey;

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o['_id'])),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(o['restaurant']?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text(_statusLabels[status] ?? status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (o['items'] as List?)?.map((item) => '${item['quantity']}x ${item['title']}').join(', ') ?? '',
                          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.electric_bolt, color: AppColors.orange, size: 13),
                            const SizedBox(width: 2),
                            Text('${(o['total'] as int).toLocaleString()} sats', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                            const Spacer(),
                            Text(
                              _formatDate(o['createdAt']),
                              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String? ts) {
    if (ts == null) return '';
    try {
      final d = DateTime.fromMillisecondsSinceEpoch(int.parse(ts));
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}

extension on int {
  String toLocaleString() => toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
