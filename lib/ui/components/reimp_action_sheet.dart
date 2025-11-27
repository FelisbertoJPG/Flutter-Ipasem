import 'package:flutter/material.dart';
import '../../models/reimpressao.dart';

enum ReimpAction { detalhes, pdfLocal }

Future<ReimpAction?> showReimpActionSheet(
    BuildContext context,
    ReimpressaoResumo a,
    ) {
  return showModalBottomSheet<ReimpAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final textTheme = Theme.of(ctx).textTheme;
      final muted = textTheme.bodySmall?.copyWith(color: Colors.black54);

      Widget item({
        required IconData icon,
        required String title,
        String? subtitle,
        required ReimpAction action,
      }) {
        return ListTile(
          leading: Icon(icon),
          title: Text(title, style: textTheme.bodyLarge),
          subtitle: subtitle != null ? Text(subtitle, style: muted) : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(ctx).pop<ReimpAction>(action),
          visualDensity: VisualDensity.compact,
        );
      }

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.40,
        minChildSize: 0.30,
        maxChildSize: 0.90,
        builder: (_, controller) {
          return SafeArea(
            top: false,
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                Text(
                  'Reimpressão da Ordem',
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('Deseja imprimir a ordem ${a.numero}?', style: muted),
                const SizedBox(height: 12),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE6E9ED)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      item(
                        icon: Icons.info_outline,
                        title: 'Ver detalhes',
                        subtitle: (a.prestadorExec.isNotEmpty || a.paciente.isNotEmpty)
                            ? [a.prestadorExec, a.paciente]
                            .where((s) => s.isNotEmpty)
                            .join(' • ')
                            : null,
                        action: ReimpAction.detalhes,
                      ),
                      const Divider(height: 1),
                      item(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'PDF no app',
                        subtitle: 'Pré-visualizar e imprimir no aplicativo',
                        action: ReimpAction.pdfLocal,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
