import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StatusBanner extends StatefulWidget {
  const StatusBanner({super.key});

  @override
  State<StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<StatusBanner> {
  static const _url = 'https://api.bitfood.app/health';
  static const _interval = Duration(seconds: 30);

  Map<String, bool> _services = {'api': true, 'database': true, 'btcpay': true};
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(_interval, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final res = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 6));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final s = data['services'] as Map<String, dynamic>? ?? {};
      if (mounted) setState(() {
        _services = {
          'api':      s['api'] == true,
          'database': s['database'] == true,
          'btcpay':   s['btcpay'] == true,
        };
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _services = {'api': false, 'database': false, 'btcpay': false};
        _loading = false;
      });
    }
  }

  bool get _allOk => _services.values.every((v) => v);

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Status dos Serviços'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('API', _services['api'] ?? false),
            _row('Banco de dados', _services['database'] ?? false),
            _row('BTCPay (Lightning)', _services['btcpay'] ?? false),
          ],
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _check(); },
              child: const Text('Atualizar')),
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Fechar')),
        ],
      ),
    );
  }

  Widget _row(String label, bool ok) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(ok ? Icons.check_circle : Icons.cancel,
          color: ok ? Colors.green : Colors.red, size: 18),
      const SizedBox(width: 10),
      Text(label),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading || _allOk) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showDialog(context),
      child: Container(
        color: const Color(0xFFD32F2F),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 14),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Serviço parcialmente offline — toque para detalhes',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const Icon(Icons.info_outline, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}
