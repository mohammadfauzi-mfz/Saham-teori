import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'data.dart';
import 'indicators.dart';
import 'theories.dart';

void _txt(Canvas c, String s, Offset o) {
  final tp = TextPainter(
      text: TextSpan(text: s, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      textDirection: TextDirection.ltr)
    ..layout();
  tp.paint(c, o);
}

void _line(Canvas canvas, List<double> s, int st, int end, double Function(int) x,
    double Function(double) y, Color color) {
  final path = Path();
  var started = false;
  for (var i = st; i < end; i++) {
    if (s[i].isNaN) {
      started = false;
      continue;
    }
    if (!started) {
      path.moveTo(x(i), y(s[i]));
      started = true;
    } else {
      path.lineTo(x(i), y(s[i]));
    }
  }
  canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
}

List<int> _rng(int n, int count, int offset) {
  final end = (n - offset).clamp(1, n).toInt();
  final st = math.max(0, end - count);
  return [st, end];
}

class PricePainter extends CustomPainter {
  final List<Candle> d;
  final Indicators ind;
  final int count, offset;
  final Reco? reco;
  final bool oMA, oBB, oSR;
  final List<double> sr;
  final int? cross;
  PricePainter(
      {required this.d,
      required this.ind,
      required this.count,
      required this.offset,
      this.reco,
      this.oMA = true,
      this.oBB = true,
      this.oSR = true,
      this.sr = const [],
      this.cross});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final n = d.length;
    final r = _rng(n, count, offset);
    final st = r[0], end = r[1], cnt = end - st;
    var mn = double.infinity, mx = -double.infinity;
    for (var i = st; i < end; i++) {
      mn = math.min(mn, d[i].l);
      mx = math.max(mx, d[i].h);
      if (oBB) {
        for (final v in [ind.bbUp[i], ind.bbLow[i]]) {
          if (!v.isNaN) {
            mn = math.min(mn, v);
            mx = math.max(mx, v);
          }
        }
      }
    }
    if (reco != null && offset == 0 && reco!.stop > mn * 0.88) mn = math.min(mn, reco!.stop);
    final pad = (mx - mn) * 0.03;
    mn -= pad;
    mx += pad;
    final cw = size.width / cnt;
    double x(int i) => (i - st + 0.5) * cw;
    double y(double v) => size.height * (1 - (v - mn) / (mx - mn));
    final grid = Paint()..color = Colors.white12;
    for (var k = 0; k <= 4; k++) {
      final v = mn + (mx - mn) * k / 4;
      final yy = y(v);
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), grid);
      _txt(canvas, v.toStringAsFixed(0), Offset(2, yy - 12));
    }
    if (reco != null) {
      canvas.drawRect(Rect.fromLTRB(0, y(reco!.buyHigh), size.width, y(reco!.buyLow)),
          Paint()..color = Colors.greenAccent.withOpacity(0.15));
      canvas.drawLine(
          Offset(0, y(reco!.stop)),
          Offset(size.width, y(reco!.stop)),
          Paint()
            ..color = Colors.redAccent
            ..strokeWidth = 1);
      _txt(canvas, 'Zona beli', Offset(size.width - 50, y(reco!.buyHigh) + 1));
      _txt(canvas, 'Stop', Offset(size.width - 28, y(reco!.stop) - 12));
    }
    if (oSR) {
      final last = d.last.c;
      for (final v in sr) {
        final col = v > last ? Colors.redAccent : Colors.greenAccent;
        canvas.drawLine(Offset(0, y(v)), Offset(size.width, y(v)),
            Paint()
              ..color = col.withOpacity(0.35)
              ..strokeWidth = 1);
        _txt(canvas, v > last ? 'R ${f0(v)}' : 'S ${f0(v)}', Offset(size.width - 62, y(v) - 11));
      }
    }
    if (oBB) {
      _line(canvas, ind.bbUp, st, end, x, y, Colors.grey);
      _line(canvas, ind.bbLow, st, end, x, y, Colors.grey);
    }
    for (var i = st; i < end; i++) {
      final up = d[i].c >= d[i].o;
      final col = up ? Colors.greenAccent : Colors.redAccent;
      final p = Paint()..color = col;
      canvas.drawLine(Offset(x(i), y(d[i].h)), Offset(x(i), y(d[i].l)), p);
      canvas.drawRect(
          Rect.fromLTRB(x(i) - cw * 0.35, y(math.max(d[i].o, d[i].c)), x(i) + cw * 0.35,
              y(math.min(d[i].o, d[i].c)) + 0.5),
          p);
    }
    if (oMA) {
      _line(canvas, ind.ma20, st, end, x, y, Colors.amber);
      _line(canvas, ind.ma50, st, end, x, y, Colors.lightBlueAccent);
      _line(canvas, ind.ma200, st, end, x, y, Colors.orangeAccent);
    }
    for (final idx in {st, (st + end) ~/ 2, end - 1}) {
      _txt(canvas, fd(d[idx].t), Offset(math.max(0, x(idx) - 20), size.height - 12));
    }
    final cr = cross;
    if (cr != null && cr >= st && cr < end) {
      final p = Paint()
        ..color = Colors.white54
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x(cr), 0), Offset(x(cr), size.height), p);
      canvas.drawLine(Offset(0, y(d[cr].c)), Offset(size.width, y(d[cr].c)), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class VolPainter extends CustomPainter {
  final List<Candle> d;
  final int count, offset;
  VolPainter(this.d, this.count, this.offset);

  @override
  void paint(Canvas canvas, Size size) {
    final r = _rng(d.length, count, offset);
    final st = r[0], end = r[1], cnt = end - st;
    var mx = 1.0;
    for (var i = st; i < end; i++) {
      mx = math.max(mx, d[i].v);
    }
    final cw = size.width / cnt;
    for (var i = st; i < end; i++) {
      final up = d[i].c >= d[i].o;
      final hgt = size.height * d[i].v / mx;
      canvas.drawRect(
          Rect.fromLTRB((i - st) * cw + cw * 0.15, size.height - hgt, (i - st + 1) * cw - cw * 0.15, size.height),
          Paint()..color = (up ? Colors.greenAccent : Colors.redAccent).withOpacity(0.55));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class SubPainter extends CustomPainter {
  final List<List<double>> series;
  final List<Color> colors;
  final int count, offset;
  final List<double>? hist;
  final List<double> guides;
  final double? fixMin, fixMax;
  SubPainter(this.series, this.colors, this.count, this.offset,
      {this.hist, this.guides = const [], this.fixMin, this.fixMax});

  @override
  void paint(Canvas canvas, Size size) {
    final n = series.first.length;
    final r = _rng(n, count, offset);
    final st = r[0], end = r[1], cnt = end - st;
    var mn = fixMin ?? double.infinity, mx = fixMax ?? -double.infinity;
    if (fixMin == null) {
      for (final s in [...series, if (hist != null) hist!]) {
        for (var i = st; i < end; i++) {
          if (!s[i].isNaN) {
            mn = math.min(mn, s[i]);
            mx = math.max(mx, s[i]);
          }
        }
      }
      mn = math.min(mn, 0);
      mx = math.max(mx, 0);
    }
    if (mx - mn == 0) mx = mn + 1;
    final cw = size.width / cnt;
    double x(int i) => (i - st + 0.5) * cw;
    double y(double v) => size.height * (1 - (v - mn) / (mx - mn));
    final grid = Paint()..color = Colors.white24;
    for (final g in guides) {
      canvas.drawLine(Offset(0, y(g)), Offset(size.width, y(g)), grid);
      _txt(canvas, g.toStringAsFixed(0), Offset(2, y(g) - 12));
    }
    if (hist != null) {
      canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), grid);
      for (var i = st; i < end; i++) {
        final v = hist![i];
        if (v.isNaN) continue;
        canvas.drawRect(
            Rect.fromLTRB(x(i) - cw * 0.35, math.min(y(0), y(v)), x(i) + cw * 0.35, math.max(y(0), y(v))),
            Paint()..color = (v >= 0 ? Colors.greenAccent : Colors.redAccent).withOpacity(0.5));
      }
    }
    for (var k = 0; k < series.length; k++) {
      _line(canvas, series[k], st, end, x, y, colors[k]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
