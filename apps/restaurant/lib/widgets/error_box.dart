import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ErrorBox extends StatefulWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorBox({super.key, required this.error, this.onRetry});

  static String _friendly(Object err) {
    final s = err.toString();
    if (s.contains('TimeoutException') || s.contains('No stream event'))
      return 'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.';
    if (s.contains('SocketException') || s.contains('NetworkException'))
      return 'Sem conexão com a internet.';
    if (s.contains('401') || s.contains('Unauthorized') || s.contains('não autorizado'))
      return 'Sessão expirada. Faça login novamente.';
    if (s.contains('403') || s.contains('Forbidden') || s.contains('acesso negado'))
      return 'Você não tem permissão para essa ação.';
    if (s.contains('404') || s.contains('not found') || s.contains('não encontrado'))
      return 'O recurso solicitado não foi encontrado.';
    if (s.contains('500') || s.contains('Internal'))
      return 'Erro interno no servidor. Tente novamente em instantes.';
    if (s.contains('Senha') || s.contains('senha') || s.contains('password'))
      return 'E-mail ou senha incorretos.';
    if (s.contains('E-mail') || s.contains('email') || s.contains('already exists'))
      return 'Este e-mail já está cadastrado.';
    final gql = RegExp(r'graphqlErrors: \[(.+?)\]').firstMatch(s);
    if (gql != null) return gql.group(1) ?? s;
    if (s.length > 120) return '${s.substring(0, 120)}…';
    return s;
  }

  @override
  State<ErrorBox> createState() => _ErrorBoxState();
}

class _ErrorBoxState extends State<ErrorBox> {
  bool _expanded = false;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final friendly = ErrorBox._friendly(widget.error);
    final detail = widget.error.toString();
    final isDifferent = detail != friendly && detail.length > friendly.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    friendly,
                    style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          if (widget.onRetry != null || isDifferent)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  if (isDifferent)
                    TextButton.icon(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16),
                      label: Text(_expanded ? 'Ocultar detalhes' : 'Ver detalhes',
                          style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                  const Spacer(),
                  if (widget.onRetry != null)
                    TextButton.icon(
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Tentar novamente', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                ],
              ),
            ),
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFFFFCDD2)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(detail,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF7B0000),
                          fontFamily: 'monospace', height: 1.4)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: detail));
                        setState(() => _copied = true);
                        Future.delayed(const Duration(seconds: 2),
                            () { if (mounted) setState(() => _copied = false); });
                      },
                      icon: Icon(_copied ? Icons.check : Icons.copy, size: 14),
                      label: Text(_copied ? 'Copiado!' : 'Copiar para suporte',
                          style: const TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
