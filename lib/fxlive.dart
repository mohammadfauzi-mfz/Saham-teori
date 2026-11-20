import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'data.dart';
import 'indicators.dart';
import 'store.dart';
import 'theories.dart';

/// Ambil candle terbaru saja lalu gabungkan ke data lama (hemat data untuk auto-refresh).
Future<List<Candle>> mergeRecent(List<Candle> d, String code, String iv) async {
  final rc = isIntraday(iv) ? '1d' : (iv == '1wk' ? '3mo' : '5d');
  final r = await fetchCandles(code, range: rc, interval: iv);
  if (r.isEmpty) return d;
  final t0 = r.first.t;
  return [...d.where((c) => c.t.isBefore(t0)), ...r];
}

class FxSnap {
  final double price, chg, buyIdeal, buyStop, sellIdeal, sellStop;
  final int bull, bear, total;
  final DateTime at;
  FxSnap(this.price, this.chg, this.buyIdeal, this.buyStop, this.sellIdeal, this.sellStop, this.bull,
      this.bear, this.total, this.at);
  double get ratio => total == 0 ? 0 : bull / total;
  String get verdict => ratio >= 0.6 ? 'BUY' : (ratio <= 0.4 ? 'SELL' : 'NETRAL');
  Color get color => ratio >= 0.6 ? Colors.greenAccent : (ratio <= 0.4 ? Colors.redAccent : Colors.amber);
}

FxSnap fxSnapshot(List<Candle> d) {
  final x = Indicators(d);
  swingOverride = autoSwing(d);
  final s = analyze(d, x, Fund(), forex: true);
  final lr = recommend(d, x, s);
  final sr = recommendShort(d, x, s);
  final bull = s.where((e) => e.ok).length;
  final n = d.length;
  final prev = d[n - 2].c;
  return FxSnap(d.last.c, prev == 0 ? 0 : (d.last.c - prev) / prev * 100, lr.ideal, lr.stop, sr.ideal, sr.stop,
      bull, s.length - bull, s.length, DateTime.now());
}

String hms(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

/// Tampilan jendela melayang. Berjalan di isolate terpisah: mengambil & menganalisis data sendiri,
/// jadi tetap hidup saat aplikasi utama di latar belakang. Konfigurasi dikirim aplikasi: "KODE|interval|detik".
class FxOverlay extends StatefulWidget {
  const FxOverlay({super.key});
  @override
  State<FxOverlay> createState() => _FxOverlayState();
}

class _FxOverlayState extends State<FxOverlay> {
  String code = 'EURUSD', iv = '15m';
  int sec = 10;
  List<Candle> d = [];
  FxSnap? snap;
  String? err;
  Timer? timer;
  bool busy = false;
  StreamSubscription? sub;

  @override
  void initState() {
    super.initState();
    sub = FlutterOverlayWindow.overlayListener.listen(_onData);
    _restart();
  }

  @override
  void dispose() {
    sub?.cancel();
    timer?.cancel();
    super.dispose();
  }

  void _onData(dynamic e) {
    final p = e.toString().split('|');
    if (p.length < 3) return;
    final s = (int.tryParse(p[2]) ?? 10).clamp(3, 120).toInt();
    if (p[0] == code && p[1] == iv && s == sec && snap != null) return;
    if (p[0] != code || p[1] != iv) {
      d = [];
      snap = null;
    }
    code = p[0];
    iv = p[1];
    sec = s;
    _restart();
  }

  void _restart() {
    timer?.cancel();
    _tick();
    timer = Timer.periodic(Duration(seconds: sec), (_) => _tick());
  }

  Future<void> _tick() async {
    if (busy) return;
    busy = true;
    final c0 = code, i0 = iv;
    try {
      var nd = d.isEmpty
          ? await fetchCandles(c0, range: rangeFor(i0), interval: i0)
          : await mergeRecent(d, c0, i0);
      if (c0 != code || i0 != iv) {
        busy = false;
        return;
      }
      if (nd.length > 1500) nd = nd.sublist(nd.length - 1500);
      if (nd.length < 80) throw Exception('data kurang');
      d = nd;
      snap = fxSnapshot(nd);
      err = null;
    } catch (_) {
      err = 'Gagal ambil data';
    }
    busy = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    priceDec = decFor(code);
    final s = snap;
    final col = s?.color ?? Colors.white38;
    const small = TextStyle(fontSize: 12, color: Colors.white);
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: const Color(0xEB0F1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: col, width: 1.5)),
        child: s == null
            ? Center(
                child: Text(err ?? 'Memuat $code...',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)))
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 232,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Expanded(
                          child: Text('$code · ${tfLabel(iv)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white))),
                      InkWell(
                          onTap: () => FlutterOverlayWindow.closeOverlay(),
                          child: const Icon(Icons.close, size: 20, color: Colors.white70)),
                    ]),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(f0(s.price),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(width: 8),
                      Text('${s.chg >= 0 ? '+' : ''}${s.chg.toStringAsFixed(3)}%',
                          style: TextStyle(fontSize: 13, color: s.chg >= 0 ? Colors.greenAccent : Colors.redAccent)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(8)),
                          child: Text(s.verdict,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black))),
                      const SizedBox(width: 8),
                      Text('▲${s.bull}  ▼${s.bear}  /${s.total}', style: small),
                    ]),
                    const SizedBox(height: 4),
                    Text('Buy ${f0(s.buyIdeal)}  SL ${f0(s.buyStop)}',
                        style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
                    Text('Sell ${f0(s.sellIdeal)}  SL ${f0(s.sellStop)}',
                        style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                    Text('${hms(s.at)} • tiap $sec dtk${err != null ? ' • ⚠ $err' : ''}',
                        style: const TextStyle(fontSize: 10, color: Colors.white54)),
                  ]),
                ),
              ),
      ),
    );
  }
}
