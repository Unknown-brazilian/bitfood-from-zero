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

const _apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:4000/graphql');
const _wsUrl = String.fromEnvironment('WS_URL', defaultValue: 'ws://10.0.2.2:4000/graphql');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  bool _loading = true;
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
    if (mounted) setState(() { _token = token; _loading = false; });
  }

  GraphQLClient _buildClient(String? token) {
    final http = HttpLink(_apiUrl);
    final ws = WebSocketLink(_wsUrl, config: SocketClientConfig(
      autoReconnect: true,
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
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
