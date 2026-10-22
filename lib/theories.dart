import 'dart:math' as math;
import 'data.dart';
import 'indicators.dart';
import 'store.dart';

class Signal {
  final String name;
  final bool ok;
  final String note;
  final bool fund;
  Signal(this.name, this.ok, this.note, [this.fund = false]);
}

class Pivot {
  final int i;
  final double p;
  final bool high;
  Pivot(this.i, this.p, this.high);
}

String f0(double v) => v.toStringAsFixed(0);

String rp(double v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

List<Pivot> zigzag(List<double> c, double th) {
  final p = <Pivot>[];
  var ei = 0;
  var dir = 0;
  for (var i = 1; i < c.length; i++) {
    if (dir == 0) {
      if (c[i] > c[0] * (1 + th)) {
        p.add(Pivot(0, c[0], false));
        dir = 1;
        ei = i;
      } else if (c[i] < c[0] * (1 - th)) {
        p.add(Pivot(0, c[0], true));
        dir = -1;
        ei = i;
      }
    } else if (dir == 1) {
      if (c[i] > c[ei]) {
        ei = i;
      } else if (c[i] < c[ei] * (1 - th)) {
        p.add(Pivot(ei, c[ei], true));
        dir = -1;
        ei = i;
      }
    } else {
      if (c[i] < c[ei]) {
        ei = i;
      } else if (c[i] > c[ei] * (1 + th)) {
        p.add(Pivot(ei, c[ei], false));
        dir = 1;
        ei = i;
      }
    }
  }
  if (dir != 0) p.add(Pivot(ei, c[ei], dir == 1));
  return p;
}

List<double> srLevels(Indicators x) {
  final piv = zigzag(x.c, Settings.swing);
  final hs = piv.where((e) => e.high).toList().reversed.take(3).map((e) => e.p);
  final ls = piv.where((e) => !e.high).toList().reversed.take(3).map((e) => e.p);
  return [...hs, ...ls];
}

List<Signal> analyze(List<Candle> d, Indicators x, Fund f, {List<Candle>? idx}) {
  final piv = zigzag(x.c, Settings.swing);
  return [
    _dow(piv),
    _elliott(piv),
    _fib(piv, x),
    _wyckoff(x),
    _candle(d, x),
    _doubleBottom(piv, x),
    _invHS(piv, x),
    _golden(x),
    _ichimoku(x),
    _rsi(x),
    _macd(x),
    _stoch(x),
    _bb(x),
    _adx(x),
    _volume(x),
    _breakout(x),
    _psar(x),
    _cci(x),
    _mfi(x),
    _triangle(piv, x),
    _rs(x, idx),
    ...fundSignals(f),
  ];
}

List<Signal> fundSignals(Fund f) {
  final r = <Signal>[];
  final per = f.per, pbv = f.pbv, roe = f.roe, der = f.der, dy = f.dy, g = f.growth;
  if (per != null) {
    r.add(Signal('PER', per > 0 && per < 15,
        'PER ${per.toStringAsFixed(1)} (acuan: 0–15 relatif murah; bandingkan dengan rata-rata sektor).', true));
  }
  if (pbv != null) {
    r.add(Signal('PBV', pbv > 0 && pbv < 2,
        'PBV ${pbv.toStringAsFixed(2)} (acuan: <2; bank besar bisa wajar lebih tinggi).', true));
  }
  if (roe != null) {
    r.add(Signal('ROE', roe >= 10, 'ROE ${roe.toStringAsFixed(1)}% (acuan: ≥10%).', true));
  }
  if (der != null) {
    r.add(Signal('DER', der < 1, 'DER ${der.toStringAsFixed(2)}x (acuan: <1x; bank/finansial berbeda).', true));
  }
  if (dy != null) {
    r.add(Signal('Dividen', dy >= 2, 'Dividend yield ${dy.toStringAsFixed(1)}% (acuan: ≥2%).', true));
  }
  if (g != null) {
    r.add(Signal('Pertumbuhan Laba', g > 0, 'Pertumbuhan laba ${g.toStringAsFixed(1)}% (acuan: >0%).', true));
  }
  return r;
}

Signal _dow(List<Pivot> p) {
  const nm = 'Dow Theory';
  final hs = p.where((e) => e.high).toList();
  final ls = p.where((e) => !e.high).toList();
  if (hs.length < 2 || ls.length < 2) {
    return Signal(nm, false, 'Pivot belum cukup untuk menilai tren.');
  }
  final hh = hs.last.p > hs[hs.length - 2].p;
  final hl = ls.last.p > ls[ls.length - 2].p;
  return Signal(
      nm,
      hh && hl,
      hh && hl
          ? 'Uptrend: higher high dan higher low terbentuk.'
          : 'Higher high: ${hh ? 'ya' : 'tidak'}, higher low: ${hl ? 'ya' : 'tidak'}. Uptrend belum terkonfirmasi.');
}

Signal _elliott(List<Pivot> piv) {
  const nm = 'Elliott Wave';
  var ps = piv;
  if (ps.isNotEmpty && ps.last.high) ps = ps.sublist(0, ps.length - 1);
  if (ps.length < 5) return Signal(nm, false, 'Swing belum cukup untuk pola 5 gelombang.');
  final w = ps.sublist(ps.length - 5);
  if (w[0].high) return Signal(nm, false, 'Urutan swing tidak diawali dari dasar.');
  final w1 = w[1].p - w[0].p;
  final w3 = w[3].p - w[2].p;
  final ok = w[2].p > w[0].p && w[3].p > w[1].p && w[4].p > w[1].p && w3 > w1;
  return Signal(
      nm,
      ok,
      ok
          ? 'Gelombang 1-4 terpenuhi (gel.2 tidak di bawah awal, gel.3 lebih panjang dari gel.1, gel.4 tidak overlap gel.1). Potensi gelombang 5. (Heuristik)'
          : 'Aturan impuls Elliott tidak terpenuhi pada swing terakhir. (Heuristik)');
}

Signal _fib(List<Pivot> p, Indicators x) {
  const nm = 'Fibonacci Retracement';
  for (var k = p.length - 1; k >= 1; k--) {
    if (p[k].high && !p[k - 1].high) {
      final lo = p[k - 1].p, hi = p[k].p;
      final price = x.c.last;
      final r = (hi - price) / (hi - lo);
      final up = price > x.c[x.c.length - 2];
      final ok = r >= 0.382 && r <= 0.618 && up;
      return Signal(
          nm,
          ok,
          'Swing ${f0(lo)} → ${f0(hi)}; harga di retracement ${(r * 100).toStringAsFixed(1)}%. ' +
              (ok ? 'Di zona 38,2–61,8% dan mulai memantul.' : 'Di luar zona 38,2–61,8% atau belum memantul.'));
    }
  }
  return Signal(nm, false, 'Swing naik belum ditemukan.');
}

Signal _wyckoff(Indicators x) {
  const nm = 'Wyckoff (Akumulasi)';
  final n = x.c.length;
  const m = 40;
  if (n < m + 21) return Signal(nm, false, 'Data kurang.');
  var hi = -double.infinity, lo = double.infinity;
  for (var i = n - m; i < n; i++) {
    hi = math.max(hi, x.h[i]);
    lo = math.min(lo, x.l[i]);
  }
  final range = (hi - lo) / lo;
  final obvUp = x.obv.last > x.obv[n - 21];
  final ok = range < 0.15 && obvUp;
  return Signal(
      nm,
      ok,
      'Rentang harga 40 candle ${(range * 100).toStringAsFixed(1)}% (syarat <15%), OBV ${obvUp ? 'naik' : 'turun'}. ' +
          (ok ? 'Indikasi fase akumulasi.' : 'Belum menunjukkan akumulasi.'));
}

// ignore: unused_element
Signal _candleOld(List<Candle> d, Indicators x) {
  const nm = 'Candlestick Bullish';
  final n = d.length;
  final a = d[n - 2], b = d[n - 1];
  final engulf = a.c < a.o && b.c > b.o && b.c >= a.o && b.o <= a.c;
  final body = (b.c - b.o).abs();
  final rng = b.h - b.l;
  final lowSh = math.min(b.o, b.c) - b.l;
  final upSh = b.h - math.max(b.o, b.c);
  final down = !x.ma20[n - 1].isNaN && b.c < x.ma20[n - 1];
  final hammer = rng > 0 && lowSh >= 2 * body && upSh <= body && lowSh >= rng * 0.5 && down;
  return Signal(
      nm,
      engulf || hammer,
      engulf
          ? 'Bullish Engulfing pada candle terakhir.'
          : hammer
              ? 'Hammer setelah tekanan turun pada candle terakhir.'
              : 'Tidak ada Bullish Engulfing/Hammer di candle terakhir.');
}

Signal _doubleBottom(List<Pivot> p, Indicators x) {
  const nm = 'Double Bottom';
  final ls = p.where((e) => !e.high).toList();
  if (ls.length < 2) return Signal(nm, false, 'Dasar belum cukup.');
  final a = ls[ls.length - 2], b = ls.last;
  if ((a.p - b.p).abs() / a.p >= 0.03) {
    return Signal(nm, false, 'Dua dasar terakhir berbeda >3%.');
  }
  final mid = p.where((e) => e.high && e.i > a.i && e.i < b.i).toList();
  if (mid.isEmpty) return Signal(nm, false, 'Neckline tidak ditemukan.');
  final neck = mid.map((e) => e.p).reduce(math.max);
  final ok = x.c.last > neck;
  return Signal(nm, ok,
      'Dasar ${f0(a.p)} & ${f0(b.p)}, neckline ${f0(neck)}. ' + (ok ? 'Harga menembus neckline.' : 'Harga belum menembus neckline.'));
}

Signal _invHS(List<Pivot> p, Indicators x) {
  const nm = 'Inverse Head & Shoulders';
  final ls = p.where((e) => !e.high).toList();
  if (ls.length < 3) return Signal(nm, false, 'Dasar belum cukup.');
  final a = ls[ls.length - 3], hd = ls[ls.length - 2], b = ls.last;
  if (!(hd.p < a.p && hd.p < b.p)) return Signal(nm, false, 'Dasar tengah (head) bukan yang terendah.');
  if ((a.p - b.p).abs() / a.p > 0.06) return Signal(nm, false, 'Dua bahu berbeda >6%.');
  final hs = p.where((e) => e.high && e.i > a.i && e.i < b.i).toList();
  if (hs.length < 2) return Signal(nm, false, 'Neckline tidak ditemukan.');
  final neck = hs.map((e) => e.p).reduce((u, v) => u + v) / hs.length;
  final ok = x.c.last > neck;
  return Signal(nm, ok,
      'Bahu ${f0(a.p)}/${f0(b.p)}, head ${f0(hd.p)}, neckline ${f0(neck)}. ' + (ok ? 'Harga menembus neckline.' : 'Belum menembus neckline.'));
}

Signal _golden(Indicators x) {
  const nm = 'Golden Cross';
  final a = x.ma50.last, b = x.ma200.last;
  if (a.isNaN || b.isNaN) return Signal(nm, false, 'Data kurang dari 200 candle.');
  final ok = a > b;
  return Signal(nm, ok,
      'MA50 ${f0(a)} ${ok ? '>' : '<'} MA200 ${f0(b)}. ' + (ok ? 'Golden Cross aktif.' : 'Death Cross / belum Golden Cross.'));
}

Signal _ichimoku(Indicators x) {
  const nm = 'Ichimoku Cloud';
  final cl = x.cloud(x.c.length - 1);
  if (cl == null) return Signal(nm, false, 'Data kurang.');
  final top = math.max(cl[0], cl[1]);
  final ok = x.c.last > top;
  return Signal(nm, ok, 'Harga ${f0(x.c.last)} ${ok ? 'di atas' : 'tidak di atas'} awan (batas atas ${f0(top)}).');
}

Signal _rsi(Indicators x) {
  const nm = 'RSI';
  final n = x.rsi.length;
  final r = x.rsi[n - 1], pr = x.rsi[n - 2];
  if (r.isNaN || pr.isNaN) return Signal(nm, false, 'Data kurang.');
  final ok = (r > 50 && r < 70) || (pr < 30 && r > pr);
  return Signal(nm, ok,
      'RSI ${r.toStringAsFixed(1)}. ' +
          (ok ? 'Momentum bullish (50–70 atau pantulan dari oversold).' : r >= 70 ? 'Overbought (≥70).' : 'Momentum lemah.'));
}

Signal _macd(Indicators x) {
  const nm = 'MACD';
  final n = x.macd.length;
  final m = x.macd[n - 1], s = x.macdSig[n - 1];
  if (m.isNaN || s.isNaN) return Signal(nm, false, 'Data kurang.');
  final rising = x.macdHist[n - 1] > x.macdHist[n - 2];
  return Signal(nm, m > s && rising,
      'MACD ${m.toStringAsFixed(2)} ${m > s ? '>' : '<'} sinyal ${s.toStringAsFixed(2)}, histogram ${rising ? 'menguat' : 'melemah'}.');
}

Signal _stoch(Indicators x) {
  const nm = 'Stochastic';
  final n = x.c.length;
  final k = x.stochK[n - 1], dd = x.stochD[n - 1];
  if (k.isNaN || dd.isNaN) return Signal(nm, false, 'Data kurang.');
  final ok = k > dd && k < 80;
  return Signal(nm, ok,
      '%K ${k.toStringAsFixed(1)} ${k > dd ? '>' : '<'} %D ${dd.toStringAsFixed(1)}. ' +
          (ok ? 'Momentum naik dan belum overbought.' : k >= 80 ? 'Zona overbought (≥80).' : 'Momentum belum naik.'));
}

Signal _bb(Indicators x) {
  const nm = 'Bollinger Bands';
  final n = x.c.length;
  final mid = x.bbMid[n - 1], up = x.bbUp[n - 1];
  if (mid.isNaN) return Signal(nm, false, 'Data kurang.');
  final c = x.c[n - 1];
  final ok = c > mid && c < up;
  return Signal(nm, ok,
      ok ? 'Harga di atas middle band dan belum menembus upper band.' : c >= up ? 'Harga menembus upper band (rawan jenuh beli).' : 'Harga di bawah middle band.');
}

Signal _adx(Indicators x) {
  const nm = 'ADX / DI';
  final n = x.c.length;
  final a = x.adx[n - 1], p = x.pdi[n - 1], m = x.mdi[n - 1];
  if (a.isNaN) return Signal(nm, false, 'Data kurang.');
  final ok = a > 20 && p > m;
  return Signal(nm, ok,
      'ADX ${a.toStringAsFixed(1)}, +DI ${p.toStringAsFixed(1)}, −DI ${m.toStringAsFixed(1)}. ' +
          (ok ? 'Tren naik dengan kekuatan memadai (ADX>20).' : a <= 20 ? 'Tren lemah/sideways (ADX≤20).' : 'Tekanan jual lebih dominan.'));
}

Signal _volume(Indicators x) {
  const nm = 'Konfirmasi Volume';
  final n = x.c.length;
  if (n < 22) return Signal(nm, false, 'Data kurang.');
  var s = 0.0;
  for (var i = n - 21; i < n - 1; i++) {
    s += x.v[i];
  }
  final avg = s / 20;
  final ratio = avg == 0 ? 0 : x.v[n - 1] / avg;
  final up = x.c[n - 1] > x.c[n - 2];
  final ok = ratio >= 1.2 && up;
  return Signal(nm, ok,
      'Volume terakhir ${ratio.toStringAsFixed(2)}x rata-rata 20 candle, harga ${up ? 'naik' : 'turun'}. ' +
          (ok ? 'Kenaikan didukung volume.' : 'Belum ada konfirmasi volume untuk kenaikan.'));
}

Signal _breakout(Indicators x) {
  const nm = 'Breakout Resistance';
  final n = x.c.length;
  if (n < 22) return Signal(nm, false, 'Data kurang.');
  var hi = -double.infinity;
  for (var i = n - 21; i < n - 1; i++) {
    hi = math.max(hi, x.h[i]);
  }
  final ok = x.c[n - 1] > hi;
  return Signal(nm, ok, 'High 20 candle sebelumnya ${f0(hi)}. ' + (ok ? 'Harga menutup di atasnya (breakout).' : 'Belum breakout.'));
}

class Reco {
  final double price, buyLow, buyHigh, ideal, stop, t1, t2, rr;
  final int score, total, techScore, techTotal, fundScore, fundTotal;
  final String verdict;
  final List<String> supports;
  Reco(
      {required this.price,
      required this.buyLow,
      required this.buyHigh,
      required this.ideal,
      required this.stop,
      required this.t1,
      required this.t2,
      required this.rr,
      required this.score,
      required this.total,
      required this.techScore,
      required this.techTotal,
      required this.fundScore,
      required this.fundTotal,
      required this.verdict,
      required this.supports});
  double get ratio => total == 0 ? 0 : score / total;
  bool get inZone => price >= buyLow && price <= buyHigh;
}

/// Harga beli ideal = konfluensi support (MA, Bollinger, Fibonacci, swing low, Ichimoku)
/// di bawah harga sekarang. Stop berbasis ATR, target dari swing high.
Reco recommend(List<Candle> d, Indicators x, List<Signal> sigs) {
  final n = x.c.length;
  final price = x.c.last;
  var atr = x.atr[n - 1];
  if (atr.isNaN) atr = price * 0.02;
  final piv = zigzag(x.c, Settings.swing);
  final lv = <MapEntry<String, double>>[];
  void add(String name, double v) {
    if (!v.isNaN && v < price && v > price * 0.8) lv.add(MapEntry(name, v));
  }

  add('MA20', x.ma20[n - 1]);
  add('MA50', x.ma50[n - 1]);
  add('MA200', x.ma200[n - 1]);
  add('Bollinger bawah', x.bbLow[n - 1]);
  add('Bollinger tengah', x.bbMid[n - 1]);
  final cl = x.cloud(n - 1);
  if (cl != null) add('Atas awan Ichimoku', math.max(cl[0], cl[1]));
  for (var k = piv.length - 1; k >= 1; k--) {
    if (piv[k].high && !piv[k - 1].high) {
      final lo = piv[k - 1].p, hi = piv[k].p;
      add('Fib 38,2%', hi - (hi - lo) * 0.382);
      add('Fib 50%', hi - (hi - lo) * 0.5);
      add('Fib 61,8%', hi - (hi - lo) * 0.618);
      break;
    }
  }
  for (final p in piv.where((e) => !e.high).toList().reversed.take(2)) {
    add('Swing low', p.p);
  }

  double ideal;
  var names = <String>[];
  if (lv.isEmpty) {
    ideal = price - atr;
  } else {
    var best = lv.first;
    var bestN = -1;
    for (final a in lv) {
      final cnt = lv.where((b) => (b.value - a.value).abs() <= 0.75 * atr).length;
      if (cnt > bestN || (cnt == bestN && a.value > best.value)) {
        best = a;
        bestN = cnt;
      }
    }
    final grp = lv.where((b) => (b.value - best.value).abs() <= 0.75 * atr).toList();
    ideal = grp.map((e) => e.value).reduce((a, b) => a + b) / grp.length;
    names = grp.map((e) => e.key).toList();
  }
  final buyLow = ideal - Settings.zoneAtr * atr;
  final buyHigh = math.min(ideal + Settings.zoneAtr * atr, price);
  final stop = buyLow - Settings.stopAtr * atr;
  final r = ideal - stop;
  final highs = piv.where((e) => e.high && e.p > ideal + r).map((e) => e.p).toList()..sort();
  final t1 = highs.isNotEmpty ? highs.first : ideal + 2 * r;
  final t2 = math.max(highs.isNotEmpty ? highs.last : 0.0, ideal + 3 * r);
  final tech = sigs.where((s) => !s.fund).toList();
  final fund = sigs.where((s) => s.fund).toList();
  final score = sigs.where((s) => s.ok).length;
  final ratio = sigs.isEmpty ? 0.0 : score / sigs.length;
  final verdict = ratio >= 0.6
      ? 'Cenderung bullish: beli bertahap di zona beli.'
      : ratio >= 0.35
          ? 'Netral: tunggu konfirmasi, beli hanya jika harga di zona beli.'
          : 'Lemah: sebaiknya tunggu sinyal membaik.';
  return Reco(
      price: price,
      buyLow: buyLow,
      buyHigh: buyHigh,
      ideal: ideal,
      stop: stop,
      t1: t1,
      t2: t2,
      rr: (t1 - ideal) / r,
      score: score,
      total: sigs.length,
      techScore: tech.where((s) => s.ok).length,
      techTotal: tech.length,
      fundScore: fund.where((s) => s.ok).length,
      fundTotal: fund.length,
      verdict: verdict,
      supports: names);
}

Signal _candle(List<Candle> d, Indicators x) {
  const nm = 'Candlestick Bullish';
  final n = d.length;
  final a = d[n - 2], b = d[n - 1];
  final engulf = a.c < a.o && b.c > b.o && b.c >= a.o && b.o <= a.c;
  final body = (b.c - b.o).abs();
  final rng = b.h - b.l;
  final lowSh = math.min(b.o, b.c) - b.l;
  final upSh = b.h - math.max(b.o, b.c);
  final down = !x.ma20[n - 1].isNaN && b.c < x.ma20[n - 1];
  final hammer = rng > 0 && lowSh >= 2 * body && upSh <= body && lowSh >= rng * 0.5 && down;
  var morning = false, soldiers = false;
  if (n >= 3) {
    final z = d[n - 3];
    final zr = z.h - z.l;
    final bb = (a.c - a.o).abs();
    final ar = a.h - a.l;
    morning = zr > 0 &&
        (z.o - z.c) > 0.5 * zr &&
        ar > 0 &&
        bb < 0.3 * ar &&
        b.c > b.o &&
        b.c > (z.o + z.c) / 2;
    soldiers = z.c > z.o &&
        a.c > a.o &&
        b.c > b.o &&
        a.c > z.c &&
        b.c > a.c &&
        a.o > z.o &&
        b.o > a.o &&
        a.o < z.c &&
        b.o < a.c;
  }
  final ok = engulf || hammer || morning || soldiers;
  return Signal(
      nm,
      ok,
      engulf
          ? 'Bullish Engulfing pada candle terakhir.'
          : hammer
              ? 'Hammer setelah tekanan turun pada candle terakhir.'
              : morning
                  ? 'Morning Star (3 candle) pada candle terakhir.'
                  : soldiers
                      ? 'Three White Soldiers (3 candle naik berurutan).'
                      : 'Tidak ada Engulfing/Hammer/Morning Star/Three White Soldiers.');
}

Signal _psar(Indicators x) {
  const nm = 'Parabolic SAR';
  final s = x.psar.last;
  if (s.isNaN) return Signal(nm, false, 'Data kurang.');
  final ok = x.c.last > s;
  return Signal(nm, ok, 'SAR ${f0(s)} ${ok ? 'di bawah' : 'di atas'} harga. ' + (ok ? 'Tren naik.' : 'Tren turun.'));
}

Signal _cci(Indicators x) {
  const nm = 'CCI';
  final n = x.cci.length;
  final v = x.cci[n - 1], p = x.cci[n - 2];
  if (v.isNaN || p.isNaN) return Signal(nm, false, 'Data kurang.');
  final ok = (v > 0 && v > p && v < 200) || (p < -100 && v > p);
  return Signal(nm, ok,
      'CCI ${v.toStringAsFixed(0)}. ' + (ok ? 'Momentum naik (di atas 0 dan menguat, atau pantulan dari -100).' : v >= 200 ? 'Terlalu panas (≥200).' : 'Momentum belum naik.'));
}

Signal _mfi(Indicators x) {
  const nm = 'MFI (Money Flow)';
  final n = x.mfi.length;
  final v = x.mfi[n - 1], p = x.mfi[n - 2];
  if (v.isNaN || p.isNaN) return Signal(nm, false, 'Data kurang.');
  final ok = (v > 50 && v < 80) || (p < 20 && v > p);
  return Signal(nm, ok,
      'MFI ${v.toStringAsFixed(1)}. ' + (ok ? 'Aliran dana masuk (50–80 atau pantulan dari <20).' : v >= 80 ? 'Jenuh beli (≥80).' : 'Aliran dana lemah.'));
}

Signal _triangle(List<Pivot> p, Indicators x) {
  const nm = 'Ascending Triangle';
  final hs = p.where((e) => e.high).toList();
  final ls = p.where((e) => !e.high).toList();
  if (hs.length < 2 || ls.length < 2) return Signal(nm, false, 'Pivot belum cukup.');
  final h1 = hs[hs.length - 2].p, h2 = hs.last.p;
  final flat = (h1 - h2).abs() / h1 < 0.015;
  final rising = ls.last.p > ls[ls.length - 2].p;
  final res = math.max(h1, h2);
  final near = x.c.last >= res * 0.97;
  final ok = flat && rising && near;
  return Signal(nm, ok,
      'Resistance datar: ${flat ? 'ya' : 'tidak'}, dasar naik: ${rising ? 'ya' : 'tidak'}, harga dekat/di atas resistance ${f0(res)}: ${near ? 'ya' : 'tidak'}.');
}

Signal _rs(Indicators x, List<Candle>? idx) {
  const nm = 'Relative Strength vs IHSG';
  if (idx == null || idx.length < 61) return Signal(nm, false, 'Data IHSG tidak tersedia.');
  final n = x.c.length;
  if (n < 61) return Signal(nm, false, 'Data kurang.');
  final s = x.c[n - 1] / x.c[n - 61] - 1;
  final m = idx[idx.length - 1].c / idx[idx.length - 61].c - 1;
  final ok = s > m;
  return Signal(nm, ok,
      'Return 60 candle: saham ${(s * 100).toStringAsFixed(1)}% vs IHSG ${(m * 100).toStringAsFixed(1)}%. ' +
          (ok ? 'Lebih kuat dari IHSG.' : 'Lebih lemah dari IHSG.'));
}
