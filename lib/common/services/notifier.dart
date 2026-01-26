// lib/services/notifier.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Serviço único para notificações locais.
class AppNotifier {
  AppNotifier._();
  static final AppNotifier I = AppNotifier._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Canal padrão (Android) — uso geral
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'app_default_channel',
    'Notificações',
    description: 'Alertas do aplicativo',
    importance: Importance.high,
    playSound: true,
  );

  // Canal de status de exames (Android) — mudanças A/I/etc
  static const AndroidNotificationChannel _exameChannel =
  AndroidNotificationChannel(
    'exames_status',
    'Status de Exames',
    description: 'Mudanças de status das autorizações',
    importance: Importance.high,
    playSound: true,
  );

  /// Inicializa o plugin e garante permissão (Android 13+/iOS/macOS).
  Future<void> init() async {
    if (_initialized) return;

    // 1) Pede permissão de forma cross-platform
    await _ensurePermission();

    // 2) Inicialização por plataforma
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        // TODO: tratar clique (payload) se quiser (ex.: abrir detalhes do exame)
        // r.payload => 'exame:<numero>'
      },
    );

    // 3) Cria canais no Android
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);
    await androidImpl?.createNotificationChannel(_exameChannel);

    _initialized = true;
  }

  /// Solicita/garante permissão usando `permission_handler`.
  Future<void> _ensurePermission() async {
    if (kIsWeb) return; // web não usa este serviço

    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  /// Notificação simples (heads-up no Android) no canal padrão.
  Future<void> showSimple({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    if (!_initialized) await init();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/launcher_icon',
      ),
      iOS: const DarwinNotificationDetails(presentSound: true),
      macOS: const DarwinNotificationDetails(presentSound: true),
    );

    final notifId =
        id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _plugin.show(notifId, title, body, details, payload: payload);
  }

  // ====== Helpers para “não empilhar” por autorização ======

  // ID estável por exame (substitui a notificação do mesmo exame)
  int _notifIdForExam(int numero) => 200000 + (numero % 100000);

  static const _groupKeyExames = 'exames_status_group';

  NotificationDetails _exameDetails({required String bigText}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _exameChannel.id,
        _exameChannel.name,
        channelDescription: _exameChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/launcher_icon',
        groupKey: _groupKeyExames, // agrupa notificações de exames
        category: AndroidNotificationCategory.status,
        styleInformation: BigTextStyleInformation(bigText),
      ),
      iOS: const DarwinNotificationDetails(
        presentSound: true,
        // agrupa na Central de Notificações do iOS
        threadIdentifier: _groupKeyExames,
      ),
      macOS: const DarwinNotificationDetails(
        presentSound: true,
        threadIdentifier: _groupKeyExames,
      ),
    );
  }

  /// Azulejo pronto para “exame liberado”.
  Future<void> notifyExameLiberado({
    required int numero,
    String? paciente,
    String? prestador,
  }) async {
    if (!_initialized) await init();

    final parts = <String>[
      'Autorização #$numero liberada.',
      if ((paciente ?? '').isNotEmpty) '• $paciente',
      if ((prestador ?? '').isNotEmpty) '• $prestador',
    ];
    final body = parts.join(' ');

    await _plugin.show(
      _notifIdForExam(numero),
      'Autorização liberada',
      body,
      _exameDetails(bigText: body),
      payload: 'exame:$numero',
    );
  }

  /// Azulejo para “exame negado”.
  Future<void> notifyExameNegado({
    required int numero,
    String? paciente,
    String? prestador,
  }) async {
    if (!_initialized) await init();

    final parts = <String>[
      'Autorização #$numero foi negada.',
      if ((paciente ?? '').isNotEmpty) '• $paciente',
      if ((prestador ?? '').isNotEmpty) '• $prestador',
    ];
    final body = parts.join(' ');

    await _plugin.show(
      _notifIdForExam(numero),
      'Autorização negada',
      body,
      _exameDetails(bigText: body),
      payload: 'exame:$numero',
    );
  }
}
