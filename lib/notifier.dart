import 'dart:ui';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'data.dart';
import 'store.dart';

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
const _alarmId = 7001;

/// Entry point dijalankan AlarmManager di latar belakang (aplikasi tidak perlu dibuka).
@pragma('vm:entry-point')
Future<void> backgroundTarget() async {
  DartPluginRegistrant.ensureInitialized();
  try {
    await Notifier.backgroundCheck();
  } catch (_) {}
}

class Notifier {
  static Future<void> _initPlugin() async {
    await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  }

  /// Dipanggil sekali saat aplikasi mulai.
  static Future<void> init() async {
    await _initPlugin();
    await AndroidAlarmManager.initialize();
    if (await Store.notifOn()) await schedule();
  }

  static Future<bool> requestPermission() async {
    final impl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return (await impl?.requestNotificationsPermission()) ?? true;
  }

  static Future<void> schedule() async {
    await AndroidAlarmManager.periodic(const Duration(minutes: 15), _alarmId, backgroundTarget,
        wakeup: true, rescheduleOnReboot: true);
  }

  static Future<void> cancel() async => AndroidAlarmManager.cancel(_alarmId);

  /// Aktif/nonaktifkan notifikasi + simpan target (% untung total portofolio).
  static Future<void> configure({required bool on, required double target}) async {
    await Store.setNotif(on: on, target: target, fired: false);
    if (on) {
      await requestPermission();
      await schedule();
    } else {
      await cancel();
    }
  }

  /// Dipanggil dengan P/L% portofolio saat ini. Notifikasi dikirim sekali saat target tercapai,
  /// dan di-reset ketika P/L kembali di bawah target.
  static Future<void> evaluate(double plPct) async {
    if (!await Store.notifOn()) return;
    final target = await Store.notifTarget();
    final fired = await Store.notifFired();
    if (plPct >= target) {
      if (!fired) {
        await _show(plPct, target);
        await Store.setNotif(fired: true);
      }
    } else if (fired) {
      await Store.setNotif(fired: false);
    }
  }

  static Future<void> _show(double pl, double target) async {
    await _plugin.show(
        1001,
        'Portofolio capai target 🎯',
        'Total untung ${pl.toStringAsFixed(2)}% (target ${target.toStringAsFixed(1)}%). Pertimbangkan ambil untung.',
        const NotificationDetails(
            android: AndroidNotificationDetails('portfolio_target', 'Target portofolio',
                channelDescription: 'Pemberitahuan saat portofolio melewati target',
                importance: Importance.high,
                priority: Priority.high)));
  }

  /// Dijalankan di isolate latar belakang: ambil harga terakhir tiap posisi, hitung P/L total.
  static Future<void> backgroundCheck() async {
    if (!await Store.notifOn()) return;
    await _initPlugin();
    final hs = await Store.holdings();
    if (hs.isEmpty) return;
    var cost = 0.0, value = 0.0;
    for (final h in hs) {
      final c = await fetchCandles(h.code, range: '5d', interval: '1d');
      if (c.isEmpty) return;
      cost += h.lots * 100 * h.avg;
      value += h.lots * 100 * c.last.c;
    }
    if (cost <= 0) return;
    await evaluate((value - cost) / cost * 100);
  }
}
