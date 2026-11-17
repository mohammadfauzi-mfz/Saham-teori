import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Fund {
  double? per, pbv, roe, der, dy, growth;
  Fund({this.per, this.pbv, this.roe, this.der, this.dy, this.growth});
  Map<String, dynamic> toJson() =>
      {'per': per, 'pbv': pbv, 'roe': roe, 'der': der, 'dy': dy, 'growth': growth};
  factory Fund.fromJson(Map<String, dynamic> j) {
    double? g(String k) => (j[k] as num?)?.toDouble();
    return Fund(
        per: g('per'), pbv: g('pbv'), roe: g('roe'), der: g('der'), dy: g('dy'), growth: g('growth'));
  }
}

class Holding {
  final String code;
  final int lots;
  final double avg;
  Holding(this.code, this.lots, this.avg);
  Map<String, dynamic> toJson() => {'code': code, 'lots': lots, 'avg': avg};
  factory Holding.fromJson(Map<String, dynamic> j) =>
      Holding(j['code'] as String, (j['lots'] as num).toInt(), (j['avg'] as num).toDouble());
}

class Alert {
  final String code;
  final double price;
  final bool above;
  Alert(this.code, this.price, this.above);
  Map<String, dynamic> toJson() => {'code': code, 'price': price, 'above': above};
  factory Alert.fromJson(Map<String, dynamic> j) =>
      Alert(j['code'] as String, (j['price'] as num).toDouble(), j['above'] as bool);
}

class Settings {
  static double swing = 0.05, stopAtr = 1.0, zoneAtr = 0.5, riskPct = 1.0, capital = 10000000;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    swing = p.getDouble('s_swing') ?? swing;
    stopAtr = p.getDouble('s_stop') ?? stopAtr;
    zoneAtr = p.getDouble('s_zone') ?? zoneAtr;
    riskPct = p.getDouble('s_risk') ?? riskPct;
    capital = p.getDouble('s_cap') ?? capital;
  }

  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('s_swing', swing);
    await p.setDouble('s_stop', stopAtr);
    await p.setDouble('s_zone', zoneAtr);
    await p.setDouble('s_risk', riskPct);
    await p.setDouble('s_cap', capital);
  }
}

class Store {
  static Future<List<String>> watch() async {
    final p = await SharedPreferences.getInstance();
    return List<String>.from(p.getStringList('watch') ?? <String>[]);
  }

  static Future<void> setWatch(List<String> l) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('watch', l);
  }

  static Future<Fund> fund(String code) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('fund_$code');
    if (s == null) return Fund();
    return Fund.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  static Future<void> setFund(String code, Fund f) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('fund_$code', jsonEncode(f.toJson()));
  }

  static Future<List<Holding>> holdings() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('holdings');
    if (s == null) return <Holding>[];
    return (jsonDecode(s) as List)
        .map((e) => Holding.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> setHoldings(List<Holding> l) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('holdings', jsonEncode(l.map((e) => e.toJson()).toList()));
  }

  static Future<List<Alert>> alerts() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('alerts');
    if (s == null) return <Alert>[];
    return (jsonDecode(s) as List)
        .map((e) => Alert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> setAlerts(List<Alert> l) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('alerts', jsonEncode(l.map((e) => e.toJson()).toList()));
  }

  // ---- Notifikasi target portofolio ----
  static Future<bool> notifOn() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p.getBool('n_on') ?? false;
  }

  static Future<double> notifTarget() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p.getDouble('n_target') ?? 10.0;
  }

  static Future<bool> notifFired() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p.getBool('n_fired') ?? false;
  }

  static Future<void> setNotif({bool? on, double? target, bool? fired}) async {
    final p = await SharedPreferences.getInstance();
    if (on != null) await p.setBool('n_on', on);
    if (target != null) await p.setDouble('n_target', target);
    if (fired != null) await p.setBool('n_fired', fired);
  }
}
