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
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
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
    for (final c in [_usernameCtrl, _passwordCtrl, _confirmPasswordCtrl, _nameCtrl, _emailCtrl, _phoneCtrl, _addressCtrl, _captchaCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _passwordStrengthError(String pwd) {
    if (pwd.length < 8) return 'A senha deve ter no mínimo 8 caracteres';
    if (!RegExp(r'[0-9]').hasMatch(pwd)) return 'A senha deve conter ao menos 1 número';
    if (!RegExp(r'[A-Z]').hasMatch(pwd)) return 'A senha deve conter ao menos 1 letra maiúscula';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) return 'A senha deve conter ao menos 1 caractere especial';
    return null;
  }

  String? _validate() {
    if (_isRegister) {
      if (_nameCtrl.text.trim().isEmpty)    return 'Digite o nome do restaurante';
      if (_emailCtrl.text.trim().isEmpty)   return 'Digite o e-mail';
      if (_passwordCtrl.text.isEmpty)       return 'Digite sua senha';
      final pwdError = _passwordStrengthError(_passwordCtrl.text);
      if (pwdError != null)                 return pwdError;
      if (_confirmPasswordCtrl.text != _passwordCtrl.text) return 'As senhas não coincidem';
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
        final data = result.data?['registerRestaurant'];
        final token = data?['token'] as String?;
        if (data == null || token == null) {
          throw 'Não foi possível criar a conta. Verifique os dados e tente novamente.';
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('restaurant_id', data['restaurantId'] ?? '');
        await prefs.setString('restaurant_name', data['name'] ?? '');
        widget.onLogin(token);
      } else {
        final result = await client.mutate(MutationOptions(
          document: gql(loginRestaurantMutation),
          variables: {
            'emailOrUsername': _usernameCtrl.text.trim(),
            'password': _passwordCtrl.text,
          },
        ));
        if (result.hasException) throw result.exception!;
        final data = result.data?['loginRestaurant'];
        final token = data?['token'] as String?;
        if (data == null || token == null) {
          throw 'E-mail/username ou senha inválidos.';
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('restaurant_id', data['restaurantId'] ?? '');
        await prefs.setString('restaurant_name', data['name'] ?? '');
        widget.onLogin(token);
      }
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
        scopes: ['email'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        setState(() => _loading = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw 'Não foi possível obter o token do Google.';

      if (!mounted) return;
      final client = GraphQLProvider.of(context).value;
      final result = await client.mutate(MutationOptions(
        document: gql(googleAuthMutation),
        variables: {
          'idToken': idToken,
          'userType': 'restaurant',
          'name': account.displayName,
        },
      ));
      if (result.hasException) throw result.exception!;
      final data = result.data?['googleAuth'];
      final token = data?['token'] as String?;
      if (data == null || token == null) {
        throw 'Não foi possível entrar com o Google.';
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('restaurant_id', data['restaurantId'] ?? '');
      await prefs.setString('restaurant_name', data['name'] ?? '');
      widget.onLogin(token);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login Google ainda não configurado')),
      );
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
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('A senha deve conter:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        SizedBox(height: 4),
                        Text('• mínimo de 8 caracteres', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        Text('• ao menos 1 número', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        Text('• ao menos 1 letra maiúscula', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        Text('• ao menos 1 caractere especial', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                  _field(_confirmPasswordCtrl, 'Confirmar senha', obscure: _obscure),
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
                if (!_isRegister) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Expanded(child: Divider(color: AppColors.divider)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('ou', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      ),
                      Expanded(child: Divider(color: AppColors.divider)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _googleSignIn,
                      icon: const Text('G', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary)),
                      label: const Text('Entrar com Google',
                          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
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
