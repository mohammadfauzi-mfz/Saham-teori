import 'dart:math' as math;
import 'data.dart';
import 'theories.dart';

/// Smart Money Concept (heuristik algoritmik): struktur pasar (BOS/CHoCH), Order Block,
/// Fair Value Gap, likuiditas (EQH/EQL + sweep), premium/discount, dan setup entry.
/// Semua indeks adalah indeks candle pada list yang dianalisis.

class SmcZone {
  final int from; // candle pembentuk zona
  final int brk; // candle yang mengonfirmasi (break) / sama dengan from untuk FVG
  final double lo, hi;
  final bool bull;
  final String kind; // 'OB' | 'FVG'
  SmcZone(this.from, this.brk, this.lo, this.hi, this.bull, this.kind);
}

class SmcBreak {
  final int from, to; // indeks swing yang ditembus -> candle penembus
  final double p;
  final bool bull, choch;
  SmcBreak(this.from, this.to, this.p, this.bull, this.choch);
  String get label => choch ? 'CHoCH' : 'BOS';
}

class SmcLiq {
  final int i;
  final double p;
  final bool high; // true = EQH (buy-side liquidity), false = EQL (sell-side)
  SmcLiq(this.i, this.p, this.high);
}

class SmcSetup {
  final bool buy;
  final String ref; // 'OB' | 'FVG'
  final double lo, hi, entry, sl, tp1, tp2, rr;
  final bool inZone;
  final String note;
  SmcSetup(this.buy, this.ref, this.lo, this.hi, this.entry, this.sl, this.tp1, this.tp2, this.rr,
      this.inZone, this.note);
}

class Smc {
  final int trend; // 1 bullish, -1 bearish, 0 belum jelas
  final double price, atr;
  final List<SmcBreak> breaks;
  final List<SmcZone> obs, fvgs;
  final List<SmcLiq> liq;
  final String? sweep;
  final bool? sweepBull; // true = sweep low (bullish), false = sweep high (bearish)
  final double? eq, rangeHi, rangeLo, pd; // pd = posisi harga dalam range (0 = dasar, 100 = puncak)
  final SmcSetup? setup;
  final String setupNote;
  Smc(this.trend, this.price, this.atr, this.breaks, this.obs, this.fvgs, this.liq, this.sweep,
      this.sweepBull, this.eq, this.rangeHi, this.rangeLo, this.pd, this.setup, this.setupNote);

  String get trendName => trend == 1 ? 'Bullish' : (trend == -1 ? 'Bearish' : 'Belum jelas');
  String get zoneName => pd == null ? '-' : (pd! < 45 ? 'Discount' : (pd! > 55 ? 'Premium' : 'Equilibrium'));
}

Smc? analyzeSmc(List<Candle> d, {int k = 3}) {
  final n = d.length;
  if (n < 60) return null;
  final s0 = math.max(0, n - 600);
  final price = d.last.c;

  // ATR(14) dan rata-rata rentang candle
  var tr = 0.0, trN = 0;
  for (var i = math.max(1, n - 14); i < n; i++) {
    tr += math.max(d[i].h - d[i].l, math.max((d[i].h - d[i - 1].c).abs(), (d[i].l - d[i - 1].c).abs()));
    trN++;
  }
  final atr = tr / trN;
  var rs = 0.0;
  final r0 = math.max(0, n - 100);
  for (var i = r0; i < n; i++) {
    rs += d[i].h - d[i].l;
  }
  final avgR = rs / (n - r0);
  final minGap = 0.15 * avgR;

  // fractal swing (k candle kiri & kanan)
  final isH = List<bool>.filled(n, false), isL = List<bool>.filled(n, false);
  for (var i = s0 + k; i < n - k; i++) {
    var hh = true, ll = true;
    for (var j = i - k; j <= i + k; j++) {
      if (j == i) continue;
      if (j < i ? d[j].h >= d[i].h : d[j].h > d[i].h) hh = false;
      if (j < i ? d[j].l <= d[i].l : d[j].l < d[i].l) ll = false;
    }
    isH[i] = hh;
    isL[i] = ll;
  }

  // struktur: BOS / CHoCH + Order Block
  var trend = 0;
  var hIdx = -1, lIdx = -1;
  var hP = 0.0, lP = 0.0;
  var hBroken = true, lBroken = true;
  final pivH = <int>[], pivL = <int>[];
  final breaks = <SmcBreak>[];
  final allObs = <SmcZone>[];
  for (var i = s0; i < n; i++) {
    final pi = i - k;
    if (pi >= s0 + k) {
      if (isH[pi]) {
        pivH.add(pi);
        hIdx = pi;
        hP = d[pi].h;
        hBroken = false;
      }
      if (isL[pi]) {
        pivL.add(pi);
        lIdx = pi;
        lP = d[pi].l;
        lBroken = false;
      }
    }
    if (!hBroken && d[i].c > hP) {
      breaks.add(SmcBreak(hIdx, i, hP, true, trend == -1));
      trend = 1;
      hBroken = true;
      var a = (lIdx >= 0 && lIdx < i) ? lIdx : math.max(s0, i - 15);
      a = math.max(a, i - 60);
      var best = -1;
      for (var j = a; j < i; j++) {
        if (d[j].c < d[j].o && (best == -1 || d[j].l <= d[best].l)) best = j;
      }
      if (best == -1) {
        for (var j = a; j < i; j++) {
          if (best == -1 || d[j].l <= d[best].l) best = j;
        }
      }
      if (best != -1) allObs.add(SmcZone(best, i, d[best].l, d[best].h, true, 'OB'));
    } else if (!lBroken && d[i].c < lP) {
      breaks.add(SmcBreak(lIdx, i, lP, false, trend == 1));
      trend = -1;
      lBroken = true;
      var a = (hIdx >= 0 && hIdx < i) ? hIdx : math.max(s0, i - 15);
      a = math.max(a, i - 60);
      var best = -1;
      for (var j = a; j < i; j++) {
        if (d[j].c > d[j].o && (best == -1 || d[j].h >= d[best].h)) best = j;
      }
      if (best == -1) {
        for (var j = a; j < i; j++) {
          if (best == -1 || d[j].h >= d[best].h) best = j;
        }
      }
      if (best != -1) allObs.add(SmcZone(best, i, d[best].l, d[best].h, false, 'OB'));
    }
  }

  // Order Block yang belum termitigasi (belum ditutup menembus zona)
  final obs = <SmcZone>[];
  for (final z in allObs) {
    var mit = false;
    for (var j = z.brk + 1; j < n; j++) {
      if (z.bull ? d[j].c < z.lo : d[j].c > z.hi) {
        mit = true;
        break;
      }
    }
    if (!mit) obs.add(z);
  }
  List<SmcZone> lastN(List<SmcZone> l, bool bull, int m) {
    final x = l.where((z) => z.bull == bull).toList()..sort((a, b) => b.from.compareTo(a.from));
    return x.take(m).toList();
  }

  final obsKeep = [...lastN(obs, true, 3), ...lastN(obs, false, 3)];

  // Fair Value Gap yang belum terisi penuh
  final fv = <SmcZone>[];
  for (var i = math.max(s0 + 2, n - 400); i < n; i++) {
    if (d[i].l - d[i - 2].h > minGap) {
      final lo = d[i - 2].h;
      var hi = d[i].l;
      var filled = false;
      for (var j = i + 1; j < n; j++) {
        if (d[j].l <= lo) {
          filled = true;
          break;
        }
        if (d[j].l < hi) hi = d[j].l;
      }
      if (!filled && hi - lo >= 0.5 * minGap) fv.add(SmcZone(i - 1, i, lo, hi, true, 'FVG'));
    } else if (d[i - 2].l - d[i].h > minGap) {
      var lo = d[i].h;
      final hi = d[i - 2].l;
      var filled = false;
      for (var j = i + 1; j < n; j++) {
        if (d[j].h >= hi) {
          filled = true;
          break;
        }
        if (d[j].h > lo) lo = d[j].h;
      }
      if (!filled && hi - lo >= 0.5 * minGap) fv.add(SmcZone(i - 1, i, lo, hi, false, 'FVG'));
    }
  }
  final fvKeep = [...lastN(fv, true, 3), ...lastN(fv, false, 3)];

  // Likuiditas: equal highs/lows yang belum disapu
  final tol = 0.15 * atr;
  final liq = <SmcLiq>[];
  final pH = pivH.where((i) => i >= n - 300).toList();
  final pL = pivL.where((i) => i >= n - 300).toList();
  for (var x = 0; x < pH.length; x++) {
    for (var y = x + 1; y < pH.length; y++) {
      final a = pH[x], b = pH[y];
      if (b - a < 5 || (d[a].h - d[b].h).abs() > tol) continue;
      final lvl = math.max(d[a].h, d[b].h);
      var swept = false;
      for (var j = b + 1; j < n; j++) {
        if (d[j].h > lvl) {
          swept = true;
          break;
        }
      }
      if (!swept && !liq.any((q) => q.high && (q.p - lvl).abs() <= tol)) liq.add(SmcLiq(b, lvl, true));
    }
  }
  for (var x = 0; x < pL.length; x++) {
    for (var y = x + 1; y < pL.length; y++) {
      final a = pL[x], b = pL[y];
      if (b - a < 5 || (d[a].l - d[b].l).abs() > tol) continue;
      final lvl = math.min(d[a].l, d[b].l);
      var swept = false;
      for (var j = b + 1; j < n; j++) {
        if (d[j].l < lvl) {
          swept = true;
          break;
        }
      }
      if (!swept && !liq.any((q) => !q.high && (q.p - lvl).abs() <= tol)) liq.add(SmcLiq(b, lvl, false));
    }
  }

  // Sweep terbaru (6 candle terakhir): wick menembus swing tapi close kembali
  String? sweep;
  bool? sweepBull;
  for (var j = n - 1; j >= n - 6 && sweep == null; j--) {
    for (final p in pivH.reversed) {
      if (p >= j - 1) continue;
      final lvl = d[p].h;
      if (d[j].h > lvl && d[j].c < lvl) {
        var prior = false;
        for (var q = p + 1; q < j; q++) {
          if (d[q].h > lvl) {
            prior = true;
            break;
          }
        }
        if (!prior) {
          sweep = 'Sweep high ${f0(lvl)} (${n - 1 - j} candle lalu): likuiditas atas diambil, waspada reversal turun';
          sweepBull = false;
          break;
        }
      }
    }
    if (sweep != null) break;
    for (final p in pivL.reversed) {
      if (p >= j - 1) continue;
      final lvl = d[p].l;
      if (d[j].l < lvl && d[j].c > lvl) {
        var prior = false;
        for (var q = p + 1; q < j; q++) {
          if (d[q].l < lvl) {
            prior = true;
            break;
          }
        }
        if (!prior) {
          sweep = 'Sweep low ${f0(lvl)} (${n - 1 - j} candle lalu): likuiditas bawah diambil, waspada reversal naik';
          sweepBull = true;
          break;
        }
      }
    }
  }

  // Premium / Discount: range 100 candle terakhir
  var rHi = -double.infinity, rLo = double.infinity;
  for (var i = r0; i < n; i++) {
    rHi = math.max(rHi, d[i].h);
    rLo = math.min(rLo, d[i].l);
  }
  final eq = (rHi + rLo) / 2;
  final pd = rHi > rLo ? (price - rLo) / (rHi - rLo) * 100 : 50.0;

  // Setup entry: zona OB/FVG searah struktur yang belum termitigasi, terdekat dengan harga
  SmcSetup? setup;
  var note = '';
  if (trend == 0) {
    note = 'Struktur belum jelas (belum ada BOS/CHoCH). Tunggu konfirmasi.';
  } else {
    final buy = trend == 1;
    final zones = [...obsKeep, ...fvKeep].where((z) => z.bull == buy).toList();
    final cand = zones.where((z) => buy ? z.lo <= price : z.hi >= price).toList();
    if (cand.isEmpty) {
      note = 'Belum ada OB/FVG ${buy ? 'bullish' : 'bearish'} yang belum termitigasi ${buy ? 'di bawah' : 'di atas'} harga.';
    } else {
      cand.sort((a, b) {
        final da = buy ? (price - a.hi).abs() : (a.lo - price).abs();
        final db = buy ? (price - b.hi).abs() : (b.lo - price).abs();
        final c = da.compareTo(db);
        return c != 0 ? c : (a.kind == 'OB' ? -1 : 1);
      });
      final z = cand.first;
      final inZone = price >= z.lo && price <= z.hi;
      // Entry: harga sekarang jika sudah di zona, jika belum di tepi zona terdekat (lebih mudah terisi).
      final entry = inZone ? price : (buy ? z.hi : z.lo);
      // SL 1 ATR di luar sisi jauh zona agar tidak mudah tersapu wick.
      final sl = buy ? z.lo - 1.0 * atr : z.hi + 1.0 * atr;
      final risk = (entry - sl).abs();
      if (risk <= 0) {
        note = 'Zona terlalu sempit untuk dihitung.';
      } else {
        // target = likuiditas / swing yang belum disapu searah arah
        final targets = <double>[];
        for (final q in liq) {
          if (buy ? (q.high && q.p > entry) : (!q.high && q.p < entry)) targets.add(q.p);
        }
        for (final p in (buy ? pivH : pivL)) {
          final lvl = buy ? d[p].h : d[p].l;
          var swept = false;
          for (var j = p + 1; j < n; j++) {
            if (buy ? d[j].h > lvl : d[j].l < lvl) {
              swept = true;
              break;
            }
          }
          if (!swept && (buy ? lvl > entry : lvl < entry)) targets.add(lvl);
        }
        targets.sort((a, b) => buy ? a.compareTo(b) : b.compareTo(a));
        final far = targets.where((t) => (t - entry).abs() >= risk).toList();
        final tp1 = far.isNotEmpty ? far.first : (buy ? entry + 2 * risk : entry - 2 * risk);
        final nxt = far.where((t) => buy ? t > tp1 + 0.1 * atr : t < tp1 - 0.1 * atr).toList();
        final tp2 = nxt.isNotEmpty ? nxt.first : (buy ? tp1 + risk : tp1 - risk);
        final parts = <String>[];
        if (buy && pd > 55) parts.add('harga masih premium (${pd.toStringAsFixed(0)}%), idealnya buy di discount');
        if (!buy && pd < 45) parts.add('harga masih discount (${pd.toStringAsFixed(0)}%), idealnya sell di premium');
        if (sweepBull != null && sweepBull == buy) parts.add('ada sweep likuiditas yang searah (konfirmasi)');
        final dist = buy ? price - z.hi : z.lo - price;
        if (!inZone && dist > 6 * atr) parts.add('zona masih jauh dari harga (${(dist / atr).toStringAsFixed(1)} ATR)');
        setup = SmcSetup(buy, z.kind, z.lo, z.hi, entry, sl, tp1, tp2, (tp1 - entry).abs() / risk, inZone,
            parts.join('; '));
      }
    }
  }

  return Smc(trend, price, atr, breaks.length > 6 ? breaks.sublist(breaks.length - 6) : breaks, obsKeep, fvKeep,
      liq, sweep, sweepBull, eq, rHi, rLo, pd, setup, note);
}

/// Kesimpulan satu-dua kalimat dari hasil SMC.
String smcConclusion(Smc s) {
  final u = s.setup;
  final bias = s.trend == 1 ? 'BUY' : (s.trend == -1 ? 'SELL' : null);
  if (bias == null) return 'Struktur belum jelas, sebaiknya tunggu.';
  final good = (s.trend == 1 && s.zoneName == 'Discount') || (s.trend == -1 && s.zoneName == 'Premium');
  final zone = s.zoneName == 'Equilibrium' ? 'di tengah range' : 'di zona ${s.zoneName}';
  if (u == null) return 'Bias $bias (struktur ${s.trendName}), harga $zone. Belum ada setup, tunggu pullback ke zona.';
  final where = u.inZone ? 'harga sudah di zona setup, tunggu candle konfirmasi' : 'tunggu harga pullback ke zona ${u.lo.toStringAsFixed(priceDec)}–${u.hi.toStringAsFixed(priceDec)}';
  final align = u.buy == (s.trend == 1) ? (good ? 'searah struktur & zona ideal' : 'searah struktur') : 'melawan struktur (hati-hati)';
  return 'Bias $bias, $align, harga $zone. $where. RR 1:${u.rr.toStringAsFixed(1)}.';
}
