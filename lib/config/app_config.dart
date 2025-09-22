// lib/config/app_config.dart
import 'package:flutter/widgets.dart';
import 'params.dart';

class AppConfig extends InheritedWidget {
  final AppParams params;
  final String flavor; // ex.: dev/hml/prod

  const AppConfig({
    super.key,
    required this.params,
    required this.flavor,
    required super.child,
  });

  static AppConfig of(BuildContext context) {
    final cfg = context.dependOnInheritedWidgetOfExactType<AppConfig>();
    assert(cfg != null, 'AppConfig não encontrado no contexto.');
    return cfg!;
  }

  @override
  bool updateShouldNotify(covariant AppConfig oldWidget) =>
      oldWidget.params != params || oldWidget.flavor != flavor;
}
