import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/queries.dart';
import '../../theme/app_theme.dart';

class LightningWalletScreen extends StatelessWidget {
  const LightningWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(meQuery),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (result, {fetchMore, refetch}) {
        final me = result.data?['me'];
        return _LightningBody(me: me, refetch: refetch);
      },
    );
  }
}

class _LightningBody extends StatefulWidget {
  final Map<String, dynamic>? me;
  final Refetch? refetch;
  const _LightningBody({this.me, this.refetch});

  @override
  State<_LightningBody> createState() => _LightningBodyState();
}

class _LightningBodyState extends State<_LightningBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _addrCtrl = TextEditingController();
  bool _savingAddr = false;
  bool _addrSaved = false;
  String? _addrError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    if (widget.me?['lightningAddress'] != null) {
      _addrCtrl.text = widget.me!['lightningAddress'];
    }
  }

  @override
  void didUpdateWidget(_LightningBody old) {
    super.didUpdateWidget(old);
    if (old.me != widget.me && widget.me?['lightningAddress'] != null &&
        _addrCtrl.text.isEmpty) {
      _addrCtrl.text = widget.me!['lightningAddress'];
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  bool get _locked => widget.me?['lightningAddressLocked'] == true;

  Future<bool> _confirmLightningChange() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('⚠️ Atenção'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seu endereço Lightning será bloqueado após a confirmação.\n\n'
                'Não será possível alterá-lo depois. Certifique-se de que o endereço está correto.\n\n'
                'Digite ENTENDI para confirmar:',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(hintText: 'ENTENDI', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: ctrl.text.trim() == 'ENTENDI' ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return confirmed ?? false;
  }

  Future<void> _saveAddress() async {
    final addr = _addrCtrl.text.trim();
    if (!_locked && addr.isNotEmpty) {
      final ok = await _confirmLightningChange();
      if (!ok) return;
    }
    setState(() { _savingAddr = true; _addrError = null; });
    try {
      final client = GraphQLProvider.of(context).value;
      final res = await client.mutate(MutationOptions(
        document: gql(setLightningAddressMutation),
        variables: { 'lightningAddress': addr.isEmpty ? null : addr },
      ));
      if (res.hasException) throw res.exception!;
      widget.refetch?.call();
      setState(() { _addrSaved = true; _savingAddr = false; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _addrSaved = false);
    } catch (e) {
      setState(() {
        _addrError = e.toString().replaceAll(RegExp(r'OperationException.*?:\s?'), '');
        _savingAddr = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedAddr = widget.me?['lightningAddress'] as String?;
    final balanceSats = (widget.me?['balanceSats'] ?? 0) as int;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bitcoin · Lightning Network'),
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.orange,
          tabs: const [
            Tab(text: 'Minha Carteira'),
            Tab(text: 'Adicionar Fundos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _WalletTab(
            savedAddr: savedAddr,
            balanceSats: balanceSats,
            addrCtrl: _addrCtrl,
            saving: _savingAddr,
            saved: _addrSaved,
            error: _addrError,
            onSave: _saveAddress,
          ),
          _DepositTab(balanceSats: balanceSats, onDeposited: widget.refetch),
        ],
      ),
    );
  }
}

// ── Wallet Tab ────────────────────────────────────────────────────────────────

class _WalletTab extends StatelessWidget {
  final String? savedAddr;
  final int balanceSats;
  final TextEditingController addrCtrl;
  final bool saving;
  final bool saved;
  final String? error;
  final VoidCallback onSave;

  const _WalletTab({
    required this.savedAddr,
    required this.balanceSats,
    required this.addrCtrl,
    required this.saving,
    required this.saved,
    required this.error,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
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
          child: Column(children: [
            const Text('⚡', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text('Lightning Network',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              balanceSats > 0
                  ? 'Saldo: $balanceSats sats'
                  : 'Pagamentos instantâneos em Bitcoin\nsem taxas bancárias, sem fronteiras',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Connected status
        if (savedAddr != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FFF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Carteira conectada',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success, fontSize: 13)),
                  Text(savedAddr!, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        const Text('Lightning Address',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 6),
        const Text(
          'Endereço para receber saques e reembolsos. Formato: user@carteira.com',
          style: TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.5),
        ),
        const SizedBox(height: 12),

        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8)),
            child: Text(error!, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
          ),
          const SizedBox(height: 10),
        ],

        TextField(
          controller: addrCtrl,
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
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(saved ? Icons.check : Icons.link, color: Colors.white),
            label: Text(
              saved ? 'Salvo!' : (savedAddr != null ? 'Atualizar Carteira' : 'Conectar Carteira'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: saved ? AppColors.success : AppColors.orange,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        const SizedBox(height: 32),
        _InfoCard(icon: Icons.flash_on, title: 'Pagamentos instantâneos',
            body: 'Transações confirmadas em segundos, não em minutos ou horas.'),
        const SizedBox(height: 10),
        _InfoCard(icon: Icons.money_off, title: 'Taxas mínimas',
            body: 'Pague frações de centavo por transação, independente do valor.'),
        const SizedBox(height: 10),
        _InfoCard(icon: Icons.public, title: 'Sem fronteiras',
            body: 'Pague em qualquer país sem conversão de moeda ou bloqueios bancários.'),
        const SizedBox(height: 20),
        const Text('Carteiras recomendadas',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            _WalletChip('Wallet of Satoshi'), _WalletChip('Phoenix'),
            _WalletChip('Breez'), _WalletChip('Muun'),
            _WalletChip('Zeus'), _WalletChip('Blue Wallet'),
          ],
        ),
      ],
    );
  }
}

// ── Deposit Tab ───────────────────────────────────────────────────────────────

class _DepositTab extends StatefulWidget {
  final int balanceSats;
  final Refetch? onDeposited;
  const _DepositTab({required this.balanceSats, this.onDeposited});

  @override
  State<_DepositTab> createState() => _DepositTabState();
}

class _DepositTabState extends State<_DepositTab> {
  final _amountCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _invoice;
  bool _paid = false;
  Timer? _pollTimer;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    final sats = int.tryParse(_amountCtrl.text.trim());
    if (sats == null || sats < 1) {
      setState(() => _error = 'Digite um valor válido em sats (mínimo 1).');
      return;
    }
    setState(() { _loading = true; _error = null; _invoice = null; _paid = false; });
    _pollTimer?.cancel();
    try {
      final client = GraphQLProvider.of(context).value;
      final res = await client.mutate(MutationOptions(
        document: gql(createDepositInvoiceMutation),
        variables: { 'amountSats': sats },
      ));
      if (res.hasException) throw res.exception!;
      final inv = res.data!['createDepositInvoice'] as Map<String, dynamic>;
      setState(() { _invoice = inv; _loading = false; });
      _startPolling();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll(RegExp(r'OperationException.*?:\s?'), '');
        _loading = false;
      });
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _paid) return;
      final client = GraphQLProvider.of(context).value;
      final res = await client.query(QueryOptions(
        document: gql(meQuery),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      final newBalance = (res.data?['me']?['balanceSats'] ?? 0) as int;
      if (newBalance > widget.balanceSats) {
        _pollTimer?.cancel();
        widget.onDeposited?.call();
        if (mounted) setState(() => _paid = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Balance card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet_outlined, color: AppColors.orange, size: 28),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Saldo atual', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              Text('${widget.balanceSats} sats',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        if (_paid) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FFF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 24),
              SizedBox(width: 10),
              Text('Pagamento confirmado! Saldo atualizado.',
                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        const Text('Gerar Invoice',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 6),
        const Text(
          'Adicione sats à sua conta BitFood via Lightning Network. O saldo será creditado automaticamente.',
          style: TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.5),
        ),
        const SizedBox(height: 14),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8)),
            child: Text(_error!, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
          ),
          const SizedBox(height: 10),
        ],

        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: 'Quantidade em sats (ex: 1000)',
            prefixIcon: const Icon(Icons.electric_bolt, color: AppColors.orange),
            suffixText: 'sats',
            filled: true,
            fillColor: AppColors.cardWhite,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [1000, 5000, 10000, 50000].map((v) => ActionChip(
            label: Text('$v sats'),
            onPressed: () => _amountCtrl.text = '$v',
            backgroundColor: AppColors.orange.withOpacity(0.08),
            side: BorderSide(color: AppColors.orange.withOpacity(0.3)),
            labelStyle: const TextStyle(color: AppColors.orange, fontSize: 12),
          )).toList(),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _generate,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.qr_code, color: Colors.white),
            label: Text(_loading ? 'Gerando...' : 'Gerar Invoice Lightning',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        if (_invoice != null) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Escaneie ou copie o invoice',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (_invoice!['lightningInvoice'] != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                child: QrImageView(
                  data: (_invoice!['lightningInvoice'] as String).toUpperCase(),
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_invoice!['lightningInvoice'] != null)
            _CopyRow(label: 'Invoice BOLT11', value: _invoice!['lightningInvoice']),
          _CopyRow(label: 'Link de pagamento', value: _invoice!['checkoutUrl']),
          const SizedBox(height: 10),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange)),
            SizedBox(width: 8),
            Text('Aguardando confirmação...', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ]),
        ],
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  const _CopyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 11, color: AppColors.textDark),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        IconButton(
          icon: const Icon(Icons.copy, size: 18, color: AppColors.orange),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copiado!'), duration: Duration(seconds: 1)),
            );
          },
        ),
      ]),
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
    decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.orange, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
        const SizedBox(height: 2),
        Text(body, style: const TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4)),
      ])),
    ]),
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
