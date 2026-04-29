import 'dart:convert';
import 'dart:io';
import 'package:country_state_city/country_state_city.dart' as csc;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme.dart';
import '../services/location_service.dart';

class AddressResult {
  final String formatted;
  final double lat;
  final double lng;
  const AddressResult({required this.formatted, required this.lat, required this.lng});
}

Future<AddressResult?> showAddressPickerSheet(BuildContext context, {String? title}) {
  return showModalBottomSheet<AddressResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _AddressPickerSheet(title: title ?? 'Endereço'),
  );
}

class _AddressPickerSheet extends StatefulWidget {
  final String title;
  const _AddressPickerSheet({required this.title});

  @override
  State<_AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<_AddressPickerSheet> {
  final _streetCtrl       = TextEditingController();
  final _numberCtrl       = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();

  List<csc.Country> _countries = [];
  List<csc.State>   _states    = [];
  List<csc.City>    _cities    = [];

  csc.Country? _selectedCountry;
  csc.State?   _selectedState;
  csc.City?    _selectedCity;

  bool _loadingCountries = true;
  bool _loadingStates    = false;
  bool _loadingCities    = false;
  bool _locating         = false;
  String? _error;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _streetCtrl.dispose();
    _numberCtrl.dispose();
    _neighborhoodCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    final list = await csc.getAllCountries();
    list.sort((a, b) => a.name.compareTo(b.name));
    final iso2 = LocationService.detectedIso2;
    csc.Country? pre;
    if (iso2 != null) {
      try { pre = list.firstWhere((c) => c.isoCode.toUpperCase() == iso2.toUpperCase()); }
      catch (_) {}
    }
    if (!mounted) return;
    setState(() { _countries = list; _loadingCountries = false; if (pre != null) _selectedCountry = pre; });
    if (pre != null) await _loadStates(pre);
  }

  Future<void> _loadStates(csc.Country country) async {
    setState(() { _loadingStates = true; _states = []; _cities = []; _selectedState = null; _selectedCity = null; });
    final list = await csc.getStatesOfCountry(country.isoCode);
    list.sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;
    setState(() { _states = list; _loadingStates = false; });
  }

  Future<void> _loadCities(csc.State state) async {
    setState(() { _loadingCities = true; _cities = []; _selectedCity = null; });
    final list = await csc.getStateCities(_selectedCountry!.isoCode, state.isoCode);
    list.sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;
    setState(() { _cities = list; _loadingCities = false; });
  }

  Future<void> _geolocate() async {
    setState(() { _locating = true; _error = null; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        setState(() { _error = 'Permissão de localização negada.'; _locating = false; }); return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _lat = pos.latitude; _lng = pos.longitude;

      final http = HttpClient();
      http.userAgent = 'BitFood/1.0 (arthurleobertotto@gmail.com)';
      final req = await http.getUrl(Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json'));
      req.headers.set('Accept-Language', 'en');
      final resp = await req.close();
      final body = await resp.transform(const Utf8Decoder()).join();
      http.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final addr = (data['address'] as Map<String, dynamic>?) ?? {};
      _streetCtrl.text       = addr['road'] ?? addr['pedestrian'] ?? '';
      _numberCtrl.text       = addr['house_number'] ?? '';
      _neighborhoodCtrl.text = addr['suburb'] ?? addr['neighbourhood'] ?? '';

      final iso2 = (addr['country_code'] as String?)?.toUpperCase();
      if (iso2 != null) {
        try {
          final country = _countries.firstWhere((c) => c.isoCode.toUpperCase() == iso2);
          setState(() => _selectedCountry = country);
          await _loadStates(country);
          final stateName = addr['state'] as String?;
          if (stateName != null && _states.isNotEmpty) {
            try {
              final st = _states.firstWhere((s) =>
                  s.name.toLowerCase().contains(stateName.toLowerCase()) ||
                  stateName.toLowerCase().contains(s.name.toLowerCase()));
              setState(() => _selectedState = st);
              await _loadCities(st);
              final cityName = addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['village'];
              if (cityName != null && _cities.isNotEmpty) {
                try {
                  final city = _cities.firstWhere((c) =>
                      c.name.toLowerCase().contains(cityName.toLowerCase()) ||
                      cityName.toLowerCase().contains(c.name.toLowerCase()));
                  setState(() => _selectedCity = city);
                } catch (_) {}
              }
            } catch (_) {}
          }
        } catch (_) {}
      }
      setState(() => _locating = false);
    } catch (_) {
      setState(() { _error = 'Erro ao obter localização.'; _locating = false; });
    }
  }

  void _submit() {
    if (_selectedCountry == null) { setState(() => _error = 'Selecione o país.'); return; }
    if (_lat == null || _lng == null) { setState(() => _error = 'Use o GPS para obter as coordenadas.'); return; }
    final street = _streetCtrl.text.trim();
    if (street.isEmpty) { setState(() => _error = 'Rua é obrigatória.'); return; }
    final parts = [
      street,
      if (_numberCtrl.text.trim().isNotEmpty) _numberCtrl.text.trim(),
      if (_neighborhoodCtrl.text.trim().isNotEmpty) _neighborhoodCtrl.text.trim(),
      if (_selectedCity != null) _selectedCity!.name,
      if (_selectedState != null) _selectedState!.name,
      _selectedCountry!.name,
    ];
    Navigator.pop(context, AddressResult(formatted: parts.join(', '), lat: _lat!, lng: _lng!));
  }

  Widget _textField(String label, TextEditingController ctrl, {String? hint, TextInputType? keyboard}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl, keyboardType: keyboard,
        decoration: InputDecoration(
          hintText: hint, filled: true, fillColor: const Color(0xFFF5F5F5),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true,
        ),
      ),
      const SizedBox(height: 10),
    ]);
  }

  InputDecoration _drop(String hint) => InputDecoration(
    hintText: hint, filled: true, fillColor: const Color(0xFFF5F5F5),
    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 10),

          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _locating || _loadingCountries ? null : _geolocate,
              icon: _locating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.my_location, size: 18, color: AppColors.primary),
              label: Text(_locating ? 'Localizando...' : 'Usar minha localização atual',
                  style: const TextStyle(color: AppColors.primary)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 8),
          const Text('* As coordenadas GPS são necessárias para o filtro direcional.',
              style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
          const SizedBox(height: 10),

          if (_error != null) ...[
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: AppColors.primary, fontSize: 13))),
            const SizedBox(height: 10),
          ],

          Text('País *', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
          const SizedBox(height: 4),
          _loadingCountries
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<csc.Country>(
                  value: _selectedCountry, decoration: _drop('Selecione o país'),
                  isExpanded: true, menuMaxHeight: 300,
                  items: _countries.map((c) => DropdownMenuItem(
                    value: c, child: Text('${c.flag ?? ""} ${c.name}', overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (c) async { if (c == null) return; setState(() => _selectedCountry = c); await _loadStates(c); },
                ),
          const SizedBox(height: 10),

          if (_selectedCountry != null) ...[
            Text('Estado', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
            const SizedBox(height: 4),
            _loadingStates ? const LinearProgressIndicator()
                : DropdownButtonFormField<csc.State>(
                    value: _selectedState, decoration: _drop(_states.isEmpty ? 'Sem estados' : 'Selecione o estado'),
                    isExpanded: true, menuMaxHeight: 300,
                    items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: _states.isEmpty ? null : (s) async { if (s == null) return; setState(() => _selectedState = s); await _loadCities(s); },
                  ),
            const SizedBox(height: 10),
          ],

          if (_selectedState != null) ...[
            Text('Cidade', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
            const SizedBox(height: 4),
            _loadingCities ? const LinearProgressIndicator()
                : DropdownButtonFormField<csc.City>(
                    value: _selectedCity, decoration: _drop(_cities.isEmpty ? 'Sem cidades' : 'Selecione a cidade'),
                    isExpanded: true, menuMaxHeight: 300,
                    items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: _cities.isEmpty ? null : (c) => setState(() => _selectedCity = c),
                  ),
            const SizedBox(height: 10),
          ],

          const Divider(height: 20),
          _textField('Rua / Avenida *', _streetCtrl, hint: 'Rua das Flores'),
          Row(children: [
            Expanded(flex: 2, child: _textField('Número', _numberCtrl, hint: '123', keyboard: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: _textField('Bairro', _neighborhoodCtrl, hint: 'Centro')),
          ]),

          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirmar Endereço',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
