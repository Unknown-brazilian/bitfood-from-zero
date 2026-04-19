import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GraphQLService {
  static const String _apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:4000/graphql',
  );
  static const String _wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://10.0.2.2:4000/graphql',
  );

  static late ValueNotifier<GraphQLClient> client;

  static GraphQLClient _buildClient([String? token]) {
    final httpLink = HttpLink(_apiUrl);
    final wsLink = WebSocketLink(
      _wsUrl,
      config: SocketClientConfig(
        autoReconnect: true,
        inactivityTimeout: const Duration(seconds: 30),
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
