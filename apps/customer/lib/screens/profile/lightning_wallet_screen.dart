import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

class LightningWalletScreen extends StatefulWidget {
  const LightningWalletScreen({super.key});

  @override
  State<LightningWalletScreen> createState() => _LightningWalletScreenState();
}

class _LightningWalletScreenState extends State<LightningWalletScreen> {
  final _addressCtrl = TextEditingController();
  String? _savedAddress;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final addr = prefs.getString('lightning_address');
    setState(() {
      _savedAddress = addr;
      if (addr != null) _addressCtrl.text = addr;
    });
  }

  Future<void> _save() async {
    final addr = _addressCtrl.text.trim();
    if (addr.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lightning_address', addr);
    setState(() { _savedAddress = addr; _saved = true; });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  Future<void> _disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lightning_address');
    setState(() { _savedAddress = null; _addressCtrl.clear(); });
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bitcoin · Lightning Network'),
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6900), Color(0xFFFFB347)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Text('⚡', style: TextStyle(fontSize: 48)),
                SizedBox(height: 8),
                Text('Lightning Network', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text(
                  'Pagamentos instantâneos em Bitcoin\nsem taxas bancárias, sem fronteiras',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Status card
          if (_savedAddress != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Carteira conectada', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success, fontSize: 13)),
                        Text(_savedAddress!, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Connect section
          const Text('Lightning Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 6),
          const Text(
            'Conecte sua carteira Lightning para receber reembolsos e cashback. Use o formato user@carteira.com (ex: satoshi@walletofsatoshi.com)',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'ex: voce@walletofsatoshi.com',
              prefixIcon: const Icon(Icons.electric_bolt, color: AppColors.orange),
              filled: true,
              fillColor: AppColors.cardWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: Icon(_saved ? Icons.check : Icons.link, color: Colors.white),
              label: Text(_saved ? 'Salvo!' : (_savedAddress != null ? 'Atualizar Carteira' : 'Conectar Carteira'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _saved ? AppColors.success : AppColors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_savedAddress != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.link_off, color: AppColors.primary),
                label: const Text('Desconectar Carteira', style: TextStyle(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
          // Info cards
          _InfoCard(
            icon: Icons.flash_on,
            title: 'Pagamentos instantâneos',
            body: 'Transações confirmadas em segundos, não em minutos ou horas.',
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.money_off,
            title: 'Taxas mínimas',
            body: 'Pague frações de centavo por transação, independente do valor.',
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.public,
            title: 'Sem fronteiras',
            body: 'Pague em qualquer país sem conversão de moeda ou bloqueios bancários.',
          ),
          const SizedBox(height: 20),

          // Wallet recommendations
          const Text('Carteiras recomendadas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: const [
              _WalletChip('Wallet of Satoshi'),
              _WalletChip('Phoenix'),
              _WalletChip('Breez'),
              _WalletChip('Muun'),
              _WalletChip('Zeus'),
              _WalletChip('Blue Wallet'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _InfoCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.cardWhite,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.orange, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WalletChip extends StatelessWidget {
  final String name;
  const _WalletChip(this.name);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.orange.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.orange.withOpacity(0.3)),
    ),
    child: Text(name, style: const TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.w600)),
  );
}
