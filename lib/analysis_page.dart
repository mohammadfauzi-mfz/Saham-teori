import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'backtest.dart';
import 'charts.dart';
import 'fundauto.dart';
import 'fxlive.dart';
import 'service.dart';
import 'smc.dart';
import 'data.dart';
import 'indicators.dart';
import 'store.dart';
import 'theories.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});
  @override
  State<AnalysisPage> createState() => AnalysisPageState();
}

class AnalysisPageState extends State<AnalysisPage> with WidgetsBindingObserver {
  final ctl = TextEditingController(text: 'BBCA');
  List<Candle> data = [];
  List<Signal> sigs = [];
  Indicators? ind;
  Reco? reco, recoS;
  bool short = false;
  String loadedCode = '';
  double loadedSwing = 0;
  Fund fund = Fund();
  List<double> sr = [];
  bool loading = false;
  String? err;
  String interval = '1d';
  int count = 120;
  double off = 0;
  int? cross;
  double chartW = 300;
  final Map<int, Offset> _ptrs = {};
  double _pinchDist = 0;
  int _pinchBase = 120;
  bool pinching = false;
  bool oMA = true, oBB = true, oSR = true, oSMC = true;
  Smc? smc;
  bool pVol = true, pRSI = true, pMACD = true, pStoch = false, pADX = false;
  bool inWatch = false;
  Timer? _timer;
  bool autoOn = false, refreshing = false, overlayOn = false;
  int autoSec = 10;
  DateTime? lastUp;
  String? autoErr;

  int get offset => off.round();
  bool get fx => isForex(loadedCode);
  Reco? get cur => (fx && short) ? recoS : reco;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _restartTimer();
      if (autoOn && fx) refreshQuiet();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _setAuto(bool on) {
    setState(() => autoOn = on);
    _restartTimer();
    if (on) refreshQuiet();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (autoOn && fx) _timer = Timer.periodic(Duration(seconds: autoSec), (_) => refreshQuiet());
  }

  /// Refresh diam-diam (tanpa spinner), posisi geser/zoom grafik dipertahankan. Khusus forex.
  Future<void> refreshQuiet() async {
    if (refreshing || loading || data.isEmpty || !fx) return;
    refreshing = true;
    try {
      final c = loadedCode, iv = interval;
      final nd = await mergeRecent(data, c, iv);
      if (!mounted || c != loadedCode || iv != interval || nd.length < 80) return;
      final i = Indicators(nd);
      swingOverride = loadedSwing;
      final s = analyze(nd, i, Fund(), forex: true);
      final added = nd.length - data.length;
      setState(() {
        if (off > 0 && added > 0) off += added; // tetap di candle yang sama saat melihat riwayat
        data = nd;
        ind = i;
        sigs = s;
        reco = recommend(nd, i, s);
        recoS = recommendShort(nd, i, s);
        smc = analyzeSmc(nd);
        sr = srLevels(i);
        lastUp = DateTime.now();
        autoErr = null;
      });
    } catch (_) {
      if (mounted) setState(() => autoErr = 'Gagal refresh (koneksi/limit data)');
    } finally {
      refreshing = false;
    }
  }

  Future<void> _syncOverlay() async {
    if (!overlayOn || !fx) return;
    try {
      await FlutterOverlayWindow.shareData('$loadedCode|$interval|$autoSec|${Settings.ovStep}');
    } catch (_) {}
  }

  Future<void> toggleOverlay() async {
    final msg = ScaffoldMessenger.of(context);
    try {
      if (overlayOn) {
        await FlutterOverlayWindow.closeOverlay();
        if (mounted) setState(() => overlayOn = false);
        return;
      }
      var ok = await FlutterOverlayWindow.isPermissionGranted();
      if (!ok) ok = (await FlutterOverlayWindow.requestPermission()) ?? false;
      if (!ok) {
        msg.showSnackBar(const SnackBar(content: Text('Izin "Tampil di atas aplikasi lain" diperlukan')));
        return;
      }
      await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: 'Saham Teori',
          overlayContent: 'Indikator forex aktif',
          alignment: OverlayAlignment.topRight,
          height: ovH(ovWidths[Settings.ovStep]),
          width: ovWidths[Settings.ovStep]);
      if (mounted) setState(() => overlayOn = true);
      for (final ms in [800, 1000, 1700]) {
        await Future.delayed(Duration(milliseconds: ms));
        await _syncOverlay();
      }
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text('Jendela melayang gagal: $e')));
    }
  }

  String get code => ctl.text.trim().toUpperCase().replaceAll('.JK', '');

  Future<void> loadCode(String c) async {
    ctl.text = c;
    await load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final d = await fetchCandles(code, range: rangeFor(interval), interval: interval);
      if (d.length < 80) throw Exception('Data terlalu sedikit');
      final isFx = isForex(code);
      final f = isFx ? Fund() : await Store.fund(code);
      final w = await Store.watch();
      final i = Indicators(d);
      final idxc = isFx ? null : await indexCandles(interval);
      loadedSwing = (isFx || isIntraday(interval)) ? autoSwing(d) : 0;
      swingOverride = loadedSwing;
      final s = analyze(d, i, f, idx: idxc, forex: isFx);
      setState(() {
        data = d;
        ind = i;
        fund = f;
        sigs = s;
        reco = recommend(d, i, s);
        recoS = isFx ? recommendShort(d, i, s) : null;
        smc = isFx ? analyzeSmc(d) : null;
        short = false;
        loadedCode = code;
        priceDec = decFor(code);
        sr = srLevels(i);
        count = math.min(120, d.length);
        off = -(count * 0.15);
        cross = null;
        inWatch = w.contains(code);
        lastUp = DateTime.now();
        autoErr = null;
      });
    } catch (e) {
      setState(() => err = 'Gagal memuat: $e');
    }
    setState(() => loading = false);
    _restartTimer();
    _syncOverlay();
  }

  Future<void> toggleWatch() async {
    final w = await Store.watch();
    if (w.contains(code)) {
      w.remove(code);
    } else {
      w.add(code);
    }
    await Store.setWatch(w);
    setState(() => inWatch = w.contains(code));
  }

  Future<void> editFund() async {
    final keys = ['PER', 'PBV', 'ROE (%)', 'DER (x)', 'Dividend yield (%)', 'Pertumbuhan laba (%)'];
    final cs = [fund.per, fund.pbv, fund.roe, fund.der, fund.dy, fund.growth]
        .map((v) => TextEditingController(text: v == null ? '' : v.toString()))
        .toList();
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: Text('Fundamental $code'),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (var k = 0; k < keys.length; k++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: cs[k],
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                            labelText: keys[k], isDense: true, border: const OutlineInputBorder()),
                      ),
                    ),
                  const Text('Isi dari laporan keuangan/situs data saham. Kosongkan jika tidak ada.',
                      style: TextStyle(fontSize: 11, color: Colors.white54)),
                ]),
              ),
              actions: [
                TextButton(
                    onPressed: () async {
                      final msg = ScaffoldMessenger.of(context);
                      try {
                        final af = await fetchFund(code);
                        String t(double? v) => v == null ? '' : v.toStringAsFixed(2);
                        cs[0].text = t(af.per);
                        cs[1].text = t(af.pbv);
                        cs[2].text = t(af.roe);
                        cs[3].text = t(af.der);
                        cs[4].text = t(af.dy);
                        cs[5].text = t(af.growth);
                        msg.showSnackBar(const SnackBar(
                            content: Text('Data diambil dari Yahoo Finance. Periksa lalu tekan Simpan.')));
                      } catch (e) {
                        msg.showSnackBar(SnackBar(content: Text('Gagal ambil otomatis: $e')));
                      }
                    },
                    child: const Text('Ambil otomatis')),
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
              ],
            ));
    if (ok != true) return;
    double? p(int k) => double.tryParse(cs[k].text.trim().replaceAll(',', '.'));
    final f = Fund(per: p(0), pbv: p(1), roe: p(2), der: p(3), dy: p(4), growth: p(5));
    await Store.setFund(code, f);
    await load();
  }

  void calc() {
    if (fx) {
      calcFx();
      return;
    }
    final r = reco;
    if (r == null) return;
    final cap = TextEditingController(text: Settings.capital.toStringAsFixed(0));
    final risk = TextEditingController(text: Settings.riskPct.toString());
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(builder: (ctx, set) {
              final c = double.tryParse(cap.text.trim()) ?? 0;
              final rk = double.tryParse(risk.text.trim().replaceAll(',', '.')) ?? 0;
              final ps = r.ideal - r.stop;
              var lots = ps > 0 ? ((c * rk / 100) / ps / 100).floor() : 0;
              final maxLots = (c / (r.ideal * 100)).floor();
              if (lots > maxLots) lots = maxLots;
              final cost = lots * 100 * r.ideal;
              final loss = lots * 100 * ps;
              final gain = lots * 100 * (r.t1 - r.ideal);
              return Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kalkulator Posisi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: cap,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Modal (Rp)', border: OutlineInputBorder(), isDense: true),
                      onChanged: (_) => set(() {})),
                  const SizedBox(height: 8),
                  TextField(
                      controller: risk,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Risiko per transaksi (% modal)',
                          border: OutlineInputBorder(),
                          isDense: true),
                      onChanged: (_) => set(() {})),
                  const SizedBox(height: 12),
                  Text('Beli di ${f0(r.ideal)}, stop loss ${f0(r.stop)}'),
                  Text('Jumlah: $lots lot (${lots * 100} lembar)',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Nilai beli: Rp ${rp(cost)}'),
                  Text('Rugi jika kena stop: Rp ${rp(loss)}'),
                  Text('Potensi untung di Target 1: Rp ${rp(gain)}'),
                  const SizedBox(height: 6),
                  const Text('1 lot = 100 lembar. Belum termasuk fee broker/pajak.',
                      style: TextStyle(fontSize: 11, color: Colors.white38)),
                ]),
              );
            }));
  }

  Future<void> calcFx({SmcSetup? su}) async {
    final r = cur;
    if (r == null) return;
    final entry = su?.entry ?? r.ideal, slP = su?.sl ?? r.stop, t1P = su?.tp1 ?? r.t1;
    final c = loadedCode;
    final usdQ = await usdPerQuote(c, r.price);
    if (!mounted) return;
    final pip = pipSize(c);
    final pipVal = pip * contractSize(c) * (usdQ ?? 0); // USD per pip per 1 lot
    final cap = TextEditingController(text: Settings.capitalUsd.toStringAsFixed(0));
    final risk = TextEditingController(text: Settings.riskPct.toString());
    final sh = su != null ? !su.buy : short;
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(builder: (ctx, set) {
              final cp = double.tryParse(cap.text.trim().replaceAll(',', '.')) ?? 0;
              final rk = double.tryParse(risk.text.trim().replaceAll(',', '.')) ?? 0;
              final stopPips = (entry - slP).abs() / pip;
              final t1Pips = (t1P - entry).abs() / pip;
              var lots = 0.0;
              if (pipVal > 0 && stopPips > 0) lots = ((cp * rk / 100) / (stopPips * pipVal) * 100).floor() / 100;
              return Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Kalkulator Lot Forex $c${su != null ? ' (setup SMC)' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: cap,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Modal (USD)', border: OutlineInputBorder(), isDense: true),
                      onChanged: (v) {
                        Settings.capitalUsd = double.tryParse(v.trim().replaceAll(',', '.')) ?? Settings.capitalUsd;
                        set(() {});
                      }),
                  const SizedBox(height: 8),
                  TextField(
                      controller: risk,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Risiko per transaksi (% modal)',
                          border: OutlineInputBorder(),
                          isDense: true),
                      onChanged: (_) => set(() {})),
                  const SizedBox(height: 12),
                  Text('${sh ? 'Jual (short)' : 'Beli (long)'} di ${f0(entry)}, stop ${f0(slP)} '
                      '(${stopPips.toStringAsFixed(1)} pip)'),
                  Text('Ukuran posisi: ${lots.toStringAsFixed(2)} lot',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (usdQ == null)
                    const Text('Kurs konversi ke USD tidak tersedia, nilai pip tidak bisa dihitung.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12))
                  else ...[
                    Text('Nilai 1 pip per 1 lot ≈ \$${pipVal.toStringAsFixed(2)}'),
                    Text('Rugi jika kena stop: \$${(lots * stopPips * pipVal).toStringAsFixed(2)}'),
                    Text('Potensi untung di Target 1: \$${(lots * t1Pips * pipVal).toStringAsFixed(2)}'),
                  ],
                  const SizedBox(height: 6),
                  const Text(
                      '1 lot = 100.000 unit (emas: 100 oz). Belum termasuk spread/komisi/swap. '
                      'Cek margin & leverage di broker; lot dibulatkan ke bawah 0,01.',
                      style: TextStyle(fontSize: 11, color: Colors.white38)),
                ]),
              );
            }));
    await Settings.save();
  }

  Future<void> openSettings() async {
    final cs = [
      (Settings.swing * 100).toStringAsFixed(1),
      Settings.stopAtr.toString(),
      Settings.zoneAtr.toString(),
      Settings.riskPct.toString(),
      Settings.capital.toStringAsFixed(0),
    ].map((v) => TextEditingController(text: v)).toList();
    const labels = [
      'Ambang swing/zigzag (%)',
      'Pengali ATR untuk stop loss',
      'Lebar zona beli (± x ATR)',
      'Risiko per transaksi (% modal)',
      'Modal default (Rp)'
    ];
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Pengaturan'),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (var k = 0; k < labels.length; k++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: cs[k],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                            labelText: labels[k], isDense: true, border: const OutlineInputBorder()),
                      ),
                    ),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
              ],
            ));
    if (ok != true) return;
    double g(int k, double def) => double.tryParse(cs[k].text.trim().replaceAll(',', '.')) ?? def;
    Settings.swing = (g(0, 5) / 100).clamp(0.02, 0.2).toDouble();
    Settings.stopAtr = g(1, 1).clamp(0.5, 5.0).toDouble();
    Settings.zoneAtr = g(2, 0.5).clamp(0.1, 3.0).toDouble();
    Settings.riskPct = g(3, 1).clamp(0.1, 10.0).toDouble();
    Settings.capital = g(4, 10000000);
    await Settings.save();
    await load();
  }

  Future<void> addPortfolio() async {
    final r = reco;
    if (r == null) return;
    final lot = TextEditingController(text: '1');
    final avg = TextEditingController(text: f0(r.price));
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: Text('Tambah $code ke portofolio'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: lot,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Jumlah lot', isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(
                    controller: avg,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Harga beli per lembar', isDense: true, border: OutlineInputBorder())),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tambah')),
              ],
            ));
    if (ok != true) return;
    final l = int.tryParse(lot.text.trim());
    final a = double.tryParse(avg.text.trim().replaceAll(',', '.'));
    if (l == null || l <= 0 || a == null || a <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Input tidak valid')));
      }
      return;
    }
    final hs = await Store.holdings();
    final k = hs.indexWhere((h) => h.code == code);
    if (k >= 0) {
      final h = hs[k];
      final tl = h.lots + l;
      hs[k] = Holding(code, tl, (h.avg * h.lots + a * l) / tl);
    } else {
      hs.add(Holding(code, l, a));
    }
    await Store.setHoldings(hs);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ditambahkan ke portofolio')));
    }
  }

  void runBacktest() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => FutureBuilder<BtResult>(
              future: backtestAsync(data.length > 1200 ? data.sublist(data.length - 1200) : data, forex: fx),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Menjalankan backtest...'),
                      ]));
                }
                final b = snap.data!;
                if (b.note.isNotEmpty) return Padding(padding: const EdgeInsets.all(24), child: Text(b.note));
                final win = b.trades == 0 ? 0 : b.wins / b.trades * 100;
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Backtest $code', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Transaksi: ${b.trades}  •  Menang: ${win.toStringAsFixed(0)}%'),
                      Text('Total return strategi: ${b.total.toStringAsFixed(1)}%'),
                      Text('Buy & hold periode sama: ${b.bh.toStringAsFixed(1)}%'),
                      Text('Max drawdown: ${b.maxDd.toStringAsFixed(1)}%'),
                      const SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(b.log.reversed.take(15).join('\n'),
                              style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Aturan: beli saat ≥60% teori teknikal hijau, jual saat <35%, stop 2 ATR, target 3 ATR, maks 40 candle, fee ${fx ? '0,02' : '0,4'}%. '
                          'Hasil historis tidak menjamin masa depan.',
                          style: TextStyle(fontSize: 11, color: Colors.white38)),
                    ]),
                  ),
                );
              },
            ));
  }

  void copySummary() {
    final r = cur;
    if (r == null) return;
    final tf = tfLabel(interval);
    final b = StringBuffer();
    b.writeln('$code ($tf)${fx ? (short ? ' - SELL' : ' - BUY') : ''}');
    b.writeln('Harga: ${f0(r.price)}');
    b.writeln('Skor: ${r.score}/${r.total} hijau');
    b.writeln(r.verdict);
    b.writeln('${fx && short ? 'Zona jual' : 'Zona beli'}: ${f0(r.buyLow)} - ${f0(r.buyHigh)} (ideal ${f0(r.ideal)})');
    b.writeln('Stop: ${f0(r.stop)} | T1: ${f0(r.t1)} | T2: ${f0(r.t2)}');
    for (final s in sigs) {
      b.writeln('${s.ok ? '🟢' : '🔴'} ${s.name}');
    }
    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ringkasan disalin')));
  }

  Widget chip(Signal s) {
    final col = s.ok ? Colors.greenAccent : Colors.redAccent;
    return GestureDetector(
      onTap: () => showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: Text(s.name, style: TextStyle(color: col)),
                content: Text(s.note),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
              )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: col.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: col)),
        child: Text(s.name, style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget fc(String t, bool v, void Function(bool) f) => FilterChip(
      label: Text(t, style: const TextStyle(fontSize: 12)),
      selected: v,
      visualDensity: VisualDensity.compact,
      onSelected: (x) => setState(() => f(x)));

  Widget smcCard(Smc s) {
    final n = data.length;
    final price = s.price;
    const st = TextStyle(fontSize: 13);
    final b = s.breaks.isEmpty ? null : s.breaks.last;
    SmcZone? near(List<SmcZone> l, bool bull) {
      final x = l.where((z) => z.bull == bull).toList();
      if (x.isEmpty) return null;
      x.sort((a, c) => (((a.lo + a.hi) / 2) - price).abs().compareTo((((c.lo + c.hi) / 2) - price).abs()));
      return x.first;
    }

    String zl(SmcZone? z) => z == null ? '-' : '${f0(z.lo)} – ${f0(z.hi)}';
    final up = s.liq.where((q) => q.high && q.p > price).toList()..sort((a, c) => a.p.compareTo(c.p));
    final dn = s.liq.where((q) => !q.high && q.p < price).toList()..sort((a, c) => c.p.compareTo(a.p));
    final su = s.setup;
    final col = s.trend == 1 ? Colors.greenAccent : (s.trend == -1 ? Colors.redAccent : Colors.amber);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Smart Money Concept (SMC)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
              'Struktur: ${s.trendName}'
              '${b == null ? '' : ' • ${b.label} ${b.bull ? 'bullish' : 'bearish'} di ${f0(b.p)} (${n - 1 - b.to} candle lalu)'}',
              style: TextStyle(fontSize: 13, color: col, fontWeight: FontWeight.bold)),
          if (s.pd != null)
            Text('Zona harga: ${s.zoneName} (${s.pd!.toStringAsFixed(0)}% dari range 100 candle, EQ ${f0(s.eq!)})',
                style: st),
          Text('Order Block bullish: ${zl(near(s.obs, true))}', style: st),
          Text('Order Block bearish: ${zl(near(s.obs, false))}', style: st),
          Text('FVG bullish: ${zl(near(s.fvgs, true))}', style: st),
          Text('FVG bearish: ${zl(near(s.fvgs, false))}', style: st),
          Text(
              'Likuiditas: EQH ${up.isEmpty ? '-' : f0(up.first.p)} • EQL ${dn.isEmpty ? '-' : f0(dn.first.p)}',
              style: st),
          if (s.sweep != null) Text(s.sweep!, style: const TextStyle(fontSize: 13, color: Colors.amber)),
          const Divider(height: 18),
          if (su != null) ...[
            Text('Setup ${su.buy ? 'BUY' : 'SELL'} (${su.ref} ${su.buy ? 'bullish' : 'bearish'})',
                style: TextStyle(fontWeight: FontWeight.bold, color: su.buy ? Colors.greenAccent : Colors.redAccent)),
            Text('Zona: ${f0(su.lo)} – ${f0(su.hi)}${su.inZone ? '  (harga sedang di zona)' : ''}', style: st),
            Text('Entry ${f0(su.entry)} (tengah zona${su.inZone ? '' : ', limit order'}) • SL ${f0(su.sl)}', style: st),
            Text('TP1 ${f0(su.tp1)} • TP2 ${f0(su.tp2)} • RR ke TP1 1:${su.rr.toStringAsFixed(1)}', style: st),
            if (su.note.isNotEmpty) Text('Catatan: ${su.note}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
                onPressed: () => calcFx(su: su),
                icon: const Icon(Icons.calculate, size: 18),
                label: const Text('Hitung lot dari setup SMC')),
          ] else
            Text(s.setupNote, style: st),
          const SizedBox(height: 6),
          const Text(
              'Deteksi SMC bersifat heuristik algoritmik (fractal swing 3 candle), bisa berbeda dari tafsir manual. '
              'Gunakan konfirmasi timeframe lebih tinggi. Bukan rekomendasi investasi.',
              style: TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
      ),
    );
  }

  Widget recoCard(Reco r) {
    final sh = fx && short;
    final z = sh ? 'jual' : 'beli';
    final col = r.ratio >= 0.6 ? Colors.greenAccent : (r.ratio >= 0.35 ? Colors.amber : Colors.redAccent);
    final dist = (r.ideal - r.price) / r.price * 100;
    const st = TextStyle(fontSize: 13, height: 1.5);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sh ? 'Rekomendasi Harga Jual (Short)' : 'Rekomendasi Harga Beli', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(r.verdict, style: TextStyle(color: col, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Harga sekarang: ${f0(r.price)}', style: st),
          Text('Zona $z ideal: ${f0(r.buyLow)} – ${f0(r.buyHigh)}', style: st),
          Text('Titik ideal: ${f0(r.ideal)} (${dist.toStringAsFixed(1)}% dari harga sekarang)', style: st),
          if (r.inZone)
            Text('Harga sekarang sudah berada di zona $z.',
                style: const TextStyle(fontSize: 13, color: Colors.greenAccent)),
          if (r.supports.isNotEmpty) Text('Konfluensi ${sh ? 'resistance' : 'support'}: ${r.supports.join(', ')}', style: st),
          Text('Stop loss: ${f0(r.stop)}', style: st),
          Text('Target 1: ${f0(r.t1)}  •  Target 2: ${f0(r.t2)}', style: st),
          Text('Risk:Reward ke Target 1 = 1 : ${r.rr.toStringAsFixed(1)}', style: st),
          Text('${sh ? 'Skor bearish' : 'Skor total'} ${r.score}/${r.total}  (Teknikal ${r.techScore}/${r.techTotal}'
              '${r.fundTotal > 0 ? ', Fundamental ${r.fundScore}/${r.fundTotal}' : (fx ? '' : ', Fundamental belum diisi')})',
              style: st),
          const SizedBox(height: 6),
          Text(
              sh
                  ? 'Dihitung dari konfluensi resistance (MA, Bollinger, Fibonacci, swing high, Ichimoku), '
                      'stop berbasis ATR di atas zona, target ke swing low. Bukan rekomendasi investasi.'
                  : 'Dihitung dari konfluensi support (MA, Bollinger, Fibonacci, swing low, Ichimoku), '
                      'stop berbasis ATR, target dari swing high. Bukan rekomendasi investasi.',
              style: TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
      ),
    );
  }

  Widget panel(String title, double h, CustomPainter p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(title, style: const TextStyle(fontSize: 11, color: Colors.white54))),
          SizedBox(height: h, child: CustomPaint(size: Size.infinite, painter: p)),
        ],
      );

  double _clampOff(double v) {
    final lo = -count * 0.5; // boleh digeser melewati candle terakhir (ruang kosong kanan)
    final hi = math.max(lo, (data.length - count).toDouble());
    return v.clamp(lo, hi).toDouble();
  }

  void _setCount(int c) {
    count = c.clamp(20, data.length).toInt();
    off = _clampOff(off);
  }

  void zoom(double f) => setState(() => _setCount((count * f).round()));

  void _ptrDown(PointerDownEvent e) {
    _ptrs[e.pointer] = e.localPosition;
    if (_ptrs.length == 2) {
      final p = _ptrs.values.toList();
      _pinchDist = (p[0] - p[1]).distance;
      _pinchBase = count;
      setState(() => pinching = true);
    }
  }

  void _ptrMove(PointerMoveEvent e) {
    if (!_ptrs.containsKey(e.pointer)) return;
    _ptrs[e.pointer] = e.localPosition;
    if (_ptrs.length == 2 && _pinchDist > 10) {
      final p = _ptrs.values.toList();
      final dist = (p[0] - p[1]).distance;
      if (dist > 10) setState(() => _setCount((_pinchBase * _pinchDist / dist).round()));
    }
  }

  void _ptrUp(PointerEvent e) {
    _ptrs.remove(e.pointer);
    if (_ptrs.length < 2 && pinching) setState(() => pinching = false);
  }

  Widget chartArea(Indicators i) {
    final n = data.length;
    final r = _range(n);
    final idx = (cross ?? (r[1] - 1)).clamp(0, n - 1).toInt();
    final c = data[idx];
    final info =
        '${fd(c.t)}  O ${f0(c.o)}  H ${f0(c.h)}  L ${f0(c.l)}  C ${f0(c.c)}${fx ? '' : '  Vol ${rp(c.v)}'}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(info, style: const TextStyle(fontSize: 11, color: Colors.white70))),
        IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => zoom(1.4),
            icon: const Icon(Icons.zoom_out)),
        IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => zoom(0.7),
            icon: const Icon(Icons.zoom_in)),
      ]),
      const Text('Geser kiri/kanan • cubit 2 jari untuk zoom • ketuk candle untuk crosshair • MA20 kuning, MA50 biru, MA200 oranye',
          style: TextStyle(fontSize: 10, color: Colors.white38)),
      LayoutBuilder(builder: (ctx, cons) {
        chartW = cons.maxWidth;
        return Listener(
          onPointerDown: _ptrDown,
          onPointerMove: _ptrMove,
          onPointerUp: _ptrUp,
          onPointerCancel: _ptrUp,
          child: GestureDetector(
          onHorizontalDragUpdate: (d) {
            if (pinching) return;
            final cw = chartW / count;
            setState(() => off = _clampOff(off + d.delta.dx / cw));
          },
          onTapUp: (d) {
            final rr = _range(n);
            final cw = chartW / count;
            final k = (rr[0] + (d.localPosition.dx / cw).floor()).clamp(0, n - 1).toInt();
            setState(() => cross = cross == k ? null : k);
          },
          child: SizedBox(
            height: 300,
            child: CustomPaint(
              size: Size.infinite,
              painter: PricePainter(
                  d: data,
                  ind: i,
                  count: count,
                  offset: offset,
                  reco: cur,
                  zoneLabel: (fx && short) ? 'Zona jual' : 'Zona beli',
                  oMA: oMA,
                  oBB: oBB,
                  oSR: oSR,
                  smc: fx ? smc : null,
                  oSMC: oSMC,
                  sr: sr,
                  cross: cross),
            ),
          ),
        ));
      }),
      if (pVol && !fx) panel('Volume', 60, VolPainter(data, count, offset)),
      if (pRSI)
        panel('RSI (14)', 90,
            SubPainter([i.rsi], [Colors.purpleAccent], count, offset,
                guides: const [30, 70], fixMin: 0, fixMax: 100)),
      if (pMACD)
        panel('MACD (12,26,9)  MACD biru, sinyal kuning', 100,
            SubPainter([i.macd, i.macdSig], [Colors.lightBlueAccent, Colors.amber], count, offset,
                hist: i.macdHist)),
      if (pStoch)
        panel('Stochastic (14,3)  %K biru, %D kuning', 90,
            SubPainter([i.stochK, i.stochD], [Colors.lightBlueAccent, Colors.amber], count, offset,
                guides: const [20, 80], fixMin: 0, fixMax: 100)),
      if (pADX)
        panel('ADX putih, +DI hijau, −DI merah', 90,
            SubPainter([i.adx, i.pdi, i.mdi], [Colors.white, Colors.greenAccent, Colors.redAccent],
                count, offset,
                guides: const [20])),
    ]);
  }

  List<int> _range(int n) {
    final end = n - offset;
    return [end - count, end];
  }

  @override
  Widget build(BuildContext context) {
    priceDec = decFor(loadedCode);
    intradayFmt = isIntraday(interval);
    swingOverride = loadedSwing;
    final i = ind;
    final r = cur;
    final tech = sigs.where((s) => !s.fund).toList();
    final fu = sigs.where((s) => s.fund).toList();
    final green = sigs.where((s) => s.ok).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saham Teori (IDX)'),
        actions: [
          IconButton(
              onPressed: i == null ? null : toggleWatch,
              icon: Icon(inWatch ? Icons.star : Icons.star_border, color: inWatch ? Colors.amber : null)),
          IconButton(onPressed: r == null ? null : copySummary, icon: const Icon(Icons.copy)),
          IconButton(onPressed: openSettings, icon: const Icon(Icons.settings)),
        ],
      ),
      body: SafeArea(
        child: ListView(
            padding: const EdgeInsets.all(12),
            physics: pinching ? const NeverScrollableScrollPhysics() : null,
            children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: ctl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Kode saham / pair (BBCA, EURUSD, XAUUSD)',
                    border: OutlineInputBorder(),
                    isDense: true),
                onSubmitted: (_) => load(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: loading ? null : load, child: const Text('Muat')),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final p in forexPairs)
                Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                        label: Text(p, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => loadCode(p))),
            ]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final t in tfList)
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: Text(t[1]),
                        selected: interval == t[0],
                        onSelected: (_) {
                          interval = t[0];
                          load();
                        })),
            ]),
          ),
          if (fx && recoS != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              ChoiceChip(
                  label: const Text('Buy (Long)'),
                  selected: !short,
                  onSelected: (_) => setState(() => short = false)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: const Text('Sell (Short)'),
                  selected: short,
                  onSelected: (_) => setState(() => short = true)),
            ]),
          ],
          if (fx) ...[
            const SizedBox(height: 4),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
              Switch(value: autoOn, onChanged: _setAuto),
              const Text('Auto-refresh'),
              DropdownButton<int>(
                  value: autoSec,
                  isDense: true,
                  items: [
                    for (final s in const [5, 10, 15, 30, 60]) DropdownMenuItem(value: s, child: Text('$s dtk'))
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => autoSec = v);
                    _restartTimer();
                    _syncOverlay();
                  }),
              DropdownButton<int>(
                  value: Settings.ovStep,
                  isDense: true,
                  hint: const Text('Ukuran'),
                  items: [
                    for (var k = 0; k < ovWidths.length; k++)
                      DropdownMenuItem(value: k, child: Text('Ukuran: ${ovNames[k]}'))
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => Settings.ovStep = v);
                    await Settings.save();
                    if (overlayOn) {
                      try {
                        await FlutterOverlayWindow.resizeOverlay(ovWidths[v], ovH(ovWidths[v]), true);
                      } catch (_) {}
                      _syncOverlay();
                    }
                  }),
              OutlinedButton.icon(
                  onPressed: toggleOverlay,
                  icon: Icon(overlayOn ? Icons.picture_in_picture : Icons.picture_in_picture_alt_outlined, size: 18),
                  label: Text(overlayOn ? 'Tutup indikator melayang' : 'Indikator melayang')),
            ]),
            if (autoOn || lastUp != null)
              Text(
                  autoErr ??
                      'Update terakhir ${lastUp == null ? '-' : hms(lastUp!)}${autoOn ? ' • otomatis tiap $autoSec dtk' : ''}',
                  style: TextStyle(fontSize: 11, color: autoErr != null ? Colors.redAccent : Colors.white54)),
          ],
          const SizedBox(height: 8),
          if (loading) const LinearProgressIndicator(),
          if (err != null) Text(err!, style: const TextStyle(color: Colors.redAccent)),
          if (sigs.isNotEmpty) ...[
            Text('Hijau $green / ${sigs.length} teori terpenuhi (ketuk label untuk detail)',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 6),
            const Text('Teknikal', style: TextStyle(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: tech.map(chip).toList()),
            const SizedBox(height: 8),
            if (!fx) const Text('Fundamental (input manual)', style: TextStyle(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 4),
            if (fu.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: fu.map(chip).toList()),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              if (!fx)
                OutlinedButton.icon(
                  onPressed: editFund,
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(fu.isEmpty ? 'Isi fundamental' : 'Ubah fundamental')),
              OutlinedButton.icon(
                  onPressed: calc,
                  icon: const Icon(Icons.calculate, size: 16),
                  label: const Text('Kalkulator posisi')),
              OutlinedButton.icon(
                  onPressed: runBacktest,
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('Backtest')),
              if (!fx)
                OutlinedButton.icon(
                  onPressed: addPortfolio,
                  icon: const Icon(Icons.add_chart, size: 16),
                  label: const Text('Ke portofolio')),
            ]),
            if (r != null) ...[const SizedBox(height: 8), recoCard(r)],
            if (fx && smc != null) ...[const SizedBox(height: 8), smcCard(smc!)],
          ],
          if (i != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              fc('MA', oMA, (v) => oMA = v),
              fc('Bollinger', oBB, (v) => oBB = v),
              fc('S/R', oSR, (v) => oSR = v),
              if (fx) fc('SMC', oSMC, (v) => oSMC = v),
              if (!fx) fc('Volume', pVol, (v) => pVol = v),
              fc('RSI', pRSI, (v) => pRSI = v),
              fc('MACD', pMACD, (v) => pMACD = v),
              fc('Stoch', pStoch, (v) => pStoch = v),
              fc('ADX', pADX, (v) => pADX = v),
            ]),
            const SizedBox(height: 4),
            chartArea(i),
            const SizedBox(height: 12),
            const Text(
                'Hijau = sinyal bullish terpenuhi, merah = tidak terpenuhi/bearish. '
                'Deteksi pola bersifat heuristik, bukan rekomendasi investasi.',
                style: TextStyle(fontSize: 11, color: Colors.white38)),
          ],
        ]),
      ),
    );
  }
}
