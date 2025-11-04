// lib/services/api_router.dart
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'dev_api.dart';

/// Fonte única da base da API/gateway para todo o app.
/// Suporta:
///  - http(s)://host
///  - http(s)://host/
///  - http(s)://host/api-dev.php
class ApiRouter {
  static const String _defaultBase = 'https://assistweb.ipasemnh.com.br';
  static const String _defaultGatewayPath = '/api-dev.php';

  static const String _prefsBaseKey = 'api_base';
  static const String _prefsPathKey = 'api_path';

  static String _base = _defaultBase;      // ex.: https://assistweb.ipasemnh.com.br
  static String _apiPath = _defaultGatewayPath; // ex.: /api-dev.php
  static bool _configured = false;

  /// Chame 1x no bootstrap (entrypoint) com a base definida pela flavor.
  /// Aceita:
  ///  - http://host
  ///  - http://host/
  ///  - http://host/api-dev.php
  static void configure(String baseOrGateway, {String defaultGatewayPath = _defaultGatewayPath}) {
    var raw = baseOrGateway.trim();

    // Remove barras finais duplicadas (sem mexer no esquema)
    while (raw.endsWith('/')) {
      raw = raw.substring(0, raw.length - 1);
    }

    if (raw.toLowerCase().endsWith('.php')) {
      // veio como gateway completo
      final cut = raw.lastIndexOf('/');
      _base = raw.substring(0, cut);     // http(s)://host
      _apiPath = raw.substring(cut);     // /api-dev.php
    } else {
      _base = raw;                       // http(s)://host
      _apiPath = defaultGatewayPath;     // /api-dev.php (ou o informado)
    }

    // Garante que o path começa com '/'
    if (_apiPath.isNotEmpty && !_apiPath.startsWith('/')) {
      _apiPath = '/$_apiPath';
    }

    _configured = true;
  }

  /// Persiste a configuração atual para outros isolates (ex.: Workmanager).
  static Future<void> persistToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsBaseKey, _base);
    await prefs.setString(_prefsPathKey, _apiPath);
  }

  /// Recarrega a configuração do SharedPreferences (use no isolate do worker).
  static Future<void> configureFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBase = prefs.getString(_prefsBaseKey);
    final savedPath = prefs.getString(_prefsPathKey);

    if ((savedBase != null && savedBase.isNotEmpty) &&
        (savedPath != null && savedPath.isNotEmpty)) {
      _base = _normalizeBase(savedBase);
      _apiPath = savedPath.startsWith('/') ? savedPath : '/$savedPath';
      _configured = true;
    }
  }

  /// Fallback de ambiente se ninguém configurou (mantém compat com seu código atual).
  static void _ensureConfiguredSync() {
    if (_configured) return;

    // Tenta env var (síncrono)
    final env = const String.fromEnvironment(
      'API_BASE',
      defaultValue: '$_defaultBase$_defaultGatewayPath',
    );
    configure(env);
  }

  /// Cliente síncrono — assume que já foi configurado no entrypoint
  /// (ou cai no fallback via --dart-define).
  static DevApi client() {
    _ensureConfiguredSync();
    return DevApi(_base, apiPath: _apiPath);
  }

  /// Cliente assíncrono — garante tentar prefs antes de cair no env.
  /// Útil em isolates (ex.: worker) onde você não chamou `configure(...)` antes.
  static Future<DevApi> clientAsync() async {
    if (!_configured) {
      await configureFromPrefs();
      if (!_configured) {
        _ensureConfiguredSync();
      }
    }
    return DevApi(_base, apiPath: _apiPath);
  }

  /// Conveniência: tenta ler do AppConfig (se houver no contexto) e configura.
  /// Nunca usa `context!`; funciona mesmo com `context == null`.
  static DevApi fromContext(BuildContext? context) {
    final cfgBase = context != null ? AppConfig.maybeOf(context)?.params.baseApiUrl : null;
    if (cfgBase != null && cfgBase.isNotEmpty) {
      configure(cfgBase);
    } else {
      _ensureConfiguredSync();
    }
    return DevApi(_base, apiPath: _apiPath);
  }

  /// Base atual (ex.: https://host)
  static String get base => _base;

  /// Path do gateway atual (ex.: /api-dev.php)
  static String get apiPath => _apiPath;

  /// URL completa do gateway (ex.: https://host/api-dev.php)
  static Uri get gatewayUri {
    final root = Uri.parse(_base.endsWith('/') ? _base : '$_base/');
    final rel = Uri.parse(_apiPath.startsWith('/') ? _apiPath.substring(1) : _apiPath);
    return root.resolveUri(rel);
  }

  /// Helper para montar URL do gateway com query (ex.: action=..., outros params)
  static Uri gatewayWithQuery(Map<String, dynamic> query) {
    final u = gatewayUri;
    return u.replace(queryParameters: {
      ...u.queryParameters,
      ...query.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    });
  }

  // ===== Internos =====

  static String _normalizeBase(String base) {
    var b = base.trim();
    while (b.endsWith('//')) {
      b = b.substring(0, b.length - 1);
    }
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b;
  }
}
