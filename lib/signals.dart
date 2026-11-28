import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';
import 'indicators.dart';
import 'smc.dart';
import 'store.dart';
import 'theories.dart';

/// Aturan notifikasi sinyal: kode saham/forex/Deriv + timeframe (+ opsi pemicu setup SMC).
class SigRule {
  final String code, iv;
  final bool smc;
  SigRule(this.code, this.iv, this.smc);
  String get key => '$code|$iv';
  Map<String, dynamic> toJson() => {'code': code, 'iv': iv, 'smc': smc};
  factory SigRule.fromJson(Map<String, dynamic> j) =>
      SigRule(j['code'] as String, j['iv'] as String, (j['smc'] as bool?) ?? false);
}

class SigResult {
  final String verdict; // BUY | SELL | NETRAL
  final int bull, total;
  final double price;
  final String smcKey, smcText;
  SigResult(this.verdict, this.bull, this.total, this.price, this.smcKey, this.smcText);
}

/// Hitung sinyal terkini untuk satu kode & timeframe (BUY jika >=60% teori hijau, SELL jika <=40%).
Future<SigResult> evalSignal(String code, String iv) async {
  final d = await fetchCandles(code, range: rangeFor(iv), interval: iv);
  if (d.length < 60) throw Exception('Data $code terlalu sedikit');
  final fx = isForex(code);
  priceDec = decFor(code);
  swingOverride = (fx || isIntraday(iv)) ? autoSwing(d) : 0;
  final s = analyze(d, Indicators(d), Fund(), forex: fx);
  swingOverride = 0;
  final bull = s.where((e) => e.ok).length;
  final r = s.isEmpty ? 0.5 : bull / s.length;
  final v = r >= 0.6 ? 'BUY' : (r <= 0.4 ? 'SELL' : 'NETRAL');
  var key = '', txt = '';
  final u = analyzeSmc(d)?.setup;
  if (u != null && u.inZone) {
    key = '${u.buy ? 'B' : 'S'}${u.lo.toStringAsFixed(priceDec)}';
    txt = 'Setup SMC ${u.buy ? 'BUY' : 'SELL'}: entry ${f0(u.entry)}, SL ${f0(u.sl)}, TP ${f0(u.tp1)}';
  }
  return SigResult(v, bull, s.length, d.last.c, key, txt);
}

final FlutterLocalNotificationsPlugin _np = FlutterLocalNotificationsPlugin();

class Signals {
  static Future<SharedPreferences> _p() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p;
  }

  static Future<bool> on() async => (await _p()).getBool('sg_on') ?? false;
  static Future<void> setOn(bool v) async => (await SharedPreferences.getInstance()).setBool('sg_on', v);

  static Future<List<SigRule>> rules() async {
    final s = (await _p()).getString('sg_rules');
    if (s == null) return [];
    return (jsonDecode(s) as List).map((e) => SigRule.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> setRules(List<SigRule> l) async =>
      (await SharedPreferences.getInstance()).setString('sg_rules', jsonEncode(l.map((e) => e.toJson()).toList()));

  /// Dipanggil AlarmManager (isolate latar belakang). Notifikasi hanya saat status BERUBAH ke BUY/SELL.
  static Future<void> backgroundCheck() async {
    if (!await on()) return;
    final rs = await rules();
    if (rs.isEmpty) return;
    await _np.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    final p = await SharedPreferences.getInstance();
    final state = Map<String, dynamic>.from(jsonDecode(p.getString('sg_state') ?? '{}') as Map);
    var id = 2000;
    for (final r in rs) {
      try {
        final x = await evalSignal(r.code, r.iv);
        final prev = state[r.key] as String?;
        final cur = x.verdict;
        if (prev != null && cur != prev && cur != 'NETRAL') {
          await _show(id++, r, '${r.code} ${tfLabel(r.iv)}: sinyal $cur ${cur == 'BUY' ? '🟢' : '🔴'}',
              'Harga ${x.price.toStringAsFixed(decFor(r.code))} • ${x.bull}/${x.total} teori hijau (sebelumnya $prev). Bukan rekomendasi.');
        }
        state[r.key] = cur;
        if (r.smc) {
          final sk = 'smc:${r.key}';
          final prevS = state[sk] as String? ?? '';
          if (x.smcKey.isNotEmpty && x.smcKey != prevS && state.containsKey(sk)) {
            await _show(id++, r, '${r.code} ${tfLabel(r.iv)}: harga masuk zona SMC', x.smcText);
          }
          state[sk] = x.smcKey;
        }
      } catch (_) {}
    }
    await p.setString('sg_state', jsonEncode(state));
  }

  static Future<void> _show(int id, SigRule r, String title, String body) => _np.show(
      id,
      title,
      body,
      const NotificationDetails(
          android: AndroidNotificationDetails('signals', 'Sinyal Buy/Sell',
              channelDescription: 'Pemberitahuan saat sinyal berubah',
              importance: Importance.high,
              priority: Priority.high)));
}
