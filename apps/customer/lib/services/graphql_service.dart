import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GraphQLService {
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.bitfood.app',
  );
  static String get baseUrl => _baseUrl.replaceAll(RegExp(r'/graphql$'), '');
  static final String _apiUrl = '${_baseUrl.replaceAll(RegExp(r'/graphql$'), '')}/graphql';
  static final String _wsUrl = '${_baseUrl.replaceAll(RegExp(r'/graphql$'), '').replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://')}/graphql';

  static late ValueNotifier<GraphQLClient> client;

  static GraphQLClient _buildClient([String? token]) {
    final httpLink = HttpLink(
      _apiUrl,
      defaultHeaders: const {'Accept': 'application/json'},
    );
    final wsLink = WebSocketLink(
      _wsUrl,
      config: SocketClientConfig(
        autoReconnect: true,
        inactivityTimeout: const Duration(seconds: 60),
        initialPayload: token != null ? {'authorization': 'Bearer $token'} : null,
      ),
    );
    final authLink = AuthLink(
      getToken: () async {
        final prefs = await SharedPreferences.getInstance();
        final t = prefs.getString('token');
        return t != null ? 'Bearer $t' : null;
      },
    );
    return GraphQLClient(
      link: Link.split(
        (request) => request.isSubscription,
        wsLink,
        authLink.concat(httpLink),
      ),
      cache: GraphQLCache(),
    );
  }

  static Future<void> refreshClient() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    client.value = _buildClient(token);
  }

  static Future<void> init() async {
    client = ValueNotifier(_buildClient());
    await refreshClient();
  }
}
