import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../theme.dart';
import '../queries.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(document: gql(myEarningsQuery), fetchPolicy: FetchPolicy.cacheAndNetwork),
      builder: (result, {fetchMore, refetch}) {
        final e = result.data?['myEarnings'];
        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: () async => refetch!(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 8),
                const Text('Seus Ganhos ⚡', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 16),
                _EarningCard(label: 'Hoje', sats: e?['todaySats'] ?? 0, icon: '☀️'),
                const SizedBox(height: 10),
                _EarningCard(label: 'Esta semana', sats: e?['weekSats'] ?? 0, icon: '📅'),
                const SizedBox(height: 10),
                _EarningCard(label: 'Este mês', sats: e?['monthSats'] ?? 0, icon: '📆'),
                const SizedBox(height: 10),
                _EarningCard(label: 'Total', sats: e?['totalSats'] ?? 0, icon: '⚡', highlight: true),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total de Pedidos', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                          Text('${e?['totalOrders'] ?? 0}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EarningCard extends StatelessWidget {
  final String label;
  final int sats;
  final String icon;
  final bool highlight;

  const _EarningCard({required this.label, required this.sats, required this.icon, this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlight ? AppColors.primary : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight ? AppColors.primary : AppColors.divider),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: highlight ? Colors.white70 : AppColors.textGrey)),
                Row(
                  children: [
                    const Icon(Icons.electric_bolt, color: Color(0xFFFFD700), size: 16),
                    const SizedBox(width: 2),
                    Text(
                      '${sats.toLocaleString()} sats',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: highlight ? Colors.white : AppColors.textDark),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
}

extension on int {
  String toLocaleString() => toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
