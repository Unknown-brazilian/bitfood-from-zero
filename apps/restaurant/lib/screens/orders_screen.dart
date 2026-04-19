import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../queries.dart';
import '../services/notification_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _tabs = ['PAID', 'ACCEPTED', 'PREPARING', 'READY'];
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _loadRestaurantId();
  }

  Future<void> _loadRestaurantId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _restaurantId = prefs.getString('restaurant_id'));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_restaurantId != null && _restaurantId!.isNotEmpty)
          Subscription(
            options: SubscriptionOptions(
              document: gql(newOrderSub),
              variables: {'restaurantId': _restaurantId},
            ),
            builder: (result) {
              if (!result.isLoading && result.data != null) {
                final order = result.data!['newOrderForRestaurant'];
                if (order != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    NotificationService.showNewOrder(order);
                  });
                }
              }
              return const SizedBox.shrink();
            },
          ),
        Container(
          color: AppColors.cardWhite,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            indicatorColor: AppColors.primary,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Novos'),
              Tab(text: 'Aceitos'),
              Tab(text: 'Preparando'),
              Tab(text: 'Prontos'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: _tabs.map((status) => _OrderList(status: status)).toList(),
          ),
        ),
      ],
    );
  }
}

class _OrderList extends StatelessWidget {
  final String status;
  const _OrderList({required this.status});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(restaurantOrdersQuery),
        variables: {'status': status},
        pollInterval: const Duration(seconds: 10),
      ),
      builder: (result, {fetchMore, refetch}) {
        final orders = (result.data?['restaurantOrders']?['orders'] as List?) ?? [];

        if (result.isLoading && orders.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty, size: 48, color: AppColors.textLight),
                const SizedBox(height: 8),
                Text('Nenhum pedido ${_label(status).toLowerCase()}', style: const TextStyle(color: AppColors.textGrey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => refetch!(),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (_, i) => _OrderCard(order: orders[i], onAction: refetch!),
          ),
        );
      },
    );
  }

  String _label(String s) {
    const m = {'PAID': 'Novos', 'ACCEPTED': 'Aceitos', 'PREPARING': 'Preparando', 'READY': 'Prontos'};
    return m[s] ?? s;
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onAction;

  const _OrderCard({required this.order, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final status = order['orderStatus'] as String;
    final items = (order['items'] as List?) ?? [];
    final total = order['total'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('#${order['orderId']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
                    const Spacer(),
                    Row(children: [
                      const Icon(Icons.electric_bolt, color: AppColors.orange, size: 14),
                      const SizedBox(width: 2),
                      Text('${total.toLocaleString()} sats', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
                    ]),
                  ],
                ),
                const SizedBox(height: 4),
                Text(order['user']?['name'] ?? '', style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                if (order['user']?['phone'] != null)
                  Text(order['user']['phone'], style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                const SizedBox(height: 8),
                ...items.map((item) => Text(
                  '${item['quantity']}x ${item['title']}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                )),
                if (order['deliveryAddress']?['address'] != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(order['deliveryAddress']['address'], style: const TextStyle(fontSize: 12, color: AppColors.textGrey), overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                if (order['specialInstructions'] != null) ...[
                  const SizedBox(height: 4),
                  Text('📝 ${order['specialInstructions']}', style: const TextStyle(fontSize: 12, color: AppColors.orange)),
                ],
              ],
            ),
          ),

          // Action buttons
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              children: _buildActions(context, status, order['_id']),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, String status, String orderId) {
    if (status == 'PAID') {
      return [
        _ActionBtn(label: 'Rejeitar', color: AppColors.textGrey, mutation: rejectOrderMutation, orderId: orderId, onDone: onAction),
        _ActionBtn(label: 'Aceitar', color: AppColors.success, mutation: acceptOrderMutation, orderId: orderId, onDone: onAction),
      ];
    }
    if (status == 'ACCEPTED') {
      return [_ActionBtn(label: 'Iniciar Preparo', color: AppColors.orange, mutation: markPreparingMutation, orderId: orderId, onDone: onAction)];
    }
    if (status == 'PREPARING') {
      return [_ActionBtn(label: 'Marcar como Pronto', color: AppColors.success, mutation: markReadyMutation, orderId: orderId, onDone: onAction)];
    }
    return [Padding(padding: const EdgeInsets.all(12), child: Text('Aguardando entregador', style: TextStyle(color: AppColors.textGrey, fontSize: 13)))];
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final String mutation;
  final String orderId;
  final VoidCallback onDone;

  const _ActionBtn({required this.label, required this.color, required this.mutation, required this.orderId, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Mutation(
        options: MutationOptions(document: gql(mutation)),
        builder: (runMutation, result) {
          return TextButton(
            onPressed: result?.isLoading == true ? null : () async {
              await runMutation({'orderId': orderId}).networkResult;
              onDone();
            },
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: result?.isLoading == true
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          );
        },
      ),
    );
  }
}

extension on int {
  String toLocaleString() => toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
