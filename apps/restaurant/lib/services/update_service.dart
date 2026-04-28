import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show appBaseUrl;

class UpdateService {
  static const _appType = 'restaurant';

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map(int.tryParse).toList();
    final c = current.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final lv = (i < l.length ? l[i] : 0) ?? 0;
      final cv = (i < c.length ? c[i] : 0) ?? 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  static Future<void> checkAndShow(BuildContext context) async {
    try {
      final base = appBaseUrl.replaceAll(RegExp(r'/graphql$'), '');
      final res = await http.get(Uri.parse('$base/version'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final appData = data[_appType] as Map<String, dynamic>?;
      if (appData == null) return;
      final latestVersion = appData['version'] as String? ?? '';
      final downloadUrl = appData['url'] as String? ?? '';
      final info = await PackageInfo.fromPlatform();
      if (!_isNewer(latestVersion, info.version)) return;
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UpdateDialog(version: latestVersion, url: downloadUrl),
      );
    } catch (_) {}
  }
}

class _UpdateDialog extends StatelessWidget {
  final String version;
  final String url;
  const _UpdateDialog({required this.version, required this.url});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Text('⚡ ', style: TextStyle(fontSize: 22)),
        Text('Atualização disponível', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ]),
      content: Text(
        'Uma nova versão do BitFood (v$version) está disponível.\n\nBaixe o APK atualizado para continuar usando o app.',
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Depois', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6600),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Text('Baixar v$version'),
        ),
      ],
    );
  }
}
