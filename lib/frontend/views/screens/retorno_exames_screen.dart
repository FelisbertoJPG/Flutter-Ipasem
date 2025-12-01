// lib/screens/retorno_exames_screen.dart
import 'package:flutter/material.dart';

import '../components/exames_comp/exames_liberados_card.dart';
import '../components/exames_comp/exames_pendentes_card.dart';
import '../layouts/app_shell.dart';
import '../components/exames_comp/exames_negadas_card.dart';

class RetornoExamesScreen extends StatelessWidget {
  const RetornoExamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Retorno de Autorizações de Exames',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          ExamesPendentesCard(),
          SizedBox(height: 12),
          ExamesLiberadosCard(),
          SizedBox(height: 12),
          ExamesNegadasCard(),
        ],
      ),
    );
  }
}
