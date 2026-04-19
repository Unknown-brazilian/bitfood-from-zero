import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/locale_provider.dart';
import '../theme/app_theme.dart';

class TermsScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  final VoidCallback onDeclined;
  const TermsScreen({super.key, required this.onAccepted, required this.onDeclined});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final _scrollCtrl = ScrollController();
  bool _scrolledToBottom = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.offset >= _scrollCtrl.position.maxScrollExtent - 60) {
        if (!_scrolledToBottom) setState(() => _scrolledToBottom = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terms_accepted_v1', true);
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<LocaleProvider>(context).t;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('tos_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Scroll hint
          if (!_scrolledToBottom)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.arrow_downward, color: AppColors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t('tos_scroll_hint'), style: const TextStyle(color: AppColors.orange, fontSize: 12))),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(title: t('tos_s1_title'), body: t('tos_s1_body')),
                  _Section(title: t('tos_s2_title'), body: t('tos_s2_body')),
                  _Section(title: t('tos_s3_title'), body: t('tos_s3_body')),
                  _Section(title: t('tos_s4_title'), body: t('tos_s4_body')),
                  _Section(title: t('tos_s5_title'), body: t('tos_s5_body')),
                  const SizedBox(height: 16),
                  Text(t('tos_closing'), style: const TextStyle(fontSize: 13, color: AppColors.textGrey, fontStyle: FontStyle.italic, height: 1.5)),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Bottom actions
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _scrolledToBottom ? () => setState(() => _checked = !_checked) : null,
                  child: Row(
                    children: [
                      Checkbox(
                        value: _checked,
                        onChanged: _scrolledToBottom ? (v) => setState(() => _checked = v!) : null,
                        activeColor: AppColors.primary,
                      ),
                      Expanded(
                        child: Text(
                          t('tos_checkbox'),
                          style: TextStyle(fontSize: 13, color: _scrolledToBottom ? AppColors.textDark : AppColors.textLight),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_scrolledToBottom && _checked) ? _accept : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.textLight,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(t('tos_btn_accept'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onDeclined,
                  child: Text(t('tos_btn_decline'), style: const TextStyle(color: AppColors.textGrey)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title, body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(body, style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.6)),
        ),
      ],
    ),
  );
}
