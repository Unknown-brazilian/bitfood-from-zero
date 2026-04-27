import 'dart:convert';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kCountryKey = 'detected_country_iso2';
const _kCountryNameKey = 'detected_country_name';

class LocationService {
  static String? _iso2;
  static String? _countryName;

  static String? get detectedIso2 => _iso2;
  static String? get detectedCountryName => _countryName;

  /// Solicita permissão e detecta o país do dispositivo via GPS + Nominatim.
  /// Armazena o resultado em SharedPreferences para uso offline.
  static Future<void> detectCountry() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _iso2 = prefs.getString(_kCountryKey);
        _countryName = prefs.getString(_kCountryNameKey);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );

      final client = HttpClient();
      client.userAgent = 'BitFood/1.0 (arthurleobertotto@gmail.com)';
      final req = await client.getUrl(Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${pos.latitude}&lon=${pos.longitude}&format=json',
      ));
      req.headers.set('Accept-Language', 'en');
      final resp = await req.close();
      final body = await resp.transform(const Utf8Decoder()).join();
      client.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final addr = (data['address'] as Map<String, dynamic>?) ?? {};
      final countryCode = (data['address']?['country_code'] as String?)?.toUpperCase();
      final countryName = addr['country'] as String?;

      if (countryCode != null) {
        _iso2 = countryCode;
        _countryName = countryName;
        await prefs.setString(_kCountryKey, countryCode);
        if (countryName != null) {
          await prefs.setString(_kCountryNameKey, countryName);
        }
      }
    } catch (_) {
      // Fallback para cache
      _iso2 = prefs.getString(_kCountryKey);
      _countryName = prefs.getString(_kCountryNameKey);
    }
  }
}
