import 'package:flutter/material.dart';

/// Público-alvo do item de ação.
enum QaAudience { all, loggedIn, visitor }

/// Modelo de item de ação rápida.
class QuickActionItem {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Quem deve ver este item (all/loggedIn/visitor).
  final QaAudience audience;

  /// Se true, o item aparece para todos, mas exige login no toque quando
  /// o usuário for visitante (mostra cadeado e chama onRequireLogin).
  final bool requiresLogin;

  const QuickActionItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.audience = QaAudience.all,
    this.requiresLogin = false,
  });
}

/// Grid de ações rápidas.
/// - Filtra por [audience].
/// - Mostra cadeado e bloqueia o toque de itens `requiresLogin` quando visitante.
/// - Chama [onRequireLogin] quando um item bloqueado for tocado.
class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.items,
    required this.isLoggedIn,
    this.onRequireLogin,
    this.title,
  });

  final List<QuickActionItem> items;
  final bool isLoggedIn;
  final VoidCallback? onRequireLogin;
  final String? title;
  @override
  Widget build(BuildContext context) {
    final visible = items.where((it) {
      switch (it.audience) {
        case QaAudience.all:      return true;
        case QaAudience.loggedIn: return isLoggedIn;
        case QaAudience.visitor:  return !isLoggedIn;
      }
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 3 colunas padrão, 4 em telas largas
        final cols = constraints.maxWidth >= 560 ? 4 : 3;

        // cálculo robusto de altura do tile (base + ajuste por acessibilidade)
        final textScale = MediaQuery.textScaleFactorOf(context);
        final baseH = 96.0; // altura confortável p/ ícone + 2 linhas
        final tileH = baseH + (textScale - 1.0) * 28.0; // cresce com fonte maior

        // largura de cada célula (considera espaçamento)
        const spacing = 12.0;
        final itemW = (constraints.maxWidth - spacing * (cols - 1)) / cols;

        // usamos ratio = largura/altura para dar a altura desejada
        final ratio = itemW / tileH;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Serviços em destaque', // ou use title!
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF344054),
                  ),
                ),
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visible.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: ratio, // <<< evita overflow
              ),
              itemBuilder: (context, i) {
                final it = visible[i];
                final locked = it.requiresLogin && !isLoggedIn;

                void handleTap() {
                  if (locked) {
                    if (onRequireLogin != null) {
                      onRequireLogin!();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Faça login para usar esta função.')),
                      );
                    }
                    return;
                  }
                  it.onTap();
                }

                return _QaTile(
                  label: it.label,
                  icon: it.icon,
                  locked: locked,
                  onTap: handleTap,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _QaTile extends StatelessWidget {
  const _QaTile({
    required this.label,
    required this.icon,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool locked;
  final VoidCallback onTap;


  @override
  Widget build(BuildContext context) {
  final base = Container(
  decoration: BoxDecoration(
  color: const Color(0xFFF7FAFC),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: const Color(0xFFE6EDF3), width: 1.5),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 12->10
  child: Stack(
  children: [
  Align(
  alignment: Alignment.center,
  child: Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
  const Icon(Icons.circle, size: 0), // nada; só se quiser equalizar baseline
  Icon(icon, size: 24, color: const Color(0xFF143C8D)), // 26->24
  const SizedBox(height: 6), // 8->6
  Text(
  label,
  textAlign: TextAlign.center,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: const TextStyle(
  fontSize: 12.5,              // 13 -> 12.5
  height: 1.1,                 // ajuda a caber 2 linhas
  fontWeight: FontWeight.w600,
  color: Color(0xFF101828),
  ),
  ),
  ],
  ),
  ),
  if (locked)
  const Positioned(
  top: 6,
  right: 6,
  child: Icon(Icons.lock_outline, size: 16, color: Color(0xFF98A2B3)),
  ),
  ],
  ),
  );

  return Material(
  color: Colors.transparent,
  child: InkWell(
  borderRadius: BorderRadius.circular(16),
  onTap: onTap,
  child: Opacity(
  opacity: locked ? 0.6 : 1.0,
  child: base,
  ),
  ),
  );
  }
  }
