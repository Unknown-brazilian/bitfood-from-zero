import 'dart:math';
import 'package:flutter/material.dart';
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
  bool _loading = false;
  bool _obscure = true;
  Object? _error;
  bool _isRegister = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
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
      await AuthService.saveToken(data['token']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', data['name']);
      await prefs.setString('user_id', data['userId']);
      widget.onLoginSuccess();
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() { _loading = false; });
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
                          labelText: _isRegister ? 'E-mail (opcional)' : 'E-mail ou telefone',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => !_isRegister && (v == null || v.trim().isEmpty)
                            ? 'Digite seu e-mail ou telefone'
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
                        validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                      ),
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
