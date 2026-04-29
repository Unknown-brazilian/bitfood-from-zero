import 'dart:math';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../queries.dart';
import '../widgets/error_box.dart';

class LoginScreen extends StatefulWidget {
  final ValueChanged<String> onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _addressCtrl  = TextEditingController();

  bool _loading  = false;
  bool _obscure  = true;
  bool _isRegister = false;
  Object? _error;
  final _captchaCtrl = TextEditingController();
  int _captchaA = 0, _captchaB = 0;
  String? _captchaError;

  @override
  void initState() {
    super.initState();
    _regenerateCaptcha();
  }

  void _regenerateCaptcha() {
    final rng = Random();
    _captchaA = rng.nextInt(9) + 1;
    _captchaB = rng.nextInt(9) + 1;
    _captchaCtrl.clear();
    _captchaError = null;
  }

  @override
  void dispose() {
    for (final c in [_usernameCtrl, _passwordCtrl, _nameCtrl, _emailCtrl, _phoneCtrl, _addressCtrl, _captchaCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_isRegister) {
      if (_nameCtrl.text.trim().isEmpty)    return 'Digite o nome do restaurante';
      if (_emailCtrl.text.trim().isEmpty)   return 'Digite o e-mail';
      if (_passwordCtrl.text.length < 6)    return 'A senha precisa ter pelo menos 6 caracteres';
    } else {
      if (_usernameCtrl.text.trim().isEmpty) return 'Digite seu e-mail ou username';
      if (_passwordCtrl.text.isEmpty)        return 'Digite sua senha';
    }
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    if (_isRegister) {
      final answer = int.tryParse(_captchaCtrl.text.trim());
      if (answer != _captchaA + _captchaB) {
        setState(() { _captchaError = 'Resposta incorreta. Tente novamente.'; });
        _regenerateCaptcha();
        return;
      }
    }
    setState(() { _loading = true; _error = null; });
    try {
      final client = GraphQLProvider.of(context).value;

      if (_isRegister) {
        final result = await client.mutate(MutationOptions(
          document: gql(registerRestaurantMutation),
          variables: {
            'name': _nameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'password': _passwordCtrl.text,
            if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
            if (_addressCtrl.text.trim().isNotEmpty) 'address': _addressCtrl.text.trim(),
          },
        ));
        if (result.hasException) throw result.exception!;
        final data = result.data!['registerRestaurant'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('restaurant_id', data['restaurantId'] ?? '');
        await prefs.setString('restaurant_name', data['name'] ?? '');
        widget.onLogin(data['token']);
      } else {
        final result = await client.mutate(MutationOptions(
          document: gql(loginRestaurantMutation),
          variables: {
            'emailOrUsername': _usernameCtrl.text.trim(),
            'password': _passwordCtrl.text,
          },
        ));
        if (result.hasException) throw result.exception!;
        final data = result.data!['loginRestaurant'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('restaurant_id', data['restaurantId'] ?? '');
        await prefs.setString('restaurant_name', data['name'] ?? '');
        widget.onLogin(data['token']);
      }
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType? keyboard, bool obscure = false, bool optional = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          obscureText: obscure,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: optional ? '$label (opcional)' : label,
            filled: true,
            fillColor: Colors.white,
            border: const OutlineInputBorder(),
            suffixIcon: obscure
                ? IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textLight),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
      ],
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
                  child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 32))),
                ),
                const SizedBox(height: 12),
                const Text('BitFood', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                Text(_isRegister ? 'Cadastro do Restaurante' : 'Painel do Restaurante',
                    style: const TextStyle(color: AppColors.textGrey)),
                const SizedBox(height: 28),

                if (_error != null) ...[
                  ErrorBox(error: _error!, onRetry: _submit),
                  const SizedBox(height: 8),
                ],

                if (_isRegister) ...[
                  _field(_nameCtrl, 'Nome do restaurante'),
                  _field(_emailCtrl, 'E-mail', keyboard: TextInputType.emailAddress),
                  _field(_passwordCtrl, 'Senha', obscure: _obscure),
                  _field(_phoneCtrl, 'Telefone', keyboard: TextInputType.phone, optional: true),
                  _field(_addressCtrl, 'Endereço', optional: true),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Verificação: quanto é $_captchaA + $_captchaB?',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _captchaCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: 'Sua resposta', filled: true, fillColor: Colors.white, border: OutlineInputBorder(), isDense: true),
                        ),
                        if (_captchaError != null) ...[
                          const SizedBox(height: 6),
                          Text(_captchaError!, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  _field(_usernameCtrl, 'E-mail ou username'),
                  _field(_passwordCtrl, 'Senha', obscure: _obscure),
                ],

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
