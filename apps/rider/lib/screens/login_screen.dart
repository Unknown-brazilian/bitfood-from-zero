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
  final _emailCtrl   = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();

  bool _loading    = false;
  bool _obscure    = true;
  bool _isRegister = false;
  String _vehicleType = 'MOTORCYCLE';
  String? _error;

  @override
  void dispose() {
    for (final c in [_emailCtrl, _passwordCtrl, _nameCtrl, _phoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_isRegister) {
      if (_nameCtrl.text.trim().isEmpty)   return 'Digite seu nome completo';
      if (_emailCtrl.text.trim().isEmpty)  return 'Digite seu e-mail';
      if (!_emailCtrl.text.contains('@'))  return 'E-mail inválido';
      if (_passwordCtrl.text.length < 6)   return 'A senha precisa ter pelo menos 6 caracteres';
    } else {
      if (_emailCtrl.text.trim().isEmpty)  return 'Digite seu e-mail';
      if (_passwordCtrl.text.isEmpty)      return 'Digite sua senha';
    }
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final client = GraphQLProvider.of(context).value;

      if (_isRegister) {
        final result = await client.mutate(MutationOptions(
          document: gql(registerRiderMutation),
          variables: {
            'name': _nameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'password': _passwordCtrl.text,
            if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
            'vehicleType': _vehicleType,
          },
        ));
        if (result.hasException) throw result.exception!;
        final data = result.data!['registerRider'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('rider_name', data['name'] ?? '');
        widget.onLogin(data['token']);
      } else {
        final result = await client.mutate(MutationOptions(
          document: gql(loginMutation),
          variables: {
            'emailOrPhone': _emailCtrl.text.trim(),
            'password': _passwordCtrl.text,
          },
        ));
        if (result.hasException) throw result.exception!;
        final data = result.data!['login'];
        if (data['userType'] != 'RIDER') throw Exception('Acesso restrito a entregadores cadastrados');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('rider_name', data['name'] ?? '');
        widget.onLogin(data['token']);
      }
    } catch (e) {
      setState(() {
        _error = e.toString()
            .replaceAll(RegExp(r'OperationException.*?:\s?'), '')
            .replaceAll(RegExp(r'GraphQLError\(.*?\):\s?'), '');
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _vehicleCard(String type, String label, IconData icon) {
    final selected = _vehicleType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vehicleType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.textGrey, size: 20),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                color: selected ? Colors.white : AppColors.textGrey,
                fontWeight: FontWeight.w600, fontSize: 13,
              )),
            ],
          ),
        ),
      ),
    );
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
                Text(_isRegister ? 'Cadastro de Entregador' : 'App do Entregador',
                    style: const TextStyle(color: AppColors.textGrey)),
                const SizedBox(height: 28),

                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.primary, fontSize: 13))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_isRegister) ...[
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome completo', filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'E-mail', filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                if (_isRegister) ...[
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefone (opcional)', filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    filled: true, fillColor: Colors.white, border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textLight),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),

                if (_isRegister) ...[
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Tipo de veículo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    _vehicleCard('BICYCLE', 'Bicicleta', Icons.pedal_bike),
                    const SizedBox(width: 10),
                    _vehicleCard('MOTORCYCLE', 'Moto', Icons.two_wheeler),
                  ]),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_isRegister ? 'Criar conta' : 'Entrar',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() { _isRegister = !_isRegister; _error = null; }),
                  child: Text(
                    _isRegister ? 'Já tenho conta · Entrar' : 'Não tenho conta · Cadastrar',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
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
