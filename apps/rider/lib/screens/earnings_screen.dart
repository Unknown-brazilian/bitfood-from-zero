import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../theme.dart';
import '../queries.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(document: gql(riderEarningsQuery), fetchPolicy: FetchPolicy.cacheAndNetwork),
      builder: (result, {fetchMore, refetch}) {
        final e = result.data?['myEarnings'];
        return RefreshIndicator(
          onRefresh: () async => refetch!(),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Seus Ganhos ⚡', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 16),
              _card('Hoje ☀️', e?['todaySats'] ?? 0, false),
              const SizedBox(height: 10),
              _card('Esta semana 📅', e?['weekSats'] ?? 0, false),
              const SizedBox(height: 10),
              _card('Este mês 📆', e?['monthSats'] ?? 0, false),
              const SizedBox(height: 10),
              _card('Total ⚡', e?['totalSats'] ?? 0, true),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total de Entregas', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                        Text('${e?['totalOrders'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(String label, int sats, bool highlight) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlight ? AppColors.primary : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight ? AppColors.primary : AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, color: highlight ? Colors.white70 : AppColors.textGrey)),
                  Row(
                    children: [
                      Icon(Icons.electric_bolt, color: highlight ? Colors.yellow : AppColors.orange, size: 16),
                      const SizedBox(width: 2),
                      Text('${sats.toLocaleString()} sats', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: highlight ? Colors.white : AppColors.textDark)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

extension on int {
  String toLocaleString() => toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
