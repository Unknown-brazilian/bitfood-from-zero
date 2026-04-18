import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/queries.dart';
import '../order/order_detail_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> invoiceData;
  const PaymentScreen({super.key, required this.invoiceData});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Timer? _timer;
  bool _paid = false;
  bool _checking = false;

  late final String? _lightning;
  late final String? _checkoutUrl;
  late final String _orderId;
  late final int _amountSats;
  late final String? _qrCode;
  late final bool _hasBolt11;

  @override
  void initState() {
    super.initState();
    final d = widget.invoiceData;
    _lightning = d['lightningInvoice'] as String?;
    _checkoutUrl = d['checkoutUrl'] as String?;
    _orderId = d['order']['_id'] as String;
    _amountSats = d['amountSats'] as int;
    _qrCode = d['qrCode'] as String?;
    _hasBolt11 = _lightning != null && _lightning!.toLowerCase().startsWith('ln');
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkPayment());
  }

  Future<void> _checkPayment() async {
    if (_paid) return;
    setState(() => _checking = true);
    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(QueryOptions(
        document: gql(checkPaymentQuery),
        variables: {'orderId': _orderId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (result.data?['checkPayment']?['paymentStatus'] == 'PAID') {
        _timer?.cancel();
        setState(() => _paid = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: _orderId)),
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  void _copyInvoice() {
    Clipboard.setData(ClipboardData(text: _lightning ?? _checkoutUrl ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copiado!'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_paid) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text('Pagamento confirmado!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text('Seu pedido foi recebido', style: TextStyle(color: AppColors.textGrey)),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      );
    }

    // BTCPay WebView when no BOLT11
    if (!_hasBolt11 && _checkoutUrl != null) {
      return _BTCPayWebView(
        url: _checkoutUrl!,
        amountSats: _amountSats,
        onCheckPayment: _checkPayment,
        checking: _checking,
      );
    }

    // BOLT11 QR screen
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pagar com Lightning ⚡')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Amount
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      const Text('Total a pagar', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.electric_bolt, color: AppColors.orange, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${_amountSats.toLocaleString()} sats',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // QR Code
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      _hasBolt11 && _lightning != null
                          ? QrImageView(
                              data: _lightning!,
                              version: QrVersions.auto,
                              size: 220,
                              eyeStyle: const QrEyeStyle(color: AppColors.textDark),
                              dataModuleStyle: const QrDataModuleStyle(color: AppColors.textDark),
                            )
                          : Container(
                              width: 220, height: 220,
                              color: AppColors.shimmer,
                              child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                            ),
                      const SizedBox(height: 12),
                      const Text('Escaneie com sua carteira Lightning', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Invoice text
                GestureDetector(
                  onTap: _copyInvoice,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        Text(
                          (_lightning ?? _checkoutUrl ?? ''),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.textGrey),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        const Text('Toque para copiar', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(child: Text('⏱ Invoice expira em 10 minutos', style: TextStyle(fontSize: 12, color: AppColors.textGrey))),
              ],
            ),
          ),

          // Bottom buttons
          Container(
            decoration: const BoxDecoration(
              color: AppColors.cardWhite,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : _checkPayment,
                    icon: _checking
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: Text(_checking ? 'Verificando...' : 'Verificar Pagamento'),
                  ),
                ),
                if (_checkoutUrl != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => _BTCPayWebView(
                          url: _checkoutUrl!,
                          amountSats: _amountSats,
                          onCheckPayment: _checkPayment,
                          checking: _checking,
                        )),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Abrir checkout BTCPay'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BTCPayWebView extends StatefulWidget {
  final String url;
  final int amountSats;
  final Future<void> Function() onCheckPayment;
  final bool checking;

  const _BTCPayWebView({required this.url, required this.amountSats, required this.onCheckPayment, required this.checking});

  @override
  State<_BTCPayWebView> createState() => _BTCPayWebViewState();
}

class _BTCPayWebViewState extends State<_BTCPayWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pagar com Bitcoin ⚡', style: TextStyle(fontSize: 15)),
            Text('${widget.amountSats.toLocaleString()} sats', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: _controller)),
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.cardWhite,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.checking ? null : widget.onCheckPayment,
                child: Text(widget.checking ? 'Verificando...' : 'Confirmar Pagamento'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on int {
  String toLocaleString() => toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
