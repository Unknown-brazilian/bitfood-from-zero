import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/queries.dart';

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
            label: const Text('Novo Endereço', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
                          Text('Nenhum endereço salvo', style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
                          SizedBox(height: 4),
                          Text('Toque em "Novo Endereço" para adicionar', style: TextStyle(fontSize: 13, color: AppColors.textLight)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddAddressSheet(client: client, onSaved: () { refetch?.call(); }),
    );
  }
}

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
        border: Border.all(color: isDefault ? AppColors.primary : AppColors.divider, width: isDefault ? 2 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on, color: isDefault ? AppColors.primary : AppColors.textGrey, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address['label'] != null)
                  Row(children: [
                    Text(address['label'], style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14)),
                    if (isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Padrão', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                if (address['street'] != null)
                  Text(
                    '${address['street']}${address['number'] != null ? ", ${address['number']}" : ""}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                  ),
                if ((address['complement'] ?? '').toString().isNotEmpty)
                  Text(address['complement'], style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                if (address['neighborhood'] != null)
                  Text(address['neighborhood'], style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                Text(
                  [
                    if (address['city'] != null) address['city'],
                    if (address['state'] != null) address['state'],
                    if (address['postalCode'] != null) 'CEP ${address['postalCode']}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
                if ((address['details'] ?? '').toString().isNotEmpty)
                  Text('Ref: ${address['details']}', style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAddressSheet extends StatefulWidget {
  final GraphQLClient client;
  final VoidCallback onSaved;
  const _AddAddressSheet({required this.client, required this.onSaved});

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _labelCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _complementCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'Brasil');
  final _detailsCtrl = TextEditingController();
  bool _isDefault = false;
  bool _loading = false;
  bool _locating = false;
  String? _error;
  double? _lat;
  double? _lng;

  @override
  void dispose() {
    for (final c in [_labelCtrl, _streetCtrl, _numberCtrl, _complementCtrl,
        _neighborhoodCtrl, _postalCodeCtrl, _cityCtrl, _stateCtrl, _countryCtrl, _detailsCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _geolocate() async {
    setState(() { _locating = true; _error = null; });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() { _error = 'Permissão negada. Habilite nas configurações do dispositivo.'; _locating = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _lat = pos.latitude;
      _lng = pos.longitude;

      final httpClient = HttpClient();
      httpClient.userAgent = 'BitFood/1.0 (arthurleobertotto@gmail.com)';
      final req = await httpClient.getUrl(Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json',
      ));
      req.headers.set('Accept-Language', 'pt-BR,pt;q=0.9');
      final resp = await req.close();
      final body = await resp.transform(const Utf8Decoder()).join();
      httpClient.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final addr = (data['address'] as Map<String, dynamic>?) ?? {};
      setState(() {
        _streetCtrl.text = addr['road'] ?? addr['pedestrian'] ?? addr['street'] ?? '';
        _numberCtrl.text = addr['house_number'] ?? '';
        _neighborhoodCtrl.text = addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? '';
        _postalCodeCtrl.text = addr['postcode'] ?? '';
        _cityCtrl.text = addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['village'] ?? '';
        _stateCtrl.text = addr['state'] ?? '';
        _countryCtrl.text = addr['country'] ?? 'Brasil';
        _locating = false;
      });
    } catch (e) {
      setState(() { _error = 'Erro ao obter localização: $e'; _locating = false; });
    }
  }

  Future<void> _submit() async {
    final street = _streetCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    if (street.isEmpty) { setState(() => _error = 'Rua é obrigatória'); return; }
    if (city.isEmpty) { setState(() => _error = 'Cidade é obrigatória'); return; }
    setState(() { _loading = true; _error = null; });

    final fullAddress = [
      street,
      if (_numberCtrl.text.trim().isNotEmpty) _numberCtrl.text.trim(),
      if (_neighborhoodCtrl.text.trim().isNotEmpty) _neighborhoodCtrl.text.trim(),
      city,
      if (_stateCtrl.text.trim().isNotEmpty) _stateCtrl.text.trim(),
    ].join(', ');

    try {
      final result = await widget.client.mutate(MutationOptions(
        document: gql(addAddressMutation),
        variables: {
          'address': fullAddress,
          if (_labelCtrl.text.trim().isNotEmpty) 'label': _labelCtrl.text.trim(),
          'street': street,
          if (_numberCtrl.text.trim().isNotEmpty) 'number': _numberCtrl.text.trim(),
          if (_complementCtrl.text.trim().isNotEmpty) 'complement': _complementCtrl.text.trim(),
          if (_neighborhoodCtrl.text.trim().isNotEmpty) 'neighborhood': _neighborhoodCtrl.text.trim(),
          if (_postalCodeCtrl.text.trim().isNotEmpty) 'postalCode': _postalCodeCtrl.text.trim(),
          'city': city,
          if (_stateCtrl.text.trim().isNotEmpty) 'state': _stateCtrl.text.trim(),
          if (_countryCtrl.text.trim().isNotEmpty) 'country': _countryCtrl.text.trim(),
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

  Widget _field(String label, TextEditingController ctrl, {String? hint, TextInputType? keyboard, bool required = false, List<TextInputFormatter>? formatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label${required ? ' *' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          inputFormatters: formatters,
          decoration: InputDecoration(
            hintText: hint,
            filled: true, fillColor: const Color(0xFFF5F5F5),
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Novo Endereço', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _geolocate,
                icon: _locating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.my_location, size: 18, color: AppColors.primary),
                label: Text(_locating ? 'Localizando...' : 'Usar minha localização atual',
                    style: const TextStyle(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
              ),
              const SizedBox(height: 10),
            ],
            _field('Rótulo', _labelCtrl, hint: 'Casa, Trabalho, etc.'),
            _field('Rua / Avenida', _streetCtrl, hint: 'Rua das Flores', required: true),
            Row(children: [
              Expanded(flex: 2, child: _field('Número', _numberCtrl, hint: '123', keyboard: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: _field('Complemento', _complementCtrl, hint: 'Apto 42, Bloco B')),
            ]),
            _field('Bairro', _neighborhoodCtrl, hint: 'Centro'),
            _field('CEP', _postalCodeCtrl, hint: '01310-100', keyboard: TextInputType.number),
            _field('Cidade', _cityCtrl, hint: 'São Paulo', required: true),
            Row(children: [
              Expanded(flex: 2, child: _field('Estado', _stateCtrl, hint: 'SP')),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: _field('País', _countryCtrl, hint: 'Brasil')),
            ]),
            _field('Referência / Ponto de apoio', _detailsCtrl, hint: 'Portão azul, casa de esquina'),
            Row(children: [
              Checkbox(value: _isDefault, onChanged: (v) => setState(() => _isDefault = v ?? false), activeColor: AppColors.primary),
              const Text('Definir como endereço padrão', style: TextStyle(fontSize: 13, color: AppColors.textDark)),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Salvar Endereço', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
