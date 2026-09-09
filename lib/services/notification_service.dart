import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Inicializa flutter_local_notifications y el motor de zonas horarias
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // 1. Inicializar zonas horarias
      tz.initializeTimeZones();
      _configureLocalTimeZone();

      // 2. Configurar ajustes por plataforma
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final DarwinInitializationSettings darwinSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        onDidReceiveLocalNotification: (id, title, body, payload) async {
          debugPrint('Darwin did receive notification: $title - $body');
        },
      );

      final LinuxInitializationSettings linuxSettings =
          const LinuxInitializationSettings(
        defaultActionName: 'Abrir SayDo',
      );

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      // 3. Inicializar el plugin
      final initialized = await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notificación interactuada con payload: ${response.payload}');
        },
      );

      // 4. Solicitar permisos requeridos en Android 13+ e iOS
      await requestPermissions();

      _isInitialized = initialized ?? false;
      return _isInitialized;
    } catch (e) {
      debugPrint('Error al inicializar NotificationService: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Configura la zona horaria local intentando inferirla o usando fallback
  void _configureLocalTimeZone() {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      // Buscar una ubicación en el mapa de timezones que coincida con el offset
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == offset.inMilliseconds) {
          tz.setLocalLocation(location);
          return;
        }
      }
    } catch (e) {
      debugPrint('No se pudo mapear la zona horaria exacta: $e. Usando UTC por defecto.');
    }
  }

  /// Solicita permisos para mostrar notificaciones y programar alarmas exactas
  Future<void> requestPermissions() async {
    // Android
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }

    // iOS
    final iosImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // macOS
    final macImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
    if (macImpl != null) {
      await macImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Agenda una notificación con fecha y hora específicas
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Crear TZDateTime preservando el año, mes, día, hora y minuto en la zona horaria local
    final tz.TZDateTime scheduledTZ = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledDate.hour,
      scheduledDate.minute,
    );

    // Si la fecha ya pasó, no se puede programar en el pasado
    final tzNow = tz.TZDateTime.now(tz.local);
    final targetDate = scheduledTZ.isBefore(tzNow)
        ? tzNow.add(const Duration(seconds: 10))
        : scheduledTZ;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'saydo_reminders_channel',
      'Recordatorios SayDo',
      channelDescription: 'Notificaciones de tareas y alarmas de SayDo',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails darwinDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      targetDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    debugPrint('Notificación programada con ID: $id para $targetDate');
  }

  /// Muestra una notificación instantánea
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'saydo_instant_channel',
      'Avisos SayDo',
      channelDescription: 'Avisos inmediatos del sistema SayDo',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails darwinDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Cancela una notificación específica
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancela todas las notificaciones pendientes
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Retorna la lista de notificaciones pendientes
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }
}
