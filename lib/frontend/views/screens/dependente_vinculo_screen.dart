// lib/frontend/views/screens/dependente_vinculo_screen.dart
import 'package:flutter/material.dart';

import '../../../../../backend/controller/login_dependente_controller.dart';
import '../../../../../route_transitions.dart';
import '../../theme/colors.dart';
import '../layouts/root_nav_shell.dart';

class DependenteVinculoScreen extends StatefulWidget {
  final DependentLoginController controller;

  const DependenteVinculoScreen({
    super.key,
    required this.controller,
  });

  @override
  State<DependenteVinculoScreen> createState() =>
      _DependenteVinculoScreenState();
}

class _DependenteVinculoScreenState extends State<DependenteVinculoScreen> {
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    // Seleciona o primeiro vínculo por padrão (se existir)
    final vinculos = widget.controller.vinculos;
    if (vinculos.isNotEmpty) {
      _selected = vinculos.first;
    }
  }

  String _formatCpf(String cpfRaw) {
    final digits = cpfRaw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return cpfRaw;
    return '${digits.substring(0, 3)}.'
        '${digits.substring(3, 6)}.'
        '${digits.substring(6, 9)}-'
        '${digits.substring(9)}';
  }

  Future<void> _confirmar() async {
    final v = _selected;
    if (v == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um vínculo para continuar.')),
      );
      return;
    }

    await widget.controller.finishLoginWithVinculo(v);

    if (!mounted) return;

    await pushAndRemoveAllSharedAxis(
      context,
      const RootNavShell(),
      type: SharedAxisTransitionType.vertical,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.controller.profile;
    final vinculos = widget.controller.vinculos;

    if (profile == null || vinculos.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Login do Dependente'),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final maxW =
            constraints.maxWidth > 560 ? 560.0 : constraints.maxWidth;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Não foi possível carregar os vínculos do dependente.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Voltar'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    final cpfFormatado = _formatCpf(profile.cpf);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login do Dependente'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Em telas estreitas ocupa 100%; em telas largas limita a ~560 px
            final maxW =
            constraints.maxWidth > 560 ? 560.0 : constraints.maxWidth;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  children: [
                    // Card principal
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kCardBorder, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              'Login do Dependente',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Center(
                            child: Text(
                              'Selecione o vínculo desejado.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Logado como',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.nome,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'CPF do dependente: $cpfFormatado',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Escolha o vínculo (titular) para acessar:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // === Dropdown responsivo ===
                          DropdownButtonFormField<Map<String, dynamic>>(
                            value: _selected,
                            isExpanded: true, // evita quebra de layout
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: kCardBorder,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: kBrand,
                                  width: 1.6,
                                ),
                              ),
                            ),
                            items: vinculos.map((v) {
                              final idMatricula =
                                  v['idmatricula'] ?? v['matricula'];
                              final nomeTitular =
                              (v['nome_titular'] ?? 'Titular')
                                  .toString()
                                  .trim();
                              final label =
                                  '$nomeTitular — Matrícula: ${idMatricula ?? ''}';
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: v,
                                child: Text(
                                  label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selected = value);
                            },
                          ),

                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: kBrand,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _confirmar,
                              child: const Text(
                                'Acessar',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kPanelBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kPanelBorder),
                      ),
                      child: const Text(
                        'Caso o dependente esteja vinculado a mais de um titular, '
                            'selecione o vínculo desejado para acessar as informações.',
                        style: TextStyle(color: Color(0xFF475467)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
