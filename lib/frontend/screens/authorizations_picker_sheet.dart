// lib/screens/authorizations_picker_sheet.dart
import 'package:flutter/material.dart';

// Telas de destino
import 'autorizacao_medica_screen.dart';
import 'autorizacao_odontologica_screen.dart';
import 'autorizacao_exames_screen.dart';

/// Abre um bottom-sheet com as três opções de autorização.
/// Ao tocar em uma opção, o sheet é fechado e a tela correspondente é aberta
/// via Navigator.push(MaterialPageRoute(...)), seguindo o seu modelo atual.
Future<void> showAuthorizationsPickerSheet(BuildContext parentContext) async {
  await showModalBottomSheet<void>(
    context: parentContext,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final divider = Divider(
        height: 1,
        color: theme.dividerColor.withOpacity(0.12),
      );

      void go(Widget screen) {
        // Fecha o sheet primeiro…
        Navigator.pop(sheetCtx);
        // …e então navega no contexto do caller.
        Future.microtask(() {
          Navigator.of(parentContext).push(
            MaterialPageRoute(builder: (_) => screen),
          );
        });
      }

      Widget tile({
        required IconData icon,
        required String title,
        String? subtitle,
        required VoidCallback onTap,
      }) {
        return ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: (subtitle == null || subtitle.isEmpty)
              ? null
              : Text(subtitle, style: const TextStyle(fontSize: 12.5)),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
          onTap: onTap,
        );
      }

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE5EE),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const Text(
                'Escolha o tipo de autorização',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Selecione uma das opções abaixo para continuar.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.dividerColor.withOpacity(0.35),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    tile(
                      icon: Icons.local_hospital_outlined,
                      title: 'Autorização Médica',
                      subtitle: 'Consultas, procedimentos clínicos e afins.',
                      onTap: () => go(const AutorizacaoMedicaScreen()),
                    ),
                    divider,
                    tile(
                      icon: Icons.health_and_safety_outlined,
                      title: 'Autorização Odontológica',
                      subtitle: 'Atendimentos odontológicos e procedimentos.',
                      onTap: () => go(const AutorizacaoOdontologicaScreen()),
                    ),
                    divider,
                    tile
                      (
                      icon: Icons.biotech_outlined,
                      title: 'Autorização de Exames',
                      subtitle: 'Exames laboratoriais e de imagem.',
                      onTap: () => go(const AutorizacaoExamesScreen()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
