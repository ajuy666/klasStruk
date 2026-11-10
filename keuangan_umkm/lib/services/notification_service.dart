import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(initializationSettings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
  }

  static Future<void> showExpenseLimitWarning({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'expense_limit_alerts',
      'Peringatan Batas Pengeluaran',
      channelDescription:
          'Notifikasi saat pengeluaran mendekati atau melewati batas.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      1001,
      title,
      body,
      details,
    );
  }

  static Future<void> showLowStockWarning({
    required String productName,
    required double stock,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'low_stock_alerts',
      'Peringatan Stok Menipis',
      channelDescription: 'Notifikasi saat stok produk tersisa 10 pcs atau kurang.',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      2001,
      'Stok menipis',
      '$productName tersisa ${stock.toStringAsFixed(0)} pcs.',
      const NotificationDetails(android: androidDetails),
    );
  }
}
