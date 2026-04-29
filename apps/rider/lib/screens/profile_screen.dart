import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../queries.dart';
import '../widgets/tier_card.dart';
import '../widgets/address_picker_sheet.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(document: gql(meQuery), fetchPolicy: FetchPolicy.cacheAndNetwork),
      builder: (result, {fetchMore, refetch}) {
        final me = result.data?['me'];
        return _ProfileBody(me: me, refetch: refetch, onLogout: onLogout);
      },
    );
  }
}

class _ProfileBody extends StatefulWidget {
  final Map<String, dynamic>? me;
  final Refetch? refetch;
  final VoidCallback onLogout;
  const _ProfileBody({this.me, this.refetch, required this.onLogout});

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lightningCtrl;
  String _vehicleType = 'BICYCLE';
  bool _loading = false;
  bool _savingLightning = false;
  bool _lightningSaved = false;
  bool _savingHomeAddress = false;
  String? _error;
  String? _success;
  String? _lightningError;
  String? _homeAddressError;

  @override
  void initState() {
    super.initState();
    final me = widget.me ?? {};
    _nameCtrl = TextEditingController(text: me['name'] ?? '');
    _lightningCtrl = TextEditingController(text: me['lightningAddress'] ?? '');
    _vehicleType = me['vehicleType'] ?? 'BICYCLE';
  }

  @override
  void didUpdateWidget(_ProfileBody old) {
    super.didUpdateWidget(old);
    if (old.me != widget.me && widget.me != null) {
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = widget.me!['name'] ?? '';
      if (_lightningCtrl.text.isEmpty) _lightningCtrl.text = widget.me!['lightningAddress'] ?? '';
      setState(() => _vehicleType = widget.me!['vehicleType'] ?? 'BICYCLE');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lightningCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _saveLightning() async {
    final addr = _lightningCtrl.text.trim();
    if (!_lightningLocked && addr.isNotEmpty) {
      final ok = await _confirmLightningChange();
      if (!ok) return;
    }
    setState(() { _savingLightning = true; _lightningError = null; });
    try {
      final client = GraphQLProvider.of(context).value;
      final res = await client.mutate(MutationOptions(
        document: gql(setLightningAddressMutation),
        variables: { 'lightningAddress': addr.isEmpty ? null : addr },
      ));
      if (res.hasException) throw res.exception!;
      widget.refetch?.call();
      setState(() { _lightningSaved = true; _savingLightning = false; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _lightningSaved = false);
    } catch (e) {
      setState(() {
        _lightningError = e.toString().replaceAll(RegExp(r'OperationException.*?:\s?'), '');
        _savingLightning = false;
      });
    }
  }

  bool get _nameLocked => widget.me?['nameLocked'] == true;
  bool get _lightningLocked => widget.me?['lightningAddressLocked'] == true;

  Future<void> _saveHomeAddress(AddressResult result) async {
    setState(() { _savingHomeAddress = true; _homeAddressError = null; });
    try {
      final client = GraphQLProvider.of(context).value;
      final res = await client.mutate(MutationOptions(
        document: gql(setHomeAddressMutation),
        variables: {
          'address': result.formatted,
          'lat': result.lat,
          'lng': result.lng,
        },
      ));
      if (res.hasException) throw res.exception!;
      widget.refetch?.call();
      setState(() { _savingHomeAddress = false; });
    } catch (e) {
      setState(() {
        _homeAddressError = e.toString().replaceAll(RegExp(r'OperationException.*?:\s?'), '');
        _savingHomeAddress = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.mutate(MutationOptions(
        document: gql(updateProfileMutation),
        variables: {
          if (!_nameLocked) 'name': _nameCtrl.text.trim(),
          'vehicleType': _vehicleType,
        },
      ));
      if (result.hasException) throw result.exception!;
      final newName = result.data?['updateProfile']?['name'];
      if (newName != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('rider_name', newName);
      }
      widget.refetch?.call();
      setState(() { _success = 'Perfil atualizado!'; _loading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll(RegExp(r'OperationException.*?:\s?'), '');
        _loading = false;
      });
    }
  }

  Widget _vehicleCard(String type, String label, String maxDistance, IconData icon) {
    final selected = _vehicleType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vehicleType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.textGrey, size: 30),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w700)),
              Text(maxDistance, style: TextStyle(color: selected ? Colors.white70 : AppColors.textLight, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.me?['name'] ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'E',
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(name.isNotEmpty ? name : 'Entregador', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark)),
                const Text('Entregador BitFood', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tier card
          TierCard(
            tier: widget.me?['tier'] as String? ?? 'NEW',
            score: (widget.me?['reputationScore'] as num?)?.toDouble() ?? 5.0,
            completedOrders: (widget.me?['completedOrders'] as num?)?.toInt() ?? 0,
            escrowSats: (widget.me?['escrowSats'] as num?)?.toInt(),
          ),
          const SizedBox(height: 20),

          if (_nameLocked)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: Color(0xFFF9A825)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nome bloqueado após vinculação com carteira Lightning. Contate o suporte para alterar.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                    ),
                  ),
                ],
              ),
            ),

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
          if (_success != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
              child: Text(_success!, style: const TextStyle(color: Color(0xFF388E3C), fontSize: 13)),
            ),

          const Text('Nome', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            enabled: !_nameLocked,
            decoration: InputDecoration(
              filled: true,
              fillColor: _nameLocked ? const Color(0xFFEEEEEE) : const Color(0xFFF5F5F5),
              border: const OutlineInputBorder(),
              suffixIcon: _nameLocked ? const Icon(Icons.lock_outline, size: 18, color: AppColors.textLight) : null,
            ),
          ),
          const SizedBox(height: 20),

          const Text('Tipo de Veículo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 10),
          Row(children: [
            _vehicleCard('BICYCLE', 'Bicicleta', 'Até 10km', Icons.pedal_bike),
            const SizedBox(width: 12),
            _vehicleCard('MOTORCYCLE', 'Moto', 'Até 60km', Icons.two_wheeler),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(8)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 15, color: Color(0xFF3F51B5)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rotas de bicicleta priorizam menor altimetria. Pedidos além do limite não aparecerão para você.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF3F51B5)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Lightning Address ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.electric_bolt, color: Color(0xFFFF6900), size: 18),
                SizedBox(width: 6),
                Text('Lightning Address ⚡',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ]),
              const SizedBox(height: 4),
              const Text('Endereço para receber seus ganhos via Lightning Network.',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
              const SizedBox(height: 10),
              if (_lightningError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(6)),
                  child: Text(_lightningError!, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                ),
              if (_lightningLocked)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.lock_outline, size: 15, color: Color(0xFF388E3C)),
                    SizedBox(width: 8),
                    Expanded(child: Text('Carteira vinculada e bloqueada. Contate o suporte para alterar.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)))),
                  ]),
                ),
              TextField(
                controller: _lightningCtrl,
                enabled: !_lightningLocked,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'ex: voce@walletofsatoshi.com',
                  filled: true,
                  fillColor: _lightningLocked ? const Color(0xFFEEEEEE) : const Color(0xFFF5F5F5),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: _lightningLocked ? const Icon(Icons.lock_outline, size: 18, color: AppColors.textLight) : null,
                ),
              ),
              if (!_lightningLocked) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savingLightning ? null : _saveLightning,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _lightningSaved ? AppColors.success : const Color(0xFFFF6900),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _savingLightning
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_lightningSaved ? 'Salvo!' : 'Salvar Lightning Address',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 20),

          // ── Endereço de Casa ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.home_outlined, color: AppColors.primary, size: 18),
                SizedBox(width: 6),
                Text('Endereço de Casa',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ]),
              const SizedBox(height: 4),
              const Text('Usado para filtrar pedidos em direção a casa.',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
              const SizedBox(height: 10),
              if (_homeAddressError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(6)),
                  child: Text(_homeAddressError!, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                ),
              if (widget.me?['homeAddress'] != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBDBDBD)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.me!['homeAddress'] as String,
                          style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: _savingHomeAddress
                    ? const Center(child: SizedBox(height: 24, width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                    : OutlinedButton.icon(
                        onPressed: () async {
                          final result = await showAddressPickerSheet(context, title: 'Endereço de Casa');
                          if (result != null) await _saveHomeAddress(result);
                        },
                        icon: const Icon(Icons.edit_location_alt_outlined, size: 18, color: AppColors.primary),
                        label: Text(
                          widget.me?['homeAddress'] != null ? 'Alterar Endereço de Casa' : 'Definir Endereço de Casa',
                          style: const TextStyle(color: AppColors.primary),
                        ),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary)),
                      ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _loading ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Salvar Perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, color: AppColors.primary),
            label: const Text('Sair', style: TextStyle(color: AppColors.primary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
