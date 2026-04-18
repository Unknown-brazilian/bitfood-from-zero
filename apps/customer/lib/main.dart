import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/cart_model.dart';
import 'services/graphql_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GraphQLService.init();
  runApp(const BitFoodApp());
}

class BitFoodApp extends StatelessWidget {
  const BitFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartModel(),
      child: ValueListenableBuilder<GraphQLClient>(
        valueListenable: GraphQLService.client,
        builder: (context, client, _) {
          return GraphQLProvider(
            client: GraphQLService.client,
            child: MaterialApp(
              title: 'BitFood',
              theme: AppTheme.theme,
              debugShowCheckedModeBanner: false,
              home: const _AppRoot(),
            ),
          );
        },
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

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    _loggedIn = await AuthService.isLoggedIn();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
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

    if (_loggedIn) return const HomeScreen();

    return LoginScreen(
      onLoginSuccess: () => setState(() => _loggedIn = true),
    );
  }
}
