import 'package:flutter/material.dart';
import '../../theme/colors.dart'; // kBrand, kCardBg, kCardBorder

class WelcomeCard extends StatelessWidget {
  const WelcomeCard({
    super.key,
    required this.isLoggedIn,
    this.name,            // nome opcional para saudar
    this.cpf,             // envie já formatado se quiser (ex.: 123.456.789-00)
    this.sexoTxt,         // "M", "F", "MASCULINO", "FEMININO" etc. (titular)
    required this.onLogin, // usado somente no modo visitante
  });

  final bool isLoggedIn;
  final String? name;
  final String? cpf;
  final String? sexoTxt;
  final VoidCallback onLogin;

  String _firstName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? full : parts.first;
  }

  String _onlyDigits(String? input) {
    if (input == null) return '';
    return input.replaceAll(RegExp(r'\D'), '');
  }

  /// Decide a saudação com base no login + sexo do titular.
  /// Regras:
  /// - Se CPF for o 78945612300 → "Bem-vindo, João"
  /// - Se o nome vier como "USUARIO"/"USUÁRIO" → "Bem-vindo, João"
  /// - Visitante: mantém "Bem-vindo"
  /// - Logado:
  ///    • sexoTxt começando com "F" → "Bem-vinda"
  ///    • caso contrário → "Bem-vindo"
  String _buildTitle() {
    final rawName = (name ?? '').trim();
    final upperName = rawName.toUpperCase();
    final digitsCpf = _onlyDigits(cpf);

    // 1) Regra especial pelo CPF (tratando formatado ou não)
    if (digitsCpf == '78945612300') {
      return 'Bem-vindo, João';
    }

    // 2) Regra especial pelo nome placeholder
    if (upperName == 'USUARIO' || upperName == 'USUÁRIO') {
      return 'Bem-vindo, João';
    }

    final hasName = rawName.isNotEmpty;
    final sexo = (sexoTxt ?? '').trim().toUpperCase();
    final prefixo = sexo.startsWith('F') ? 'Bem-vinda' : 'Bem-vindo';

    if (!hasName) {
      return prefixo;
    }

    if (!isLoggedIn) {
      // Visitante não tem sexo conhecido, mantém neutro
      return 'Bem-vindo';
    }

    return '$prefixo, ${_firstName(rawName)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = _buildTitle();

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título com ícone
          Row(
            children: [
              const Icon(Icons.handshake_outlined, size: 25, color: kBrand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Chips de status + CPF (se houver)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatusChip(
                label: isLoggedIn ? 'Acesso autenticado' : 'Acesso limitado',
                color: isLoggedIn
                    ? const Color(0xFF027A48)
                    : const Color(0xFF6941C6),
                bg: isLoggedIn
                    ? const Color(0xFFD1FADF)
                    : const Color(0xFFF4EBFF),
              ),
              if (cpf != null && cpf!.isNotEmpty)
                const _StatusChip(
                  label: '',
                  color: Color(0xFF475467),
                  bg: Color(0xFFEFF6F9),
                ).copyWith(label: 'CPF: $cpf'),
            ],
          ),

          const SizedBox(height: 12),

          // CTA apenas para visitante
          if (!isLoggedIn)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kBrand,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: onLogin,
                icon: const Icon(Icons.login),
                label: const Text('Fazer login'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  // helper para trocar apenas o texto mantendo cores.
  _StatusChip copyWith({String? label}) =>
      _StatusChip(label: label ?? this.label, color: color, bg: bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bg),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
