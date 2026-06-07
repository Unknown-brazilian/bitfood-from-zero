import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/queries.dart';
import '../../widgets/error_box.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;
  Object? _error;
  bool _isRegister = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();
  int _captchaA = 0, _captchaB = 0;
  String? _captchaError;

  static const String _googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  // Validação de senha forte: mín. 8, ≥1 número, ≥1 maiúscula, ≥1 especial.
  String? _validateStrongPassword(String? v) {
    final value = v ?? '';
    if (value.length < 8) return 'A senha deve ter no mínimo 8 caracteres';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Inclua ao menos um número';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Inclua ao menos uma letra maiúscula';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Inclua ao menos um caractere especial';
    }
    return null;
  }

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
      QueryResult result;

      if (_isRegister) {
        result = await client.mutate(MutationOptions(
          document: gql(registerMutation),
          variables: {
            'name': _nameCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            'password': _passwordCtrl.text,
          },
        ));
      } else {
        result = await client.mutate(MutationOptions(
          document: gql(loginMutation),
          variables: {
            'emailOrPhone': _emailCtrl.text.trim(),
            'password': _passwordCtrl.text,
          },
        ));
      }

      if (result.hasException) throw result.exception!;
      final data = _isRegister ? result.data!['register'] : result.data!['login'];
      await _saveSession(data);
      widget.onLoginSuccess();
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _saveSession(Map<String, dynamic>? data) async {
    final token = data?['token'] as String?;
    if (token == null) throw Exception('Token não recebido do servidor');
    await AuthService.saveToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', (data!['name'] as String?) ?? '');
    await prefs.setString('user_id', (data['userId'] as String?) ?? '');
  }

  Future<void> _googleSignIn() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: _googleServerClientId.isEmpty ? null : _googleServerClientId,
        scopes: const ['email'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        // Usuário cancelou o fluxo.
        setState(() => _googleLoading = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('idToken não recebido do Google');

      final client = GraphQLProvider.of(context).value;
      final result = await client.mutate(MutationOptions(
        document: gql(googleAuthMutation),
        variables: {
          'idToken': idToken,
          'userType': 'customer',
          'name': account.displayName,
        },
      ));
      if (result.hasException) throw result.exception!;
      await _saveSession(result.data!['googleAuth'] as Map<String, dynamic>?);
      if (mounted) widget.onLoginSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Login Google ainda não configurado'),
          backgroundColor: AppColors.primary,
        ));
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 56),
              // Logo
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Text('B', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('BitFood', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 4),
              const Text('Peça comida, pague com Bitcoin ⚡', style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
              const SizedBox(height: 40),

              // Card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isRegister ? 'Criar conta' : 'Entrar',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 20),

                      if (_error != null) ...[
                        ErrorBox(error: _error!, onRetry: _submit),
                        const SizedBox(height: 8),
                      ],

                      if (_isRegister) ...[
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'Nome completo'),
                          validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Verificação: quanto é $_captchaA + $_captchaB?',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _captchaCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: 'Sua resposta', isDense: true),
                              ),
                              if (_captchaError != null) ...[
                                const SizedBox(height: 6),
                                Text(_captchaError!, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextFormField(
                        controller: _emailCtrl,
                        decoration: InputDecoration(
                          labelText: _isRegister ? 'E-mail' : 'E-mail ou telefone',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? (_isRegister ? 'Digite seu e-mail' : 'Digite seu e-mail ou telefone')
                            : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textLight),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => _isRegister
                            ? _validateStrongPassword(v)
                            : (v!.isEmpty ? 'Digite sua senha' : null),
                      ),

                      if (_isRegister) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: const Text(
                            'A senha deve ter no mínimo 8 caracteres, incluindo ao menos '
                            'uma letra maiúscula, um número e um caractere especial.',
                            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPasswordCtrl,
                          obscureText: _obscure,
                          decoration: const InputDecoration(labelText: 'Confirmar senha'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Confirme sua senha';
                            if (v != _passwordCtrl.text) return 'As senhas não coincidem';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(_isRegister ? 'Criar conta' : 'Entrar'),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: const [
                          Expanded(child: Divider(color: AppColors.divider)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('ou', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: AppColors.divider)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _googleLoading ? null : _googleSignIn,
                          icon: _googleLoading
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                              : const Icon(Icons.login, color: AppColors.textDark, size: 18),
                          label: const Text('Entrar com Google', style: TextStyle(color: AppColors.textDark)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.divider),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() { _isRegister = !_isRegister; _error = null; }),
                child: Text(
                  _isRegister ? 'Já tenho conta · Entrar' : 'Não tenho conta · Criar',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
