import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

const _apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:4000/graphql');
const _wsUrl = String.fromEnvironment('WS_URL', defaultValue: 'ws://10.0.2.2:4000/graphql');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForFlutter();
  runApp(const RiderApp());
}

class RiderApp extends StatelessWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BitFood Entregador',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const _Root(),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _token = prefs.getString('token'); _loading = false; });
  }

  GraphQLClient _client(String? token) {
    final http = HttpLink(_apiUrl);
    final ws = WebSocketLink(_wsUrl,
      config: SocketClientConfig(
        autoReconnect: true,
        initialPayload: token != null ? {'authorization': 'Bearer $token'} : null,
      ),
    );
    final auth = AuthLink(getToken: () async {
      final p = await SharedPreferences.getInstance();
      final t = p.getString('token');
      return t != null ? 'Bearer $t' : null;
    });
    return GraphQLClient(
      link: Link.split((r) => r.isSubscription, ws, auth.concat(http)),
      cache: GraphQLCache(store: HiveStore()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    return GraphQLProvider(
      client: ValueNotifier(_client(_token)),
      child: _token != null
          ? const HomeScreen()
          : LoginScreen(onLogin: (token) => setState(() => _token = token)),
    );
  }
}
