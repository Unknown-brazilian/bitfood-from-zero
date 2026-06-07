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
        final r = result.data?['myRestaurant'];
        final availableSats = (e?['availableSats'] ?? 0) as int;
        final pendingSats = (e?['pendingSats'] ?? 0) as int;
        final lightningAddress = r?['lightningAddress'] as String?;
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
                _EarningCard(label: 'Disponível p/ saque', sats: availableSats, icon: '💸', highlight: true),
                if (pendingSats > 0) ...[
                  const SizedBox(height: 10),
                  _EarningCard(label: 'Pendente', sats: pendingSats, icon: '⏳'),
                ],
                const SizedBox(height: 10),
                _EarningCard(label: 'Hoje', sats: e?['todaySats'] ?? 0, icon: '☀️'),
                const SizedBox(height: 10),
                _EarningCard(label: 'Esta semana', sats: e?['weekSats'] ?? 0, icon: '📅'),
                const SizedBox(height: 10),
                _EarningCard(label: 'Este mês', sats: e?['monthSats'] ?? 0, icon: '📆'),
                const SizedBox(height: 10),
                _EarningCard(label: 'Total', sats: e?['totalSats'] ?? 0, icon: '⚡'),
                const SizedBox(height: 16),
                _WithdrawSection(
                  availableSats: availableSats,
                  lightningAddress: lightningAddress,
                  onWithdrawn: () => refetch!(),
                ),
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

class _WithdrawSection extends StatefulWidget {
  final int availableSats;
  final String? lightningAddress;
  final VoidCallback onWithdrawn;

  const _WithdrawSection({required this.availableSats, required this.lightningAddress, required this.onWithdrawn});

  @override
  State<_WithdrawSection> createState() => _WithdrawSectionState();
}

class _WithdrawSectionState extends State<_WithdrawSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAddress = widget.lightningAddress != null && widget.lightningAddress!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sacar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 12),
          if (!hasAddress)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Defina seu endereço Lightning no Perfil para sacar', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFFFFD700), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(widget.lightningAddress!, style: const TextStyle(color: AppColors.textGrey, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Valor (sats)',
                hintText: 'Máx. ${widget.availableSats.toLocaleString()}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            Mutation(
              options: MutationOptions(
                document: gql(requestWithdrawalMutation),
                onCompleted: (data) {
                  if (data == null) return;
                  _controller.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saque solicitado — pagamento Lightning em breve')),
                  );
                  widget.onWithdrawn();
                },
                onError: (error) {
                  final msg = error?.graphqlErrors.isNotEmpty == true ? error!.graphqlErrors.first.message : 'Erro ao solicitar saque';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                },
              ),
              builder: (runMutation, mutationResult) {
                final loading = mutationResult?.isLoading ?? false;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: loading ? null : () => _submit(runMutation),
                    child: loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Solicitar saque', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _submit(RunMutation runMutation) {
    final amount = int.tryParse(_controller.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um valor válido')));
      return;
    }
    if (amount > widget.availableSats) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valor maior que o disponível')));
      return;
    }
    runMutation({'amountSats': amount});
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
