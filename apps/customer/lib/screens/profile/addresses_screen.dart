import 'package:country_state_city/country_state_city.dart' as csc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../services/location_service.dart';
import '../../services/queries.dart';
import '../../theme/app_theme.dart';
import 'dart:convert';
import 'dart:io';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(document: gql(meQuery), fetchPolicy: FetchPolicy.cacheAndNetwork),
      builder: (result, {fetchMore, refetch}) {
        final addresses = (result.data?['me']?['addresses'] as List?) ?? [];
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Meus Endereços'),
            backgroundColor: AppColors.cardWhite,
            foregroundColor: AppColors.textDark,
            elevation: 0,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              final client = GraphQLProvider.of(context).value;
              _showAddSheet(context, client, refetch);
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Novo Endereço',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          body: result.isLoading && result.data == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : addresses.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on_outlined, size: 64, color: AppColors.textLight),
                          SizedBox(height: 12),
                          Text('Nenhum endereço salvo',
                              style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
                          SizedBox(height: 4),
                          Text('Toque em "Novo Endereço" para adicionar',
                              style: TextStyle(fontSize: 13, color: AppColors.textLight)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: addresses.length,
                      itemBuilder: (_, i) => _AddressCard(address: addresses[i]),
                    ),
        );
      },
    );
  }

  void _showAddSheet(BuildContext context, GraphQLClient client, Refetch? refetch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) =>
          _AddAddressSheet(client: client, onSaved: () => refetch?.call()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  const _AddressCard({required this.address});

  @override
  Widget build(BuildContext context) {
    final isDefault = address['isDefault'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDefault ? AppColors.primary : AppColors.divider,
            width: isDefault ? 2 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on,
              color: isDefault ? AppColors.primary : AppColors.textGrey, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address['label'] != null)
                  Row(children: [
                    Text(address['label'],
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            fontSize: 14)),
                    if (isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('Padrão',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                if (address['street'] != null)
                  Text(
                    '${address['street']}'
                    '${address['number'] != null ? ", ${address['number']}" : ""}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                  ),
                if ((address['complement'] ?? '').toString().isNotEmpty)
                  Text(address['complement'],
                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                if (address['neighborhood'] != null)
                  Text(address['neighborhood'],
                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                Text(
                  [
                    if (address['city'] != null) address['city'],
                    if (address['state'] != null) address['state'],
                    if (address['country'] != null) address['country'],
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _AddAddressSheet extends StatefulWidget {
  final GraphQLClient client;
  final VoidCallback onSaved;
  const _AddAddressSheet({required this.client, required this.onSaved});

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _labelCtrl        = TextEditingController();
  final _streetCtrl       = TextEditingController();
  final _numberCtrl       = TextEditingController();
  final _complementCtrl   = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _postalCodeCtrl   = TextEditingController();
  final _detailsCtrl      = TextEditingController();

  // ── country / state / city ────────────────────────────────────────────────
  List<csc.Country> _countries = [];
  List<csc.State>   _states    = [];
  List<csc.City>    _cities    = [];

  csc.Country? _selectedCountry;
  csc.State?   _selectedState;
  csc.City?    _selectedCity;

  bool _loadingCountries = true;
  bool _loadingStates    = false;
  bool _loadingCities    = false;

  // ── other ─────────────────────────────────────────────────────────────────
  bool   _isDefault = false;
  bool   _loading   = false;
  bool   _locating  = false;
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
    for (final c in [
      _labelCtrl, _streetCtrl, _numberCtrl, _complementCtrl,
      _neighborhoodCtrl, _postalCodeCtrl, _detailsCtrl
    ]) c.dispose();
    super.dispose();
  }

  // ── data loading ──────────────────────────────────────────────────────────

  Future<void> _loadCountries() async {
    final list = await csc.getAllCountries();
    list.sort((a, b) => a.name.compareTo(b.name));

    // Pre-select detected country
    final detectedIso2 = LocationService.detectedIso2;
    csc.Country? preSelected;
    if (detectedIso2 != null) {
      try {
        preSelected = list.firstWhere(
          (c) => c.isoCode.toUpperCase() == detectedIso2.toUpperCase(),
        );
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _countries = list;
      _loadingCountries = false;
      if (preSelected != null) {
        _selectedCountry = preSelected;
      }
    });

    if (preSelected != null) await _loadStates(preSelected);
  }

  Future<void> _loadStates(csc.Country country) async {
    setState(() { _loadingStates = true; _states = []; _cities = [];
                  _selectedState = null; _selectedCity = null; });
    final list = await csc.getStatesOfCountry(country.isoCode);
    list.sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;
    setState(() { _states = list; _loadingStates = false; });
  }

  Future<void> _loadCities(csc.State state) async {
    setState(() { _loadingCities = true; _cities = []; _selectedCity = null; });
    final list = await csc.getStateCities(
        _selectedCountry!.isoCode, state.isoCode);
    list.sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;
    setState(() { _cities = list; _loadingCities = false; });
  }

  // ── geolocation fill ──────────────────────────────────────────────────────

  Future<void> _geolocate() async {
    setState(() { _locating = true; _error = null; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() {
          _error = 'Permissão de localização negada.';
          _locating = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _lat = pos.latitude;
      _lng = pos.longitude;

      final httpClient = HttpClient();
      httpClient.userAgent = 'BitFood/1.0 (arthurleobertotto@gmail.com)';
      final req = await httpClient.getUrl(Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${pos.latitude}&lon=${pos.longitude}&format=json',
      ));
      req.headers.set('Accept-Language', 'en');
      final resp = await req.close();
      final body = await resp.transform(const Utf8Decoder()).join();
      httpClient.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final addr = (data['address'] as Map<String, dynamic>?) ?? {};

      _streetCtrl.text       = addr['road'] ?? addr['pedestrian'] ?? '';
      _numberCtrl.text       = addr['house_number'] ?? '';
      _neighborhoodCtrl.text = addr['suburb'] ?? addr['neighbourhood'] ?? '';
      _postalCodeCtrl.text   = addr['postcode'] ?? '';

      // Match country
      final iso2 = (addr['country_code'] as String?)?.toUpperCase();
      if (iso2 != null) {
        try {
          final country = _countries.firstWhere(
              (c) => c.isoCode.toUpperCase() == iso2);
          setState(() { _selectedCountry = country; });
          await _loadStates(country);

          // Match state
          final stateName = addr['state'] as String?;
          if (stateName != null && _states.isNotEmpty) {
            try {
              final st = _states.firstWhere((s) =>
                  s.name.toLowerCase().contains(stateName.toLowerCase()) ||
                  stateName.toLowerCase().contains(s.name.toLowerCase()));
              setState(() => _selectedState = st);
              await _loadCities(st);

              // Match city
              final cityName =
                  addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['village'];
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
    } catch (e) {
      setState(() { _error = 'Erro ao obter localização.'; _locating = false; });
    }
  }

  // ── submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedCountry == null) {
      setState(() => _error = 'Selecione o país primeiro.');
      return;
    }

    // Block if device country differs from selected country
    final detectedIso2 = LocationService.detectedIso2;
    if (detectedIso2 != null &&
        _selectedCountry!.isoCode.toUpperCase() != detectedIso2.toUpperCase()) {
      setState(() => _error =
          'Só é possível cadastrar endereços no país detectado pelo seu dispositivo '
          '(${LocationService.detectedCountryName ?? detectedIso2}).');
      return;
    }

    final street = _streetCtrl.text.trim();
    if (street.isEmpty) { setState(() => _error = 'Rua é obrigatória.'); return; }

    setState(() { _loading = true; _error = null; });

    final city    = _selectedCity?.name ?? '';
    final state   = _selectedState?.name ?? '';
    final country = _selectedCountry!.name;

    final fullAddress = [
      street,
      if (_numberCtrl.text.trim().isNotEmpty) _numberCtrl.text.trim(),
      if (_neighborhoodCtrl.text.trim().isNotEmpty) _neighborhoodCtrl.text.trim(),
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      country,
    ].join(', ');

    try {
      final result = await widget.client.mutate(MutationOptions(
        document: gql(addAddressMutation),
        variables: {
          'address': fullAddress,
          if (_labelCtrl.text.trim().isNotEmpty) 'label': _labelCtrl.text.trim(),
          'street': street,
          if (_numberCtrl.text.trim().isNotEmpty) 'number': _numberCtrl.text.trim(),
          if (_complementCtrl.text.trim().isNotEmpty)
            'complement': _complementCtrl.text.trim(),
          if (_neighborhoodCtrl.text.trim().isNotEmpty)
            'neighborhood': _neighborhoodCtrl.text.trim(),
          if (_postalCodeCtrl.text.trim().isNotEmpty)
            'postalCode': _postalCodeCtrl.text.trim(),
          if (city.isNotEmpty) 'city': city,
          if (state.isNotEmpty) 'state': state,
          'country': country,
          if (_detailsCtrl.text.trim().isNotEmpty) 'details': _detailsCtrl.text.trim(),
          if (_lat != null) 'lat': _lat,
          if (_lng != null) 'lng': _lng,
          'isDefault': _isDefault,
        },
      ));
      if (result.hasException) throw result.exception!;
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll(RegExp(r'OperationException.*?:\s?'), '');
        _loading = false;
      });
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _textField(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboard, bool required = false,
       List<TextInputFormatter>? formatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label${required ? ' *' : ''}',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          inputFormatters: formatters,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _dropdownLabel(String label, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('$label${required ? ' *' : ''}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey)),
      );

  InputDecoration _dropDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final detectedIso2 = LocationService.detectedIso2;
    final detectedName = LocationService.detectedCountryName;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              const Text('Novo Endereço',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),

            // Detected country chip
            if (detectedName != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('Dispositivo detectado em: $detectedName',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textGrey)),
              ]),
            ],
            const SizedBox(height: 10),

            // GPS button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _locating || _loadingCountries ? null : _geolocate,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.my_location, size: 18,
                        color: AppColors.primary),
                label: Text(
                    _locating ? 'Localizando...' : 'Usar minha localização atual',
                    style: const TextStyle(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 14),

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_error!,
                    style:
                        const TextStyle(color: AppColors.primary, fontSize: 13)),
              ),
              const SizedBox(height: 10),
            ],

            // ── País ──────────────────────────────────────────────────────
            _dropdownLabel('País', required: true),
            _loadingCountries
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<csc.Country>(
                    value: _selectedCountry,
                    decoration: _dropDecoration('Selecione o país'),
                    isExpanded: true,
                    menuMaxHeight: 300,
                    items: _countries
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text('${c.flag ?? ""} ${c.name}',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (detectedIso2 == null)
                        ? (c) async {
                            if (c == null) return;
                            setState(() => _selectedCountry = c);
                            await _loadStates(c);
                          }
                        : (c) async {
                            if (c == null) return;
                            // Block countries other than detected
                            if (c.isoCode.toUpperCase() !=
                                detectedIso2.toUpperCase()) {
                              setState(() => _error =
                                  'Seu dispositivo está em $detectedName. '
                                  'Só é possível cadastrar endereços nesse país.');
                              return;
                            }
                            setState(() {
                              _error = null;
                              _selectedCountry = c;
                            });
                            await _loadStates(c);
                          },
                  ),
            const SizedBox(height: 10),

            // ── Estado ────────────────────────────────────────────────────
            if (_selectedCountry != null) ...[
              _dropdownLabel('Estado / Região'),
              _loadingStates
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<csc.State>(
                      value: _selectedState,
                      decoration: _dropDecoration(_states.isEmpty
                          ? 'Sem estados disponíveis'
                          : 'Selecione o estado'),
                      isExpanded: true,
                      menuMaxHeight: 300,
                      items: _states
                          .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.name,
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: _states.isEmpty
                          ? null
                          : (s) async {
                              if (s == null) return;
                              setState(() => _selectedState = s);
                              await _loadCities(s);
                            },
                    ),
              const SizedBox(height: 10),
            ],

            // ── Cidade ────────────────────────────────────────────────────
            if (_selectedState != null) ...[
              _dropdownLabel('Cidade'),
              _loadingCities
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<csc.City>(
                      value: _selectedCity,
                      decoration: _dropDecoration(_cities.isEmpty
                          ? 'Sem cidades disponíveis'
                          : 'Selecione a cidade'),
                      isExpanded: true,
                      menuMaxHeight: 300,
                      items: _cities
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.name,
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: _cities.isEmpty
                          ? null
                          : (c) => setState(() => _selectedCity = c),
                    ),
              const SizedBox(height: 10),
            ],

            const Divider(height: 20),

            // ── Address fields ────────────────────────────────────────────
            _textField('Rótulo', _labelCtrl, hint: 'Casa, Trabalho, etc.'),
            _textField('Rua / Avenida', _streetCtrl,
                hint: 'Rua das Flores', required: true),
            Row(children: [
              Expanded(
                  flex: 2,
                  child: _textField('Número', _numberCtrl,
                      hint: '123', keyboard: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(
                  flex: 3,
                  child: _textField('Complemento', _complementCtrl,
                      hint: 'Apto 42')),
            ]),
            _textField('Bairro', _neighborhoodCtrl, hint: 'Centro'),
            _textField('CEP / Código Postal', _postalCodeCtrl,
                hint: '01310-100', keyboard: TextInputType.number),
            _textField('Referência', _detailsCtrl,
                hint: 'Portão azul, esquina...'),

            Row(children: [
              Checkbox(
                value: _isDefault,
                onChanged: (v) =>
                    setState(() => _isDefault = v ?? false),
                activeColor: AppColors.primary,
              ),
              const Text('Definir como endereço padrão',
                  style: TextStyle(fontSize: 13, color: AppColors.textDark)),
            ]),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Salvar Endereço',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
