// lib/ui/components/quick_actions.dart
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
        case QaAudience.all:
          return true;
        case QaAudience.loggedIn:
          return isLoggedIn;
        case QaAudience.visitor:
          return !isLoggedIn;
      }
    }).toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tScale = MediaQuery.textScaleFactorOf(context);

    // altura do tile adaptada à acessibilidade
    final double tileHeight = 112.0 + (tScale - 1.0) * 36.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // controla largura máxima por card para a grade "respirar"
        final double maxExtent =
        constraints.maxWidth >= 720 ? 190 : constraints.maxWidth >= 560 ? 180 : 168;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  title!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF344054),
                  ),
                ),
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visible.length,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: maxExtent,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                // força altura consistente por item (bom para até 3 linhas de label)
                mainAxisExtent: tileHeight,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: const Color(0xFF143C8D)),
                const SizedBox(height: 8),
                // até 3 linhas, quebra natural e ellipsis só se faltar espaço
                Text(
                  label,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
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

    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Opacity(
            opacity: locked ? 0.6 : 1.0,
            child: base,
          ),
        ),
      ),
    );
  }
}
