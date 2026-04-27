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
      options: QueryOptions(document: gql(meRestaurantQuery), fetchPolicy: FetchPolicy.cacheAndNetwork),
      builder: (result, {fetchMore, refetch}) {
        final r = result.data?['myRestaurant'];
        return _ProfileBody(restaurant: r, refetch: refetch, onLogout: onLogout);
      },
    );
  }
}

class _ProfileBody extends StatefulWidget {
  final Map<String, dynamic>? restaurant;
  final Refetch? refetch;
  final VoidCallback onLogout;
  const _ProfileBody({this.restaurant, this.refetch, required this.onLogout});

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _logoCtrl;
  late final TextEditingController _lightningCtrl;
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    final r = widget.restaurant ?? {};
    _nameCtrl = TextEditingController(text: r['name'] ?? '');
    _phoneCtrl = TextEditingController(text: r['phone'] ?? '');
    _addressCtrl = TextEditingController(text: r['address'] ?? '');
    _logoCtrl = TextEditingController(text: r['logo'] ?? '');
    _lightningCtrl = TextEditingController(text: r['lightningAddress'] ?? '');
  }

  @override
  void didUpdateWidget(_ProfileBody old) {
    super.didUpdateWidget(old);
    if (old.restaurant != widget.restaurant && widget.restaurant != null) {
      final r = widget.restaurant!;
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = r['name'] ?? '';
      if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = r['phone'] ?? '';
      if (_addressCtrl.text.isEmpty) _addressCtrl.text = r['address'] ?? '';
      if (_logoCtrl.text.isEmpty) _logoCtrl.text = r['logo'] ?? '';
      if (_lightningCtrl.text.isEmpty) _lightningCtrl.text = r['lightningAddress'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _logoCtrl.dispose();
    _lightningCtrl.dispose();
    super.dispose();
  }

  bool get _nameLocked => widget.restaurant?['nameLocked'] == true;

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.mutate(MutationOptions(
        document: gql(updateRestaurantProfileMutation),
        variables: {
          if (!_nameLocked) 'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          if (_logoCtrl.text.trim().isNotEmpty) 'logo': _logoCtrl.text.trim(),
          'lightningAddress': _lightningCtrl.text.trim().isEmpty ? null : _lightningCtrl.text.trim(),
        },
      ));
      if (result.hasException) throw result.exception!;
      final newName = result.data?['updateRestaurantProfile']?['name'];
      if (newName != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('restaurant_name', newName);
      }
      widget.refetch?.call();
      setState(() { _success = 'Perfil atualizado com sucesso!'; _loading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll(RegExp(r'OperationException.*?:\s?'), '');
        _loading = false;
      });
    }
  }

  Widget _field(String label, TextEditingController ctrl, {bool enabled = true, String? hint, TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          enabled: enabled,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? const Color(0xFFF5F5F5) : const Color(0xFFEEEEEE),
            border: const OutlineInputBorder(),
            suffixIcon: !enabled ? const Icon(Icons.lock_outline, size: 18, color: AppColors.textLight) : null,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.restaurant?['name'] ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Perfil do Restaurante'),
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
                      name.isNotEmpty ? name[0].toUpperCase() : 'R',
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(name.isNotEmpty ? name : 'Restaurante', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark)),
                const Text('Restaurante BitFood', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
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

          _field('Nome do Restaurante', _nameCtrl, enabled: !_nameLocked),
          _field('Telefone', _phoneCtrl, keyboard: TextInputType.phone, hint: '+55 11 99999-9999'),
          _field('Endereço', _addressCtrl, hint: 'Rua das Flores, 123 - São Paulo, SP'),
          _field('Logo (URL da imagem)', _logoCtrl, hint: 'https://...', keyboard: TextInputType.url),
          _field('Lightning Address ⚡', _lightningCtrl,
              hint: 'ex: restaurante@walletofsatoshi.com',
              keyboard: TextInputType.emailAddress),

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
