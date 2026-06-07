import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    _initialized = true;
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bitfood_restaurant',
          'Pedidos BitFood',
          channelDescription: 'Novos pedidos e atualizações',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: payload,
    );
  }

  static void showNewOrder(Map order) {
    final orderId = order['orderId'] ?? order['_id'] ?? '';
    final items = (order['items'] as List?)
            ?.map((i) => '${i?['quantity'] ?? ''}x ${i?['title'] ?? ''}'.trim())
            .where((s) => s.isNotEmpty)
            .join(', ') ??
        '';
    final userName = order['user']?['name'] as String?;
    final body = items.isNotEmpty
        ? items
        : (userName != null && userName.isNotEmpty ? userName : 'Toque para ver os detalhes');
    final totalSats = (order['total'] as num?)?.toInt() ?? 0;
    show(
      id: orderId.hashCode,
      title: 'Novo pedido! ⚡ ${_formatSats(totalSats)} sats',
      body: body,
      payload: order['_id']?.toString(),
    );
  }

  static String _formatSats(int value) =>
      value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
