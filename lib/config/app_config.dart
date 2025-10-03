import 'package:flutter/widgets.dart';
import 'params.dart';

class AppConfig extends InheritedWidget {
  final AppParams params;
  final String flavor;

  const AppConfig({
    super.key,
    required this.params,
    required this.flavor,
    required super.child,
  });

  /// Variante não nula: falha cedo se não estiver presente.
  static AppConfig of(BuildContext context) {
    final cfg = context.dependOnInheritedWidgetOfExactType<AppConfig>();
    assert(cfg != null, 'AppConfig não encontrado no contexto');
    return cfg!;
  }

  /// Variante opcional (pode retornar null).
  static AppConfig? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppConfig>();
  }

  @override
  bool updateShouldNotify(AppConfig oldWidget) =>
      oldWidget.params != params || oldWidget.flavor != flavor;
}