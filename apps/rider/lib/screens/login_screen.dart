import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  final _emailCtrl   = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();

  bool _loading    = false;
  bool _obscure    = true;
  bool _isRegister = false;
  String _vehicleType = 'MOTORCYCLE';
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
    for (final c in [_emailCtrl, _passwordCtrl, _confirmPasswordCtrl, _nameCtrl, _phoneCtrl, _captchaCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isStrongPassword(String p) {
    return p.length >= 8 &&
        p.contains(RegExp(r'[0-9]')) &&
        p.contains(RegExp(r'[A-Z]')) &&
        p.contains(RegExp(r'[^A-Za-z0-9]'));
  }

  String? _validate() {
    if (_isRegister) {
      if (_nameCtrl.text.trim().isEmpty)   return 'Digite seu nome completo';
      if (_emailCtrl.text.trim().isEmpty)  return 'Digite seu e-mail';
      if (_passwordCtrl.text.isEmpty)      return 'Digite uma senha';
      if (!_isStrongPassword(_passwordCtrl.text)) {
        return 'Senha fraca: use no mínimo 8 caracteres, com pelo menos 1 número, 1 letra maiúscula e 1 caractere especial.';
      }
      if (_confirmPasswordCtrl.text != _passwordCtrl.text) {
        return 'As senhas não conferem. Confirme a mesma senha.';
      }
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
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
      final googleSignIn = GoogleSignIn(
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
        scopes: const ['email'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        setState(() => _loading = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Não foi possível obter o token do Google');

      final client = GraphQLProvider.of(context).value;
      final result = await client.mutate(MutationOptions(
        document: gql(googleAuthMutation),
        variables: {
          'idToken': idToken,
          'userType': 'rider',
          'name': account.displayName,
        },
      ));
      if (result.hasException) throw result.exception!;
      final data = result.data!['googleAuth'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('rider_name', data['name'] ?? '');
      widget.onLogin(data['token']);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Google ainda não configurado')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _passwordRule(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 15, color: ok ? AppColors.success : AppColors.textLight),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontSize: 12,
            color: ok ? AppColors.success : AppColors.textGrey,
          )),
        ],
      ),
    );
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
                  ErrorBox(error: _error!, onRetry: _submit),
                  const SizedBox(height: 8),
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
                  onChanged: _isRegister ? (_) => setState(() {}) : null,
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
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _passwordRule('Mínimo de 8 caracteres', _passwordCtrl.text.length >= 8),
                        _passwordRule('Pelo menos 1 número', _passwordCtrl.text.contains(RegExp(r'[0-9]'))),
                        _passwordRule('Pelo menos 1 letra maiúscula', _passwordCtrl.text.contains(RegExp(r'[A-Z]'))),
                        _passwordRule('Pelo menos 1 caractere especial', _passwordCtrl.text.contains(RegExp(r'[^A-Za-z0-9]'))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar senha',
                      filled: true, fillColor: Colors.white, border: OutlineInputBorder(),
                    ),
                  ),
                ],

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
                  const SizedBox(height: 16),
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
                if (!_isRegister) ...[
                  const SizedBox(height: 16),
                  Row(children: const [
                    Expanded(child: Divider(color: AppColors.divider)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('ou', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: AppColors.divider)),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _googleSignIn,
                      icon: const Icon(Icons.account_circle, color: AppColors.primary),
                      label: const Text('Entrar com Google',
                          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
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
