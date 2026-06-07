import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/cart_model.dart';
import '../../services/queries.dart';
import '../checkout/payment_screen.dart';
import '../order/order_detail_screen.dart';
import '../profile/addresses_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _addressCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _couponCtrl = TextEditingController();
  bool _placing = false;
  String? _couponError;
  Map<String, dynamic>? _coupon;

  List<Map<String, dynamic>> _addresses = [];
  Map<String, dynamic>? _selectedAddress;
  bool _addressesLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAddresses());
  }

  Future<void> _loadAddresses() async {
    final result = await GraphQLProvider.of(context).value.query(QueryOptions(
          document: gql(meQuery),
          fetchPolicy: FetchPolicy.cacheAndNetwork,
        ));
    if (!mounted) return;
    final list = ((result.data?['me']?['addresses'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    Map<String, dynamic>? defaultAddr;
    if (list.isNotEmpty) {
      defaultAddr = list.firstWhere(
        (a) => a['isDefault'] == true,
        orElse: () => list.first,
      );
    }
    setState(() {
      _addresses = list;
      _selectedAddress = defaultAddr;
      _addressesLoaded = true;
      if (defaultAddr != null) {
        _addressCtrl.text = (defaultAddr['address'] as String?) ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Meu Carrinho'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Items
                ...cart.items.map((item) => _CartItemRow(
                  item: item,
                  onRemove: () => cart.removeItem(item.foodId, variationId: item.variationId),
                  onDecrease: () => cart.updateQuantity(item.foodId, item.quantity - 1, variationId: item.variationId),
                  onIncrease: () => cart.updateQuantity(item.foodId, item.quantity + 1, variationId: item.variationId),
                )),
                const SizedBox(height: 16),

                // Address
                _Section(
                  title: '📍 Endereço de Entrega',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedAddress != null) ...[
                        Text(
                          (_selectedAddress!['label'] as String?)?.isNotEmpty == true
                              ? _selectedAddress!['label'] as String
                              : 'Endereço selecionado',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (_selectedAddress!['address'] as String?) ?? '',
                          style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _changeAddress,
                          icon: const Icon(Icons.swap_horiz, size: 18, color: AppColors.primary),
                          label: const Text('Trocar endereço', style: TextStyle(color: AppColors.primary)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                        ),
                      ] else if (_addressesLoaded) ...[
                        const Text('Nenhum endereço salvo.', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _addAddress,
                          icon: const Icon(Icons.add_location_alt_outlined, size: 18, color: AppColors.primary),
                          label: const Text('Adicionar endereço', style: TextStyle(color: AppColors.primary)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _addressCtrl,
                          decoration: const InputDecoration(hintText: 'Ou digite seu endereço completo'),
                          maxLines: 2,
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Instructions
                _Section(
                  title: '📝 Instruções Especiais',
                  child: TextField(
                    controller: _instructionsCtrl,
                    decoration: const InputDecoration(hintText: 'Ex: Sem cebola, toque a campainha...'),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),

                // Coupon
                _Section(
                  title: '🏷️ Cupom de Desconto',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(hintText: 'CÓDIGO'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _applyCoupon(cart),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        child: const Text('Aplicar'),
                      ),
                    ],
                  ),
                ),
                if (_couponError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_couponError!, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                  ),
                if (_coupon != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('✅ ${_coupon!['title'] ?? _coupon!['code']} — ${_coupon!['discount']}% de desconto',
                        style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          ),

          // Bottom summary
          Container(
            decoration: const BoxDecoration(
              color: AppColors.cardWhite,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SummaryRow('Subtotal', '${cart.totalSats.toLocaleString()} sats'),
                _SummaryRow('Entrega', 'Calculado no pedido'),
                if (_coupon != null)
                  _SummaryRow('Desconto', '-${_coupon!['discount']}%', color: AppColors.success),
                const Divider(height: 20),
                _SummaryRow('Total estimado', '${cart.totalSats.toLocaleString()} sats', bold: true),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _placing ? null : () => _placeOrder(context, cart),
                    child: _placing
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Fazer Pedido ⚡'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyCoupon(CartModel cart) async {
    if (_couponCtrl.text.trim().isEmpty) return;
    final r = await GraphQLProvider.of(context).value.query(QueryOptions(
      document: gql(validateCouponQuery),
      variables: {
        'code': _couponCtrl.text.trim(),
        'restaurantId': cart.restaurantId ?? '',
        'orderAmount': cart.totalSats,
      },
      fetchPolicy: FetchPolicy.noCache,
    ));
    if (!mounted) return;
    if (r.hasException || r.data?['validateCoupon'] == null) {
      setState(() { _couponError = 'Cupom inválido'; _coupon = null; });
    } else {
      setState(() { _coupon = r.data!['validateCoupon'] as Map<String, dynamic>; _couponError = null; });
    }
  }

  Future<void> _addAddress() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesScreen()));
    if (mounted) await _loadAddresses();
  }

  Future<void> _changeAddress() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Escolha um endereço', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            ),
            ..._addresses.map((a) => ListTile(
                  leading: Icon(Icons.location_on, color: a['isDefault'] == true ? AppColors.primary : AppColors.textGrey),
                  title: Text((a['label'] as String?)?.isNotEmpty == true ? a['label'] as String : 'Endereço',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 14)),
                  subtitle: Text((a['address'] as String?) ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  onTap: () => Navigator.pop(ctx, a),
                )),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
              title: const Text('Adicionar novo endereço', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () => Navigator.pop(ctx, null),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (selected != null) {
      setState(() {
        _selectedAddress = selected;
        _addressCtrl.text = (selected['address'] as String?) ?? '';
      });
    }
  }

  Future<bool> _confirmAddress(String address) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar entrega', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Entregar neste endereço?', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text(address, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx, false); _changeAddress(); },
            child: const Text('Trocar endereço', style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _placeOrder(BuildContext context, CartModel cart) async {
    final address = _selectedAddress != null
        ? ((_selectedAddress!['address'] as String?) ?? '')
        : _addressCtrl.text.trim();

    if (address.trim().isEmpty) {
      if (_addressesLoaded && _addresses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Adicione um endereço de entrega para continuar'),
          backgroundColor: AppColors.primary,
        ));
        await _addAddress();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o endereço de entrega'), backgroundColor: AppColors.primary));
      }
      return;
    }

    // Confirma o endereço antes de ir para o pagamento.
    final confirmed = await _confirmAddress(address);
    if (!confirmed || !mounted) return;

    setState(() => _placing = true);

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.mutate(MutationOptions(
        document: gql(placeOrderMutation),
        variables: {
          'restaurantId': cart.restaurantId,
          'items': cart.items.map((i) => {
            'foodId': i.foodId,
            'quantity': i.quantity,
            if (i.variationId != null) 'variationId': i.variationId,
            if (i.addons.isNotEmpty)
              'addonOptionIds': i.addons.map((a) => a['_id']).whereType<String>().toList(),
          }).toList(),
          'deliveryAddress': {
            'address': address.trim(),
            if (_selectedAddress?['details'] != null) 'details': _selectedAddress!['details'],
          },
          if (_instructionsCtrl.text.isNotEmpty) 'specialInstructions': _instructionsCtrl.text.trim(),
          if (_coupon != null) 'couponCode': _couponCtrl.text.trim(),
        },
      ));

      if (result.hasException) throw result.exception!;
      if (!mounted) return;
      final data = result.data!['placeOrder'];
      cart.clear();

      if (mounted) {
        // If order is already paid (demo/mock mode without BTCPay configured)
        // skip the payment screen and go straight to order detail
        final alreadyPaid = data['order']?['paymentStatus'] == 'PAID';
        if (alreadyPaid) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: data['order']['_id'] as String),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PaymentScreen(invoiceData: data)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll(RegExp(r'GraphQLError\(.*?\):\s?'), '')),
          backgroundColor: AppColors.primary,
        ));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _CartItemRow({required this.item, required this.onRemove, required this.onDecrease, required this.onIncrease});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                if (item.variationTitle != null)
                  Text(item.variationTitle!, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                Text('${item.totalPrice.toLocaleString()} sats', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ],
            ),
          ),
          Row(
            children: [
              _QtyButton(onTap: onDecrease, icon: item.quantity == 1 ? Icons.delete_outline : Icons.remove, color: item.quantity == 1 ? AppColors.primary : AppColors.textDark),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              _QtyButton(onTap: onIncrease, icon: Icons.add),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  const _QtyButton({required this.onTap, required this.icon, this.color = AppColors.textDark});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _SummaryRow(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
            Text(value, style: TextStyle(fontSize: 13, color: color ?? AppColors.textDark, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      );
}

extension on int {
  String toLocaleString() => toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
