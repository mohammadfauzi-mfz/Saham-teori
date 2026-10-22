import 'dart:math' as math;
import 'data.dart';
import 'indicators.dart';
import 'store.dart';
import 'theories.dart';

class BtResult {
  int trades = 0, wins = 0;
  double total = 0, bh = 0, maxDd = 0;
  List<String> log = [];
  String note = '';
}

/// Aturan: beli (open candle berikutnya) saat >=60% teori teknikal hijau;
/// jual saat <35%, stop 2 ATR, target 3 ATR, maksimal 40 candle. Fee 0,4% pulang-pergi.
Future<BtResult> backtestAsync(List<Candle> d) async {
  final r = BtResult();
  final n = d.length;
  const start = 100;
  if (n < start + 30) {
    r.note = 'Data terlalu sedikit untuk backtest.';
    return r;
  }
  var inPos = false;
  double entry = 0, stop = 0, target = 0;
  var ei = 0;
  var eq = 1.0, peak = 1.0;
  const fee = 0.004;

  void close(int i, double px, String why) {
    final ret = px / entry - 1 - fee;
    eq *= 1 + ret;
    peak = math.max(peak, eq);
    r.maxDd = math.max(r.maxDd, (peak - eq) / peak * 100);
    r.trades++;
    if (ret > 0) r.wins++;
    r.log.add(
        '${fd(d[ei].t)} beli ${f0(entry)} → ${fd(d[i].t)} jual ${f0(px)}  ${(ret * 100).toStringAsFixed(1)}% ($why)');
    inPos = false;
  }

  for (var i = start; i < n; i++) {
    if (i % 10 == 0) await Future.delayed(Duration.zero);
    final sub = d.sublist(0, i + 1);
    final x = Indicators(sub);
    final sigs = analyze(sub, x, Fund()).where((s) => !s.name.startsWith('Relative')).toList();
    final ratio = sigs.where((s) => s.ok).length / sigs.length;
    if (inPos) {
      if (d[i].l <= stop) {
        close(i, math.min(stop, d[i].o), 'stop');
      } else if (d[i].h >= target) {
        close(i, math.max(target, d[i].o), 'target');
      } else if (ratio < 0.35) {
        close(i, d[i].c, 'skor turun');
      } else if (i - ei >= 40) {
        close(i, d[i].c, 'batas waktu');
      }
    } else if (ratio >= 0.6 && i + 1 < n) {
      final a = x.atr[i];
      if (a.isNaN) continue;
      entry = d[i + 1].o;
      stop = entry - 2 * a;
      target = entry + 3 * a;
      ei = i + 1;
      inPos = true;
    }
  }
  if (inPos) close(n - 1, d[n - 1].c, 'akhir data');
  r.total = (eq - 1) * 100;
  r.bh = (d.last.c / d[start].c - 1) * 100;
  return r;
}
