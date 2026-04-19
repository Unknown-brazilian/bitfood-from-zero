import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class SatsChip extends StatefulWidget {
  final int sats;
  const SatsChip({super.key, this.sats = 0});

  @override
  State<SatsChip> createState() => _SatsChipState();
}

class _SatsChipState extends State<SatsChip> {
  static const _currencies = [
    {'code': 'brl', 'symbol': 'R\$'},
    {'code': 'usd', 'symbol': 'US\$'},
    {'code': 'eur', 'symbol': '€'},
    {'code': 'gbp', 'symbol': '£'},
    {'code': 'jpy', 'symbol': '¥'},
    {'code': 'pyg', 'symbol': '₲'},
  ];

  static Map<String, double>? _cachedRates;
  static DateTime? _cacheTime;

  Map<String, double> _rates = {};
  String _currency = 'usd';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _fetchRates();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _fetchRates());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _currency = prefs.getString('fiat_currency') ?? 'usd');
  }

  Future<void> _saveCurrency(String c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fiat_currency', c);
    if (mounted) setState(() => _currency = c);
  }

  Future<void> _fetchRates() async {
    if (_cachedRates != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < 5) {
      if (mounted) setState(() => _rates = _cachedRates!);
      return;
    }
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=brl,usd,eur,gbp,jpy,pyg',
      ));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map;
      final btc = Map<String, double>.from(
        (data['bitcoin'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      );
      _cachedRates = btc;
      _cacheTime = DateTime.now();
      if (mounted) setState(() => _rates = btc);
    } catch (_) {}
  }

  String _fiatStr() {
    if (_rates.isEmpty) return '…';
    final rate = _rates[_currency] ?? 0;
    final fiat = (widget.sats / 100000000) * rate;
    final sym = _currencies.firstWhere((c) => c['code'] == _currency, orElse: () => {'symbol': '\$'})['symbol']!;
    if (_currency == 'jpy' || _currency == 'pyg') {
      return '≈ $sym ${fiat.toStringAsFixed(0)}';
    }
    return '≈ $sym ${fiat.toStringAsFixed(2)}';
  }

  String _formatSats(int v) =>
      v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

  void _showCurrencyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Moeda de referência', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            ..._currencies.map((c) => ListTile(
              dense: true,
              title: Text('${c['symbol']} ${c['code']!.toUpperCase()}',
                style: TextStyle(color: _currency == c['code'] ? AppColors.primary : Colors.white, fontWeight: FontWeight.w600)),
              trailing: _currency == c['code'] ? const Icon(Icons.check, color: AppColors.primary, size: 18) : null,
              onTap: () {
                _saveCurrency(c['code']!);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCurrencyPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.electric_bolt, color: Color(0xFFF7931A), size: 13),
            const SizedBox(width: 4),
            Text(
              '${_formatSats(widget.sats)} sats',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Text(
              _fiatStr(),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
