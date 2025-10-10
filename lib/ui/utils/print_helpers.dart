// utils/print_helpers.dart (ou dentro da sua tela de emissão)
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../pdf/pdf_mappers.dart';
import '../../repositories/reimpressao_repository.dart';
import '../../screens/pdf_preview_screen.dart';
import '../../services/dev_api.dart';
import '../../services/session.dart';

Future<void> openPreviewFromNumero(BuildContext context, int numero) async {
  try {
    final profile = await Session.getProfile();
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter o perfil do usuário.')),
      );
      return;
    }

    final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
        ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');
    final repo = ReimpressaoRepository(DevApi(baseUrl));

    final det = await repo.detalhe(numero, idMatricula: profile.id);
    if (det == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar os detalhes desta ordem.')),
      );
      return;
    }

    final data = mapDetalheToPdfData(
      det: det,
      idMatricula: profile.id,
      nomeTitular: profile.nome,
      procedimentos: const [],
    );

    final fileName = 'ordem_${det.numero}.pdf';
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => PdfPreviewScreen(data: data, fileName: fileName)),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Falha ao abrir impressão: $e')),
    );
  }
}
