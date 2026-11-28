import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'data.dart';

/// Indeks sintetis Deriv (data realtime, WebSocket publik tanpa login).
const derivSymbols = [
  ['R_10', 'Vol 10'], ['R_25', 'Vol 25'], ['R_50', 'Vol 50'], ['R_75', 'Vol 75'], ['R_100', 'Vol 100'],
  ['1HZ10V', 'Vol 10 (1s)'], ['1HZ25V', 'Vol 25 (1s)'], ['1HZ50V', 'Vol 50 (1s)'],
  ['1HZ75V', 'Vol 75 (1s)'], ['1HZ100V', 'Vol 100 (1s)'],
];
final _derivRe = RegExp(r'^(R_\d+|1HZ\d+V)$');
bool isDeriv(String c) => _derivRe.hasMatch(c);

/// Jumlah desimal dari pip_size yang dilaporkan Deriv (diisi saat data dimuat).
final derivDec = <String, int>{};

const _ws = 'wss://api.derivws.com/trading/v1/options/ws/public';
const _gran = {'1m': 60, '5m': 300, '15m': 900, '30m': 1800, '60m': 3600, '4h': 14400, '1d': 86400, '1wk': 86400};

Future<List<Candle>> fetchDeriv(String sym, {String range = '2y', String interval = '1d'}) async {
  final g = _gran[interval] ?? 86400;
  final small = range == '1d' || range == '5d' || range == '3mo';
  final count = interval == '1wk' ? 1500 : (small ? 120 : 1000);
  final ws = await WebSocket.connect(_ws).timeout(const Duration(seconds: 12));
  try {
    ws.add(jsonEncode({
      'ticks_history': sym,
      'adjust_start_time': 1,
      'count': count,
      'end': 'latest',
      'start': 1,
      'style': 'candles',
      'granularity': g,
    }));
    final done = Completer<Map>();
    final sub = ws.listen((m) {
      try {
        final j = jsonDecode(m as String) as Map;
        if (j['error'] != null) {
          if (!done.isCompleted) done.completeError(Exception(j['error']['message'] ?? 'Deriv error'));
        } else if (j['msg_type'] == 'candles' && !done.isCompleted) {
          done.complete(j);
        }
      } catch (e) {
        if (!done.isCompleted) done.completeError(e);
      }
    }, onError: (e) {
      if (!done.isCompleted) done.completeError(e);
    }, onDone: () {
      if (!done.isCompleted) done.completeError(Exception('Koneksi Deriv terputus'));
    });
    final j = await done.future.timeout(const Duration(seconds: 15));
    await sub.cancel();
    final ps = j['pip_size'];
    if (ps is num && ps > 0) {
      derivDec[sym] = ps >= 1 ? ps.toInt() : (-(math.log(ps) / math.ln10)).round(); // jumlah desimal, atau ukuran pip 0.001
    }
    var out = <Candle>[
      for (final c in (j['candles'] as List))
        Candle(DateTime.fromMillisecondsSinceEpoch((c['epoch'] as num).toInt() * 1000),
            (c['open'] as num).toDouble(), (c['high'] as num).toDouble(), (c['low'] as num).toDouble(),
            (c['close'] as num).toDouble(), 0)
    ];
    if (out.isEmpty) throw Exception('Data Deriv kosong (cek kode simbol)');
    if (interval == '1wk') out = _weekly(out);
    return out;
  } finally {
    ws.close();
  }
}

List<Candle> _weekly(List<Candle> d) {
  final out = <Candle>[];
  int? cur;
  for (final c in d) {
    final w = (c.t.millisecondsSinceEpoch ~/ 86400000 + 3) ~/ 7; // Senin sebagai awal pekan
    if (cur == w && out.isNotEmpty) {
      final p = out.last;
      out[out.length - 1] = Candle(p.t, p.o, c.h > p.h ? c.h : p.h, c.l < p.l ? c.l : p.l, c.c, 0);
    } else {
      cur = w;
      out.add(c);
    }
  }
  return out;
}
