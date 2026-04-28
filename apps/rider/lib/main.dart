import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'l10n/locale_provider.dart';
import 'screens/language_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

const _apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://api.bitfood.app/graphql');
const _wsUrl = String.fromEnvironment('WS_URL', defaultValue: 'wss://api.bitfood.app/graphql');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  final localeProvider = await LocaleProvider.load();
  runApp(RiderApp(localeProvider: localeProvider));
}

class RiderApp extends StatelessWidget {
  final LocaleProvider localeProvider;
  const RiderApp({super.key, required this.localeProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: localeProvider,
      child: MaterialApp(
        title: 'BitFood Entregador',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  String? _token;
  bool _checkDone = false;
  bool _splashDone = false;
  bool _termsAccepted = false;
  late ValueNotifier<GraphQLClient> _clientNotifier;

  @override
  void initState() {
    super.initState();
    _clientNotifier = ValueNotifier(_buildClient(null));
    _load();
  }

  @override
  void dispose() {
    _clientNotifier.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    _termsAccepted = prefs.getBool('terms_accepted_v1') ?? false;
    _clientNotifier.value = _buildClient(token);
    if (mounted) setState(() { _token = token; _checkDone = true; });
  }

  GraphQLClient _buildClient(String? token) {
    final http = HttpLink(
      _apiUrl,
      defaultHeaders: const {'Accept': 'application/json'},
    );
    final ws = WebSocketLink(_wsUrl, config: SocketClientConfig(
      autoReconnect: true,
      inactivityTimeout: const Duration(seconds: 60),
      initialPayload: token != null ? {'authorization': 'Bearer $token'} : null,
    ));
    final auth = AuthLink(getToken: () async {
      final p = await SharedPreferences.getInstance();
      final t = p.getString('token');
      return t != null ? 'Bearer $t' : null;
    });
    return GraphQLClient(
      link: Link.split((r) => r.isSubscription, ws, auth.concat(http)),
      cache: GraphQLCache(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone || !_checkDone) {
      return _AnimatedSplash(onComplete: () {
        if (mounted) setState(() => _splashDone = true);
      });
    }

    final locale = Provider.of<LocaleProvider>(context);

    if (!locale.isSet) {
      return LanguageScreen(onSelected: () => setState(() {}));
    }

    if (!_termsAccepted) {
      return TermsScreen(
        onAccepted: () => setState(() => _termsAccepted = true),
        onDeclined: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('app_locale');
          locale.setLocale('');
          if (mounted) setState(() {});
        },
      );
    }

    return GraphQLProvider(
      client: _clientNotifier,
      child: _token != null
          ? HomeScreen(onLogout: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              _clientNotifier.value = _buildClient(null);
              if (mounted) setState(() => _token = null);
            })
          : LoginScreen(onLogin: (token) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('token', token);
              _clientNotifier.value = _buildClient(token);
              if (mounted) setState(() => _token = token);
            }),
    );
  }
}

class _AnimatedSplash extends StatefulWidget {
  final VoidCallback onComplete;
  const _AnimatedSplash({required this.onComplete});

  @override
  State<_AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<_AnimatedSplash> with SingleTickerProviderStateMixin {
  static const _messages = [
    '1st Bitcoin Only\nfood delivery app',
    'We prefer\nWallet of Satoshi ⚡',
    'Work everywhere you want,\nwith no borders',
  ];

  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  int _msgIndex = 0;
  Timer? _doneTimer;
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.forward();
    _cycle();
    _doneTimer = Timer(const Duration(seconds: 10), widget.onComplete);
  }

  void _cycle() {
    _cycleTimer = Timer(const Duration(milliseconds: 3000), () async {
      if (!mounted) return;
      await _ctrl.reverse();
      if (!mounted) return;
      setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);
      _ctrl.forward();
      _cycle();
    });
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _cycleTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 24, spreadRadius: 4)],
                ),
                child: const Center(child: Text('🏍️', style: TextStyle(fontSize: 44))),
              ),
              const SizedBox(height: 20),
              const Text('BitFood',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
              const SizedBox(height: 6),
              const Text('App do Entregador', style: TextStyle(color: Color(0xFFF7931A), fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 64),
              FadeTransition(
                opacity: _fade,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    _messages[_msgIndex],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 19,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
