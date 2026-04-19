import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../queries.dart';

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
  String _vehicleType = 'BICYCLE';
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    final me = widget.me ?? {};
    _nameCtrl = TextEditingController(text: me['name'] ?? '');
    _vehicleType = me['vehicleType'] ?? 'BICYCLE';
  }

  @override
  void didUpdateWidget(_ProfileBody old) {
    super.didUpdateWidget(old);
    if (old.me != widget.me && widget.me != null) {
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = widget.me!['name'] ?? '';
      setState(() => _vehicleType = widget.me!['vehicleType'] ?? 'BICYCLE');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _nameLocked => widget.me?['nameLocked'] == true;

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
