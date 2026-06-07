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
        final me = result.data?['me'];
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
              const SizedBox(height: 12),
              _WithdrawSection(
                availableSats: (e?['availableSats'] as num?)?.toInt() ?? 0,
                pendingSats: (e?['pendingSats'] as num?)?.toInt() ?? 0,
                lightningAddress: me?['lightningAddress'] as String?,
                refetch: refetch,
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

class _WithdrawSection extends StatefulWidget {
  final int availableSats;
  final int pendingSats;
  final String? lightningAddress;
  final Refetch? refetch;
  const _WithdrawSection({
    required this.availableSats,
    required this.pendingSats,
    required this.lightningAddress,
    required this.refetch,
  });

  @override
  State<_WithdrawSection> createState() => _WithdrawSectionState();
}

class _WithdrawSectionState extends State<_WithdrawSection> {
  final TextEditingController _amountCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Informe um valor válido.');
      return;
    }
    if (amount > widget.availableSats) {
      setState(() => _error = 'Valor maior que o saldo disponível.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final client = GraphQLProvider.of(context).value;
      final res = await client.mutate(MutationOptions(
        document: gql(requestWithdrawalMutation),
        variables: { 'amountSats': amount },
      ));
      if (res.hasException) throw res.exception!;
      _amountCtrl.clear();
      widget.refetch?.call();
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saque solicitado — pagamento Lightning em breve'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll(RegExp(r'OperationException.*?:\s?'), '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAddress = widget.lightningAddress != null && widget.lightningAddress!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.account_balance_wallet_outlined, color: AppColors.orange, size: 20),
            SizedBox(width: 8),
            Text('Sacar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _balanceTile('Disponível', widget.availableSats, AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _balanceTile('Em escrow', widget.pendingSats, AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Disponível é o valor liberado para saque. Em escrow ainda está travado nas suas últimas entregas e será liberado depois.',
            style: TextStyle(fontSize: 11, color: AppColors.textGrey),
          ),
          const SizedBox(height: 14),
          if (!hasAddress)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFF9A825)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Defina seu endereço Lightning no Perfil para sacar',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                  ),
                ),
              ]),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBDBDBD)),
              ),
              child: Row(children: [
                const Icon(Icons.electric_bolt, size: 16, color: Color(0xFFFF6900)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Destino: ${widget.lightningAddress}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
              ),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              enabled: !_submitting,
              decoration: const InputDecoration(
                hintText: 'Valor em sats',
                filled: true,
                fillColor: Color(0xFFF5F5F5),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixText: 'sats',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6900),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Solicitar saque', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _balanceTile(String label, int sats, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            const SizedBox(height: 4),
            Text('${sats.toLocaleString()} sats', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );
}

extension on int {
  String toLocaleString() => toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
