import 'package:flutter/material.dart';
import '../theme.dart';

class TierCard extends StatelessWidget {
  final String tier;
  final double score;
  final int completedOrders;
  final int? escrowSats;

  const TierCard({
    super.key,
    required this.tier,
    required this.score,
    required this.completedOrders,
    this.escrowSats,
  });

  static Color _tierColor(String tier) {
    switch (tier) {
      case 'VETERAN': return const Color(0xFF6A1B9A);
      case 'TRUSTED': return const Color(0xFF1565C0);
      case 'BASIC':   return AppColors.primary;
      default:        return AppColors.textLight;
    }
  }

  static String _tierLabel(String tier) {
    switch (tier) {
      case 'VETERAN': return '⭐ Veterano';
      case 'TRUSTED': return '✅ Confiável';
      case 'BASIC':   return '🔵 Básico';
      default:        return '🆕 Novo';
    }
  }

  static String _tierLimit(String tier) {
    switch (tier) {
      case 'VETERAN': return 'Sem limite';
      case 'TRUSTED': return 'Até \$200 USD';
      case 'BASIC':   return 'Até \$50 USD';
      default:        return 'Até \$10 USD';
    }
  }

  static String _tierNext(String tier, int completed) {
    switch (tier) {
      case 'NEW':     return '${5 - completed} entrega(s) para Básico';
      case 'BASIC':   return '${20 - completed} entrega(s) para Confiável';
      case 'TRUSTED': return '${100 - completed} entrega(s) para Veterano';
      default:        return 'Nível máximo atingido!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(tier);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.workspace_premium, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              'Reputação & Nível',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                child: Text(_tierLabel(tier), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const Spacer(),
              Text(
                '${score.toStringAsFixed(1)} ★',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Row('Limite de pedidos', _tierLimit(tier)),
          _Row('Entregas concluídas', '$completedOrders'),
          if (escrowSats != null)
            _Row('Escrow retido', '$escrowSats sats'),
          if (tier != 'VETERAN') ...[
            const SizedBox(height: 6),
            Text(
              _tierNext(tier, completedOrders),
              style: TextStyle(fontSize: 11, color: color, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      ],
    ),
  );
}
