import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/queries.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Detalhes do Pedido')),
      body: Query(
        options: QueryOptions(
          document: gql(orderDetailQuery),
          variables: {'id': orderId},
          pollInterval: const Duration(seconds: 10),
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final o = result.data?['order'];
          if (o == null) return const Center(child: Text('Pedido não encontrado'));

          final status = o['orderStatus'] as String;
          final steps = ['PAID', 'ACCEPTED', 'PREPARING', 'READY', 'PICKED', 'DELIVERED'];
          final currentStep = steps.indexOf(status).clamp(0, steps.length - 1);

          return RefreshIndicator(
            onRefresh: () async => refetch!(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Status tracker
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pedido #${o['orderId']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark)),
                      const SizedBox(height: 16),
                      ...List.generate(steps.length, (i) {
                        final done = i <= currentStep;
                        final active = i == currentStep;
                        return Row(
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: done ? AppColors.primary : AppColors.divider,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(done ? Icons.check : null, color: Colors.white, size: 16),
                                ),
                                if (i < steps.length - 1)
                                  Container(width: 2, height: 24, color: done ? AppColors.primary : AppColors.divider),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _stepLabel(steps[i]),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                                color: active ? AppColors.primary : (done ? AppColors.textDark : AppColors.textLight),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Restaurant
                _Card(
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o['restaurant']?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                            Text(o['restaurant']?['address'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Rider (if assigned)
                if (o['rider'] != null) ...[
                  const SizedBox(height: 12),
                  _Card(
                    child: Row(
                      children: [
                        const Icon(Icons.delivery_dining, color: AppColors.orange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o['rider']['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              const Text('Seu entregador', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                            ],
                          ),
                        ),
                        Text(o['rider']['phone'] ?? '', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Items
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Itens do Pedido', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      const SizedBox(height: 8),
                      ...(o['items'] as List? ?? []).map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text('${item['quantity']}x', style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item['title'], style: const TextStyle(fontSize: 13, color: AppColors.textDark))),
                            Text('${(item['totalPrice'] as int).toLocaleString()} sats', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                          ],
                        ),
                      )),
                      const Divider(height: 20),
                      _Row('Entrega', '${(o['deliveryFee'] as int? ?? 0).toLocaleString()} sats'),
                      if ((o['discount'] as int? ?? 0) > 0)
                        _Row('Desconto', '-${(o['discount'] as int).toLocaleString()} sats', color: AppColors.success),
                      if ((o['tip'] as int? ?? 0) > 0)
                        _Row('Gorjeta', '${(o['tip'] as int).toLocaleString()} sats'),
                      const Divider(height: 12),
                      _Row('Total', '${(o['total'] as int).toLocaleString()} sats', bold: true),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _stepLabel(String s) {
    const m = {
      'PAID': 'Pagamento confirmado ⚡',
      'ACCEPTED': 'Restaurante aceitou',
      'PREPARING': 'Em preparo',
      'READY': 'Pronto para retirada',
      'PICKED': 'Retirado pelo entregador',
      'DELIVERED': 'Entregue!',
    };
    return m[s] ?? s;
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: child,
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _Row(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
            Text(value, style: TextStyle(fontSize: 13, color: color ?? AppColors.textDark, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      );
}

extension on int {
  String toLocaleString() => toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
