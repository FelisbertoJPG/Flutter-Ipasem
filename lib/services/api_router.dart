// lib/services/api_router.dart
import 'package:flutter/widgets.dart';
import '../config/app_config.dart';
import 'dev_api.dart';

class ApiRouter {
  static String _base = 'https://assistweb.ipasemnh.com.br';
  static String _apiPath = '/api-dev.php';
  static bool _configured = false;

  /// Chame 1x no bootstrap (main) com a base definida pela flavor.
  /// Aceita:
  ///  - http://host
  ///  - http://host/
  ///  - http://host/api-dev.php
  static void configure(String baseOrGateway, {String defaultGatewayPath = '/api-dev.php'}) {
    var raw = baseOrGateway.trim();
    while (raw.endsWith('/')) raw = raw.substring(0, raw.length - 1);

    if (raw.toLowerCase().endsWith('.php')) {
      final cut = raw.lastIndexOf('/');
      _base = raw.substring(0, cut);   // http://host
      _apiPath = raw.substring(cut);   // /api-dev.php
    } else {
      _base = raw;                     // http://host
      _apiPath = defaultGatewayPath;   // /api-dev.php
    }
    _configured = true;
  }

  /// Retorna um DevApi usando a configuração atual.
  /// Se ninguém configurou ainda, cai para o --dart-define=API_BASE (fallback).
  static DevApi client() {
    if (!_configured) {
      final env = const String.fromEnvironment(
        'API_BASE',
        defaultValue: 'https://assistweb.ipasemnh.com.br/api-dev.php',
      );
      configure(env);
    }
    return DevApi(_base, apiPath: _apiPath);
  }

  /// Conveniência: tenta ler do AppConfig do contexto e configura.
  static DevApi fromContext(BuildContext? context) {
    final cfgBase = AppConfig.maybeOf(context!)?.params.baseApiUrl;
    if (cfgBase != null && cfgBase.isNotEmpty) {
      configure(cfgBase);
    }
    return client();
  }
}
