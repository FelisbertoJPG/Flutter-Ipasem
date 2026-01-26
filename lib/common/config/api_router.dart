import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Fonte única da base da API para todo o app.
///
/// Backend (Yii):
///   'api/v1/<controller:[-\w]+>/<action:[-\w]+>' => 'api/<controller>/<action>'
///
/// Flutter:
///   ApiRouter.apiRootUri         -> https://host/api/v1
///   ApiRouter.endpoint('exame/historico')
///     -> https://host/api/v1/exame/historico
class ApiRouter {
  // ===== Defaults =====
  static const String _defaultBase = 'https://assistweb.ipasemnh.com.br';
  static const String _defaultApiPrefix = '/api/v1';

  // Chaves para SharedPreferences
  static const String _prefsBaseKey = 'api_base';
  static const String _prefsPrefixKey = 'api_prefix';

  static String _base = _defaultBase;
  static String _apiPrefix = _defaultApiPrefix;
  static bool _configured = false;

  // =====================================================================
  // Configuração
  // =====================================================================

  /// Configure em main() se quiser sobrepor os defaults/env.
  ///
  /// Exemplos:
  ///   ApiRouter.configure('http://192.9.200.98');
  ///   ApiRouter.configure('https://assistweb.ipasemnh.com.br');
  static void configure(
      String baseUrl, {
        String apiPrefix = _defaultApiPrefix,
      }) {
    _base = _normalizeBase(baseUrl);

    _apiPrefix = apiPrefix.trim().isEmpty
        ? _defaultApiPrefix
        : (apiPrefix.startsWith('/') ? apiPrefix : '/$apiPrefix');

    _configured = true;
  }

  /// Persiste a configuração atual (para isolates de background, etc.).
  static Future<void> persistToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsBaseKey, _base);
    await prefs.setString(_prefsPrefixKey, _apiPrefix);
  }

  /// Recarrega a configuração a partir de SharedPreferences.
  static Future<void> configureFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBase = prefs.getString(_prefsBaseKey);
    final savedPrefix = prefs.getString(_prefsPrefixKey);

    if (savedBase != null && savedBase.isNotEmpty) {
      _base = _normalizeBase(savedBase);
    }
    if (savedPrefix != null && savedPrefix.isNotEmpty) {
      _apiPrefix =
      savedPrefix.startsWith('/') ? savedPrefix : '/$savedPrefix';
    }

    _configured = true;
  }

  /// Fallback se ninguém chamou `configure(...)` explicitamente.
  ///
  /// Usa:
  ///   --dart-define=API_BASE
  ///   --dart-define=API_PREFIX
  static void _ensureConfiguredSync() {
    if (_configured) return;

    final envBase = const String.fromEnvironment(
      'API_BASE',
      defaultValue: _defaultBase,
    );
    final envPrefix = const String.fromEnvironment(
      'API_PREFIX',
      defaultValue: _defaultApiPrefix,
    );

    configure(envBase, apiPrefix: envPrefix);
  }

  /// Configura a partir do AppConfig (se existir no contexto).
  ///
  /// Se não houver AppConfig, cai para os valores de env/default.
  static void configureFromContext(BuildContext? context) {
    final cfgBase = context != null
        ? AppConfig.maybeOf(context)?.params.baseApiUrl
        : null;

    if (cfgBase != null && cfgBase.isNotEmpty) {
      configure(cfgBase);
    } else {
      _ensureConfiguredSync();
    }
  }

  /// Compat: alguns pontos do app podem chamar `ApiRouter.fromContext(context)`
  /// só para garantir que o Router foi configurado. Aqui apenas chamamos
  /// `configureFromContext` e devolvemos uma instância vazia.
  static ApiRouter fromContext(BuildContext context) {
    configureFromContext(context);
    return ApiRouter();
  }

  // =====================================================================
  // Acesso à base / raiz da API
  // =====================================================================

  /// Host base atual (sem /api/v1), ex.: https://assistweb.ipasemnh.com.br
  static String get base {
    _ensureConfiguredSync();
    return _base;
  }

  /// Prefixo da API, ex.: /api/v1
  static String get apiPrefix {
    _ensureConfiguredSync();
    return _apiPrefix;
  }

  /// URI da raiz da API, ex.: https://host/api/v1
  static Uri get apiRootUri {
    _ensureConfiguredSync();
    final normalizedBase = _normalizeBase(_base);
    return Uri.parse('$normalizedBase$_apiPrefix');
  }

  /// Monta uma URI para um endpoint da API a partir de um caminho relativo.
  ///
  /// Exemplos:
  ///   ApiRouter.endpoint('system/ping')
  ///     -> https://host/api/v1/system/ping
  ///   ApiRouter.endpoint('/exame/historico')
  ///     -> https://host/api/v1/exame/historico
  static Uri endpoint(String path) {
    _ensureConfiguredSync();
    final root = apiRootUri;
    final cleaned = path.startsWith('/') ? path.substring(1) : path;
    return root.resolve(cleaned);
  }

  // =====================================================================
  // Endpoints de conveniência (opcionais)
  // =====================================================================

  /// GET api/v1/system/ping  -> api/SystemController::actionPing
  static Uri get systemPing => endpoint('system/ping');

  /// GET api/v1/system/time  -> api/SystemController::actionTime
  static Uri get systemTime => endpoint('system/time');

  /// POST api/v1/auth/login  -> (se você tiver AuthController separado)
  static Uri get authLogin => endpoint('auth/login');

  /// POST api/v1/dependente/login -> api/DependenteController::actionLogin
  static Uri get dependenteLogin => endpoint('dependente/login');

  /// POST api/v1/exame/historico -> api/ExameController::actionHistorico
  static Uri get exameHistorico => endpoint('exame/historico');

  /// POST api/v1/carteirinha/emitir -> api/CarteirinhaController::actionEmitir
  static Uri get carteirinhaEmitir => endpoint('carteirinha/emitir');

  /// POST api/v1/carteirinha/dados -> api/CarteirinhaController::actionDados
  static Uri get carteirinhaDados => endpoint('carteirinha/dados');

  // =====================================================================
  // Internos
  // =====================================================================

  static String _normalizeBase(String base) {
    var b = base.trim();
    while (b.endsWith('//')) {
      b = b.substring(0, b.length - 1);
    }
    if (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b;
  }
}
