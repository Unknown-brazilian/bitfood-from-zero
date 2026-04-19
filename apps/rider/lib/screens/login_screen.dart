import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../queries.dart';

class LoginScreen extends StatefulWidget {
  final ValueChanged<String> onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.mutate(MutationOptions(
        document: gql(loginMutation),
        variables: { 'emailOrPhone': _phoneCtrl.text.trim(), 'password': _passwordCtrl.text },
      ));
      if (result.hasException) throw result.exception!;
      final data = result.data!['login'];
      if (data['userType'] != 'RIDER') throw Exception('Acesso restrito a entregadores cadastrados');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('rider_name', data['name'] ?? '');
      widget.onLogin(data['token']);
    } catch (e) {
      setState(() { _error = e.toString().replaceAll(RegExp(r'GraphQLError\(.*?\):\s?'), ''); });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                  child: const Center(child: Text('🏍️', style: TextStyle(fontSize: 32))),
                ),
                const SizedBox(height: 12),
                const Text('BitFood', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const Text('App do Entregador', style: TextStyle(color: AppColors.textGrey)),
                const SizedBox(height: 32),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'E-mail', filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha', filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Entrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
