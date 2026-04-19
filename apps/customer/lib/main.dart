import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/cart_model.dart';
import 'services/graphql_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'l10n/locale_provider.dart';
import 'screens/language_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GraphQLService.init();
  final localeProvider = await LocaleProvider.load();
  runApp(BitFoodApp(localeProvider: localeProvider));
}

class BitFoodApp extends StatelessWidget {
  final LocaleProvider localeProvider;
  const BitFoodApp({super.key, required this.localeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider(create: (_) => CartModel()),
      ],
      child: GraphQLProvider(
        client: GraphQLService.client,
        child: MaterialApp(
          title: 'BitFood',
          theme: AppTheme.theme,
          debugShowCheckedModeBanner: false,
          home: const _AppRoot(),
        ),
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _loggedIn = false;
  bool _loading = true;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    _termsAccepted = prefs.getBool('terms_accepted_v1') ?? false;
    _loggedIn = await AuthService.isLoggedIn();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();

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

    if (_loggedIn) return const HomeScreen();

    return LoginScreen(
      onLoginSuccess: () => setState(() => _loggedIn = true),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('B', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: AppColors.primary)),
          SizedBox(height: 12),
          Text('BitFood', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          SizedBox(height: 4),
          Text('⚡ Bitcoin Lightning', style: TextStyle(color: AppColors.orange, fontSize: 13)),
        ],
      ),
    ),
  );
}
