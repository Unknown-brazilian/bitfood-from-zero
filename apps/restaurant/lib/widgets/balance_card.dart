import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class BalanceCard extends StatefulWidget {
  final int sats;
  const BalanceCard({super.key, required this.sats});

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  static final _currencies = [
    {'code': 'brl', 'symbol': 'R\$', 'name': 'Real'},
    {'code': 'usd', 'symbol': 'US\$', 'name': 'Dólar'},
    {'code': 'eur', 'symbol': '€', 'name': 'Euro'},
    {'code': 'gbp', 'symbol': '£', 'name': 'Libra'},
    {'code': 'jpy', 'symbol': '¥', 'name': 'Iene'},
  ];

  Map<String, double> _rates = {};
  String _currency = 'brl';
  bool _loading = true;
  static Map<String, double>? _cachedRates;
  static DateTime? _cacheTime;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _fetchRates();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _currency = prefs.getString('fiat_currency') ?? 'brl');
  }

  Future<void> _saveCurrency(String c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fiat_currency', c);
    if (mounted) setState(() => _currency = c);
  }

  Future<void> _fetchRates() async {
    if (_cachedRates != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < 5) {
      if (mounted) setState(() { _rates = _cachedRates!; _loading = false; });
      return;
    }
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=brl,usd,eur,gbp,jpy',
      ));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map;
      final btc = Map<String, double>.from(
        (data['bitcoin'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      );
      _cachedRates = btc;
      _cacheTime = DateTime.now();
      if (mounted) setState(() { _rates = btc; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fiatStr() {
    if (_rates.isEmpty) return '—';
    final rate = _rates[_currency] ?? 0;
    final fiat = (widget.sats / 100000000) * rate;
    final sym = _currencies.firstWhere((c) => c['code'] == _currency)['symbol']!;
    if (fiat < 0.01) return '$sym 0,00';
    return '$sym ${fiat.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.electric_bolt, color: AppColors.orange, size: 16),
              const SizedBox(width: 6),
              const Text('Saldo', style: TextStyle(color: Colors.white60, fontSize: 12)),
              const Spacer(),
              // Currency picker
              DropdownButton<String>(
                value: _currency,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                underline: const SizedBox(),
                icon: const Icon(Icons.expand_more, color: Colors.white54, size: 16),
                items: _currencies.map((c) => DropdownMenuItem(
                  value: c['code'],
                  child: Text('${c['symbol']} ${c['name']}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                )).toList(),
                onChanged: (v) => _saveCurrency(v!),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatSats(widget.sats)} sats',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38))
              : Text(_fiatStr(), style: const TextStyle(color: Colors.white60, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatSats(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
}
