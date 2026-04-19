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
          'bitfood_orders',
          'Pedidos BitFood',
          channelDescription: 'Notificações de pedidos',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: payload,
    );
  }

  static void showOrderStatus(String status, String orderId) {
    final messages = {
      'ACCEPTED': ('Pedido aceito! ✅', 'Seu pedido está sendo preparado.'),
      'PREPARING': ('Em preparo 🍳', 'O restaurante está preparando seu pedido.'),
      'READY': ('Pronto para entrega! 🎉', 'Um entregador vai buscar seu pedido em breve.'),
      'ASSIGNED': ('Entregador a caminho 🏍️', 'Seu pedido foi coletado e está a caminho.'),
      'PICKED': ('Saiu para entrega 🚀', 'Seu pedido está a caminho!'),
      'DELIVERED': ('Pedido entregue! ⚡', 'Bom apetite! Pague em sats e aproveite.'),
      'REJECTED': ('Pedido recusado ❌', 'O restaurante não pôde aceitar seu pedido.'),
      'CANCELLED': ('Pedido cancelado', 'Seu pedido foi cancelado.'),
    };
    final msg = messages[status];
    if (msg != null) {
      show(id: orderId.hashCode, title: msg.$1, body: msg.$2, payload: orderId);
    }
  }
}
