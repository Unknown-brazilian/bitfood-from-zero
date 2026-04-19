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
          'bitfood_rider',
          'Entregas BitFood',
          channelDescription: 'Novos pedidos disponíveis para entrega',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: payload,
    );
  }

  static void showNewDelivery(Map order) {
    final orderId = order['orderId'] ?? order['_id'] ?? '';
    final restaurant = (order['restaurant'] as Map?)?['name'] ?? 'Restaurante';
    final totalSats = order['total'] ?? 0;
    show(
      id: orderId.hashCode,
      title: 'Nova entrega disponível! 🏍️',
      body: '$restaurant · $totalSats sats',
      payload: order['_id']?.toString(),
    );
  }
}
