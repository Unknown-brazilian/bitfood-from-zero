import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/queries.dart';
import '../../widgets/tier_card.dart';
import '../auth/login_screen.dart';
import '../order/orders_screen.dart';
import 'addresses_screen.dart';
import 'lightning_wallet_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _name;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _name = prefs.getString('user_name'));
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen(onLoginSuccess: () {})),
        (_) => false,
      );
    }
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajuda & Suporte', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Problemas com seu pedido?', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Entre em contato pelo e-mail:\nsuporte@bitfood.app', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
            SizedBox(height: 16),
            Text('Horário de atendimento', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Segunda a Sexta: 9h – 18h\nSábado: 9h – 14h', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sobre o BitFood', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BitFood é a primeira plataforma de delivery que aceita pagamentos em Bitcoin via Lightning Network.', style: TextStyle(fontSize: 13, height: 1.5)),
            SizedBox(height: 12),
            Text('Versão 1.0.5', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
            Text('© 2025 BitFood. Todos os direitos reservados.', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(meQuery),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (result, {fetchMore, refetch}) {
        final me = result.data?['me'];
        return _buildBody(context, me);
      },
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic>? me) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
            child: Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      (_name?.isNotEmpty == true ? _name![0].toUpperCase() : 'U'),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name ?? 'Usuário', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark)),
                      const Text('Cliente BitFood', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          TierCard(
            tier: me?['tier'] as String? ?? 'NEW',
            score: (me?['reputationScore'] as num?)?.toDouble() ?? 5.0,
            completedOrders: (me?['completedOrders'] as num?)?.toInt() ?? 0,
          ),
          const SizedBox(height: 16),

          // Menu items
          _MenuItem(
            icon: Icons.receipt_long_outlined,
            label: 'Meus Pedidos',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
          ),
          _MenuItem(
            icon: Icons.location_on_outlined,
            label: 'Meus Endereços',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesScreen())),
          ),
          _MenuItem(
            icon: Icons.help_outline,
            label: 'Ajuda & Suporte',
            onTap: _showHelp,
          ),
          _MenuItem(
            icon: Icons.info_outline,
            label: 'Sobre o BitFood',
            onTap: _showAbout,
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.electric_bolt,
            label: 'Bitcoin · Lightning Network ⚡',
            subtitle: 'Conecte sua carteira Lightning',
            color: AppColors.orange,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LightningWalletScreen())),
          ),
          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: AppColors.primary),
              label: const Text('Sair', style: TextStyle(color: AppColors.primary)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;

  const _MenuItem({required this.icon, required this.label, this.subtitle, this.color, this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: color ?? AppColors.textGrey, size: 22),
          title: Text(label, style: TextStyle(fontSize: 14, color: color ?? AppColors.textDark, fontWeight: FontWeight.w500)),
          subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)) : null,
          trailing: const Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
        ),
      );
}
