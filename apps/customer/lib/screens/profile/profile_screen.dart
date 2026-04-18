import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

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
        MaterialPageRoute(builder: (_) => LoginScreen(onLoginSuccess: () {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const _HomeWrapper()), (_) => false);
        })),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 16),

          // Menu items
          _MenuItem(icon: Icons.receipt_long_outlined, label: 'Meus Pedidos'),
          _MenuItem(icon: Icons.location_on_outlined, label: 'Meus Endereços'),
          _MenuItem(icon: Icons.help_outline, label: 'Ajuda & Suporte'),
          _MenuItem(icon: Icons.info_outline, label: 'Sobre o BitFood'),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.electric_bolt,
            label: 'Bitcoin · Lightning Network ⚡',
            subtitle: 'Pagamentos sem fronteiras',
            color: AppColors.orange,
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

  const _MenuItem({required this.icon, required this.label, this.subtitle, this.color});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
        child: ListTile(
          leading: Icon(icon, color: color ?? AppColors.textGrey, size: 22),
          title: Text(label, style: TextStyle(fontSize: 14, color: color ?? AppColors.textDark, fontWeight: FontWeight.w500)),
          subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)) : null,
          trailing: const Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
        ),
      );
}

// Placeholder to avoid import cycle
class _HomeWrapper extends StatelessWidget {
  const _HomeWrapper();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Reiniciando...')));
}
