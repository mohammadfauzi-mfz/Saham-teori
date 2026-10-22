import 'dart:math' as math;
import 'data.dart';

final nan = double.nan;

List<double> sma(List<double> v, int n) {
  final r = List<double>.filled(v.length, nan);
  double s = 0;
  for (var i = 0; i < v.length; i++) {
    s += v[i];
    if (i >= n) s -= v[i - n];
    if (i >= n - 1) r[i] = s / n;
  }
  return r;
}

List<double> ema(List<double> v, int n) {
  final r = List<double>.filled(v.length, nan);
  final st = v.indexWhere((x) => !x.isNaN);
  if (st < 0 || v.length - st < n) return r;
  double s = 0;
  for (var i = st; i < st + n; i++) s += v[i];
  var e = s / n;
  r[st + n - 1] = e;
  final k = 2 / (n + 1);
  for (var i = st + n; i < v.length; i++) {
    e = v[i] * k + e * (1 - k);
    r[i] = e;
  }
  return r;
}

List<double> rsiCalc(List<double> c, int n) {
  final r = List<double>.filled(c.length, nan);
  if (c.length <= n) return r;
  double g = 0, l = 0;
  for (var i = 1; i <= n; i++) {
    final d = c[i] - c[i - 1];
    if (d > 0) {
      g += d;
    } else {
      l -= d;
    }
  }
  g /= n;
  l /= n;
  r[n] = l == 0 ? 100 : 100 - 100 / (1 + g / l);
  for (var i = n + 1; i < c.length; i++) {
    final d = c[i] - c[i - 1];
    g = (g * (n - 1) + (d > 0 ? d : 0)) / n;
    l = (l * (n - 1) + (d < 0 ? -d : 0)) / n;
    r[i] = l == 0 ? 100 : 100 - 100 / (1 + g / l);
  }
  return r;
}

class Indicators {
  final List<Candle> d;
  late final List<double> c, h, l, v;
  late final List<double> ma20, ma50, ma200;
  late final List<double> bbMid, bbUp, bbLow;
  late final List<double> rsi, macd, macdSig, macdHist, obv;
  late final List<double> atr, stochK, stochD, adx, pdi, mdi, psar, cci, mfi;

  Indicators(this.d) {
    c = d.map((e) => e.c).toList();
    h = d.map((e) => e.h).toList();
    l = d.map((e) => e.l).toList();
    v = d.map((e) => e.v).toList();
    final n = c.length;
    ma20 = sma(c, 20);
    ma50 = sma(c, 50);
    ma200 = sma(c, 200);
    bbMid = ma20;
    bbUp = List<double>.filled(n, nan);
    bbLow = List<double>.filled(n, nan);
    for (var i = 19; i < n; i++) {
      double s = 0;
      for (var j = i - 19; j <= i; j++) {
        s += (c[j] - bbMid[i]) * (c[j] - bbMid[i]);
      }
      final sd = math.sqrt(s / 20);
      bbUp[i] = bbMid[i] + 2 * sd;
      bbLow[i] = bbMid[i] - 2 * sd;
    }
    rsi = rsiCalc(c, 14);
    final e12 = ema(c, 12), e26 = ema(c, 26);
    macd = List<double>.generate(n, (i) => e12[i] - e26[i]);
    macdSig = ema(macd, 9);
    macdHist = List<double>.generate(n, (i) => macd[i] - macdSig[i]);
    obv = List<double>.filled(n, 0);
    for (var i = 1; i < n; i++) {
      obv[i] = obv[i - 1] + (c[i] > c[i - 1] ? v[i] : (c[i] < c[i - 1] ? -v[i] : 0));
    }

    // ATR, ADX/DI (Wilder)
    atr = List<double>.filled(n, nan);
    adx = List<double>.filled(n, nan);
    pdi = List<double>.filled(n, nan);
    mdi = List<double>.filled(n, nan);
    if (n > 40) {
      final tr = List<double>.filled(n, 0);
      final pdm = List<double>.filled(n, 0);
      final mdm = List<double>.filled(n, 0);
      for (var i = 1; i < n; i++) {
        tr[i] = math.max(h[i] - l[i],
            math.max((h[i] - c[i - 1]).abs(), (l[i] - c[i - 1]).abs()));
        final up = h[i] - h[i - 1];
        final dn = l[i - 1] - l[i];
        pdm[i] = (up > dn && up > 0) ? up : 0;
        mdm[i] = (dn > up && dn > 0) ? dn : 0;
      }
      var a = 0.0, str = 0.0, sp = 0.0, sm = 0.0;
      for (var i = 1; i <= 14; i++) {
        a += tr[i];
        str += tr[i];
        sp += pdm[i];
        sm += mdm[i];
      }
      atr[14] = a / 14;
      var at = a / 14;
      for (var i = 15; i < n; i++) {
        at = (at * 13 + tr[i]) / 14;
        atr[i] = at;
      }
      final dx = List<double>.filled(n, nan);
      void calc(int i) {
        pdi[i] = str == 0 ? 0 : 100 * sp / str;
        mdi[i] = str == 0 ? 0 : 100 * sm / str;
        final s = pdi[i] + mdi[i];
        dx[i] = s == 0 ? 0 : 100 * (pdi[i] - mdi[i]).abs() / s;
      }

      calc(14);
      for (var i = 15; i < n; i++) {
        str = str - str / 14 + tr[i];
        sp = sp - sp / 14 + pdm[i];
        sm = sm - sm / 14 + mdm[i];
        calc(i);
      }
      var ax = 0.0;
      for (var i = 14; i <= 27; i++) {
        ax += dx[i];
      }
      ax /= 14;
      adx[27] = ax;
      for (var i = 28; i < n; i++) {
        ax = (ax * 13 + dx[i]) / 14;
        adx[i] = ax;
      }
    }

    stochK = List<double>.filled(n, nan);
    stochD = List<double>.filled(n, nan);
    for (var i = 13; i < n; i++) {
      var hi = -double.infinity, lo = double.infinity;
      for (var j = i - 13; j <= i; j++) {
        hi = math.max(hi, h[j]);
        lo = math.min(lo, l[j]);
      }
      stochK[i] = hi == lo ? 50 : (c[i] - lo) / (hi - lo) * 100;
    }
    for (var i = 15; i < n; i++) {
      stochD[i] = (stochK[i] + stochK[i - 1] + stochK[i - 2]) / 3;
    }

    psar = List<double>.filled(n, nan);
    if (n > 5) {
      var up = c[1] >= c[0];
      var sar = up ? l[0] : h[0];
      var ep = up ? h[0] : l[0];
      var af = 0.02;
      psar[0] = sar;
      for (var i = 1; i < n; i++) {
        sar = sar + af * (ep - sar);
        final p1 = i >= 2 ? i - 2 : i - 1;
        if (up) {
          sar = math.min(sar, math.min(l[i - 1], l[p1]));
          if (l[i] < sar) {
            up = false;
            sar = ep;
            ep = l[i];
            af = 0.02;
          } else if (h[i] > ep) {
            ep = h[i];
            af = math.min(af + 0.02, 0.2);
          }
        } else {
          sar = math.max(sar, math.max(h[i - 1], h[p1]));
          if (h[i] > sar) {
            up = true;
            sar = ep;
            ep = h[i];
            af = 0.02;
          } else if (l[i] < ep) {
            ep = l[i];
            af = math.min(af + 0.02, 0.2);
          }
        }
        psar[i] = sar;
      }
    }

    cci = List<double>.filled(n, nan);
    final tp = List<double>.generate(n, (i) => (h[i] + l[i] + c[i]) / 3);
    for (var i = 19; i < n; i++) {
      var m = 0.0;
      for (var j = i - 19; j <= i; j++) {
        m += tp[j];
      }
      m /= 20;
      var md = 0.0;
      for (var j = i - 19; j <= i; j++) {
        md += (tp[j] - m).abs();
      }
      md /= 20;
      cci[i] = md == 0 ? 0 : (tp[i] - m) / (0.015 * md);
    }

    mfi = List<double>.filled(n, nan);
    for (var i = 14; i < n; i++) {
      var pos = 0.0, neg = 0.0;
      for (var j = i - 13; j <= i; j++) {
        final mf = tp[j] * v[j];
        if (tp[j] > tp[j - 1]) {
          pos += mf;
        } else if (tp[j] < tp[j - 1]) {
          neg += mf;
        }
      }
      mfi[i] = neg == 0 ? 100 : 100 - 100 / (1 + pos / neg);
    }
  }

  double _mid(int n, int i) {
    var hi = -double.infinity, lo = double.infinity;
    for (var j = i - n + 1; j <= i; j++) {
      hi = math.max(hi, h[j]);
      lo = math.min(lo, l[j]);
    }
    return (hi + lo) / 2;
  }

  /// Awan Ichimoku (Senkou A, Senkou B) pada indeks i, atau null.
  List<double>? cloud(int i) {
    final k = i - 26;
    if (k - 51 < 0) return null;
    return [(_mid(9, k) + _mid(26, k)) / 2, _mid(52, k)];
  }
}
