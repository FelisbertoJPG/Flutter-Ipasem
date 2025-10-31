// lib/ui/components/quick_actions.dart
import 'package:flutter/material.dart';
import './section_card.dart';
import '../sheets/card_sheet.dart';

enum QaAudience { all, loggedIn, visitor }

class QuickActionItem {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final QaAudience audience;
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

class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.items,
    required this.isLoggedIn,
    this.onRequireLogin,
    this.title,
    this.outerPadding, // ⬅ opcional pra controlar a margem externa
  });

  final List<QuickActionItem> items;
  final bool isLoggedIn;
  final VoidCallback? onRequireLogin;
  final String? title;

  /// Margem EXTERNA do card (entre o card e as bordas da tela/seção).
  /// Se não for informada, usa breakpoints responsivos.
  final EdgeInsetsGeometry? outerPadding;

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

    final w = MediaQuery.of(context).size.width;

    // margem EXTERNA do card (até a borda da tela)
    final double hPadDefault =
    w >= 1024 ? 32 :
    w >=  840 ? 24 :
    w >=  600 ? 20 : 0; //  “engordar” um pouco

    // padding INTERNO do card (respiro do conteúdo, estilo WelcomeCard)
    final double inPad = w < 360 ? 12 : 16;

    // largura máxima por tile (Grid usa esse maxCrossAxisExtent)
    final double maxExtent =
    w >= 1024 ? 220 :
    w >=  840 ? 200 :
    w >=  600 ? 180 : 168;

    // altura do tile sensível ao textScale (acessibilidade)
    final tScale = MediaQuery.textScaleFactorOf(context);
    final double tileHeight = 112.0 + (tScale - 1.0) * 36.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // afasta o card das laterais da tela
          padding: outerPadding ?? EdgeInsets.symmetric(horizontal: hPadDefault),
          child: SectionCard(
            title: title,
            // padding interno no conteúdo do card
            child: Padding(
              padding: EdgeInsets.all(inPad),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: tileHeight,
                ),
                itemBuilder: (context, i) {
                  final it = visible[i];
                  final locked = it.requiresLogin && !isLoggedIn;

                  void handleTap() {
                    if (locked) {
                      onRequireLogin?.call();
                      if (onRequireLogin == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Faça login para usar esta função.'),
                          ),
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
            ),
          ),
        ),
        const SizedBox(height: 12), // respiro até o próximo bloco
      ],
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Opacity(opacity: locked ? 0.6 : 1.0, child: base),
      ),
    );
  }
}
