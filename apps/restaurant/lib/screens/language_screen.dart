import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/locale_provider.dart';
import '../theme.dart';

class LanguageScreen extends StatefulWidget {
  final VoidCallback onSelected;
  const LanguageScreen({super.key, required this.onSelected});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String? _selected;

  static const _langs = [
    {'code': 'pt', 'flag': '🇧🇷', 'name': 'Português do Brasil', 'native': 'Português'},
    {'code': 'en', 'flag': '🇺🇸', 'name': 'English', 'native': 'English'},
    {'code': 'es', 'flag': '🇲🇽', 'name': 'Español (América Latina)', 'native': 'Español'},
    {'code': 'fr', 'flag': '🇫🇷', 'name': 'Français', 'native': 'Français'},
    {'code': 'gn', 'flag': '🇵🇾', 'name': 'Guaraní (Paraguay)', 'native': 'Avañe\'ẽ'},
  ];

  Future<void> _confirm() async {
    if (_selected == null) return;
    await Provider.of<LocaleProvider>(context, listen: false).setLocale(_selected!);
    widget.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                child: const Center(child: Text('⚡', style: TextStyle(fontSize: 36))),
              ),
              const SizedBox(height: 16),
              const Text('BitFood', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text('Choose your language / Escolha seu idioma', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const Spacer(flex: 1),
              ..._langs.map((lang) => _LangTile(
                flag: lang['flag']!,
                name: lang['name']!,
                native: lang['native']!,
                selected: _selected == lang['code'],
                onTap: () => setState(() => _selected = lang['code']),
              )),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected == null ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.textLight,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continuar / Continue', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String flag, name, native;
  final bool selected;
  final VoidCallback onTap;
  const _LangTile({required this.flag, required this.name, required this.native, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withOpacity(0.08) : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 2 : 1),
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(native, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: selected ? AppColors.primary : AppColors.textDark)),
                Text(name, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
        ],
      ),
    ),
  );
}
