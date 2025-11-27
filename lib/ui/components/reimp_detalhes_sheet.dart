import 'package:flutter/material.dart';
import '../../models/reimpressao.dart';

Future<void> showReimpDetalhesSheet({
  required BuildContext context,
  required ReimpressaoDetalhe det,
  String? pacienteFallback,
  required VoidCallback onPrintViaSite,
}) async {
  String _mkPaciente(ReimpressaoDetalhe d) {
    final p = d.nomePaciente.trim();
    if (p.isNotEmpty) return p;
    if (pacienteFallback != null && pacienteFallback!.trim().isNotEmpty) {
      return pacienteFallback!.trim();
    }
    return '';
  }

  Widget _kv(String k, String v) => LayoutBuilder(
    builder: (context, constraints) {
      final total = constraints.maxWidth;
      final labelW = total.clamp(280, 9999) == total
          ? 120.0
          : (total * 0.34).clamp(110.0, 160.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelW,
              child: Text(k, style: const TextStyle(color: Colors.black54)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(fontWeight: FontWeight.w600),
                softWrap: true,
              ),
            ),
          ],
        ),
      );
    },
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) {
      final paciente = _mkPaciente(det);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, controller) {
          final theme = Theme.of(ctx);
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCE5EE),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Dados da Autorização',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),

                  _kv('Número', '${det.numero}'),
                  _kv('Paciente', paciente),
                  _kv('Prestador', det.nomePrestadorExec),
                  _kv('Especialidade', det.nomeEspecialidade),
                  _kv('Data de Emissão', det.dataEmissao),

                  const Divider(height: 24),

                  _kv('Endereço', det.enderecoComl),
                  _kv(
                    'Bairro/Cidade',
                    [
                      if (det.bairroComl.isNotEmpty) det.bairroComl,
                      if (det.cidadeComl.isNotEmpty) det.cidadeComl,
                    ].where((s) => s.isNotEmpty).join(' - '),
                  ),
                  if (det.telefoneComl.trim().isNotEmpty) _kv('Telefone', det.telefoneComl),

                  if (det.observacoes.trim().isNotEmpty) ...[
                    const Divider(height: 24),
                    _kv('Observações', det.observacoes),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
