import 'package:flutter/material.dart';
import 'data.dart';
import 'service.dart';
import 'signals_page.dart';
import 'store.dart';
import 'theories.dart';

Color scoreColor(double ratio) =>
    ratio >= 0.6 ? Colors.greenAccent : (ratio >= 0.35 ? Colors.amber : Colors.redAccent);

Widget quickTile(Quick q, VoidCallback onTap, {Widget? trailing}) {
  priceDec = decFor(q.code);
  final col = scoreColor(q.ratio);
  final up = q.chg >= 0;
  return ListTile(
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: col.withOpacity(0.2),
      child: Text('${q.reco.score}/${q.reco.total}', style: TextStyle(color: col, fontSize: 11)),
    ),
    title: Text(q.code, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text(
        '${isForex(q.code) ? f0(q.price) : 'Rp ${rp(q.price)}'}  ${up ? '+' : ''}${q.chg.toStringAsFixed(2)}%'
        '${q.reco.inZone ? '  •  DI ZONA BELI' : '  •  zona ${f0(q.reco.buyLow)}–${f0(q.reco.buyHigh)}'}',
        style: TextStyle(color: q.reco.inZone ? Colors.greenAccent : null, fontSize: 12)),
    trailing: trailing,
  );
}

class WatchlistPage extends StatefulWidget {
  final void Function(String) onOpen;
  const WatchlistPage({super.key, required this.onOpen});
  @override
  State<WatchlistPage> createState() => WatchlistPageState();
}

class WatchlistPageState extends State<WatchlistPage> {
  List<String> codes = [];
  List<Alert> alerts = [];
  final List<String> triggered = [];
  final Map<String, Quick> res = {};
  final Map<String, String> errs = {};
  Quick? ihsg;
  bool loading = false;
  final add = TextEditingController();

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    codes = await Store.watch();
    try {
      ihsg = await quick('^JKSE');
    } catch (_) {}
    if (mounted) setState(() {});
    for (var k = 0; k < codes.length; k += 4) {
      final part = codes.skip(k).take(4).toList();
      await Future.wait(part.map((c) async {
        try {
          res[c] = await quick(c);
          errs.remove(c);
        } catch (e) {
          errs[c] = '$e';
        }
      }));
      if (mounted) setState(() {});
    }
    await checkAlerts();
    if (mounted) setState(() => loading = false);
  }

  Future<void> checkAlerts() async {
    final all = await Store.alerts();
    final keep = <Alert>[];
    for (final a in all) {
      final q = res[a.code];
      if (q == null) {
        keep.add(a);
        continue;
      }
      final hit = a.above ? q.price >= a.price : q.price <= a.price;
      if (hit) {
        triggered.add('${a.code} ${a.above ? 'naik ke' : 'turun ke'} ${f0(q.price)} (alert ${f0(a.price)})');
      } else {
        keep.add(a);
      }
    }
    await Store.setAlerts(keep);
    alerts = keep;
  }

  Future<void> addCode() async {
    final c = add.text.trim().toUpperCase().replaceAll('.JK', '');
    if (c.isEmpty) return;
    final w = await Store.watch();
    if (!w.contains(c)) w.add(c);
    await Store.setWatch(w);
    add.clear();
    await refresh();
  }

  Future<void> remove(String c) async {
    final w = await Store.watch();
    w.remove(c);
    await Store.setWatch(w);
    res.remove(c);
    setState(() => codes = w);
  }

  Future<void> addAlert(String c) async {
    final q = res[c];
    final pc = TextEditingController(text: q == null ? '' : f0(q.price));
    var above = true;
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                  title: Text('Alert harga $c'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: pc,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Harga', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 8),
                    Row(children: [
                      ChoiceChip(
                          label: const Text('Naik ke ≥'),
                          selected: above,
                          onSelected: (_) => set(() => above = true)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                          label: const Text('Turun ke ≤'),
                          selected: !above,
                          onSelected: (_) => set(() => above = false)),
                    ]),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
                  ],
                )));
    if (ok != true) return;
    final v = double.tryParse(pc.text.trim().replaceAll(',', '.'));
    if (v == null) return;
    final al = await Store.alerts();
    al.add(Alert(c, v, above));
    await Store.setAlerts(al);
    setState(() => alerts = al);
  }

  Future<void> removeAlert(Alert a) async {
    final al = await Store.alerts();
    al.removeWhere((e) => e.code == a.code && e.price == a.price && e.above == a.above);
    await Store.setAlerts(al);
    setState(() => alerts = al);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Watchlist'), actions: [
        IconButton(
            tooltip: 'Notifikasi sinyal',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignalsPage())),
            icon: const Icon(Icons.notifications_active_outlined)),
        IconButton(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh)),
      ]),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: add,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      labelText: 'Tambah kode saham', border: OutlineInputBorder(), isDense: true),
                  onSubmitted: (_) => addCode(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: addCode, child: const Text('Tambah')),
            ]),
          ),
          if (loading) const LinearProgressIndicator(),
          if (triggered.isNotEmpty)
            Card(
              color: Colors.amber.withOpacity(0.15),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Alert harga terpicu', style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final t in triggered) Text(t),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: () => setState(() => triggered.clear()), child: const Text('Tutup'))),
                ]),
              ),
            ),
          Expanded(
            child: ListView(children: [
              if (ihsg != null) quickTile(ihsg!, () => widget.onOpen('^JKSE')),
              if (codes.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: Text('Belum ada saham.\nTambahkan di sini atau ketuk ★ di halaman Analisis.',
                            textAlign: TextAlign.center))),
              for (final c in codes)
                if (res[c] != null)
                  quickTile(res[c]!, () => widget.onOpen(c),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            onPressed: () => addAlert(c),
                            icon: Icon(alerts.any((a) => a.code == c)
                                ? Icons.notifications_active
                                : Icons.notifications_none)),
                        IconButton(onPressed: () => remove(c), icon: const Icon(Icons.delete_outline)),
                      ]))
                else
                  ListTile(
                    title: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(errs[c] ?? 'Memuat...',
                        style: TextStyle(color: errs[c] != null ? Colors.redAccent : null, fontSize: 12)),
                    trailing: IconButton(onPressed: () => remove(c), icon: const Icon(Icons.delete_outline)),
                  ),
              if (alerts.isNotEmpty) ...[
                const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Alert aktif (dicek saat halaman ini disegarkan)',
                        style: TextStyle(fontSize: 12, color: Colors.white54))),
                for (final a in alerts)
                  ListTile(
                    dense: true,
                    title: Text('${a.code} ${a.above ? '≥' : '≤'} ${f0(a.price)}'),
                    trailing: IconButton(onPressed: () => removeAlert(a), icon: const Icon(Icons.close)),
                  ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class ScreenerPage extends StatefulWidget {
  final void Function(String) onOpen;
  const ScreenerPage({super.key, required this.onOpen});
  @override
  State<ScreenerPage> createState() => _ScreenerPageState();
}

class _ScreenerPageState extends State<ScreenerPage> {
  final List<Quick> results = [];
  bool running = false;
  int done = 0;
  bool onlyZone = false;
  int sortMode = 0;

  void _sort() {
    results.sort((a, b) {
      if (sortMode == 1) {
        final da = (a.price - a.reco.ideal).abs() / a.price;
        final db = (b.price - b.reco.ideal).abs() / b.price;
        return da.compareTo(db);
      }
      if (sortMode == 2) return b.chg.compareTo(a.chg);
      return b.ratio.compareTo(a.ratio);
    });
  }

  int total = popular.length;

  Future<void> scan([List<String>? src]) async {
    final list = src ?? popular;
    setState(() {
      running = true;
      done = 0;
      total = list.length;
      results.clear();
    });
    for (var k = 0; k < list.length; k += 5) {
      final part = list.skip(k).take(5).toList();
      await Future.wait(part.map((c) async {
        try {
          results.add(await quick(c));
        } catch (_) {}
        done++;
      }));
      if (!mounted) return;
      setState(_sort);
    }
    if (mounted) setState(() => running = false);
  }

  @override
  Widget build(BuildContext context) {
    final list = results.where((q) => !onlyZone || q.reco.inZone).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Screener')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              FilledButton.icon(
                  onPressed: running ? null : scan,
                  icon: const Icon(Icons.radar),
                  label: const Text('Pindai saham populer')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: running ? null : () => scan(forexPairs), child: const Text('Forex')),
              const SizedBox(width: 12),
              if (running || done > 0) Text('$done/$total'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(spacing: 8, children: [
              for (final e in const ['Skor tertinggi', 'Terdekat zona beli', 'Naik hari ini'].asMap().entries)
                ChoiceChip(
                    label: Text(e.value, style: const TextStyle(fontSize: 12)),
                    selected: sortMode == e.key,
                    onSelected: (_) => setState(() {
                          sortMode = e.key;
                          _sort();
                        })),
            ]),
          ),
          SwitchListTile(
              dense: true,
              title: const Text('Hanya yang harganya di zona beli'),
              value: onlyZone,
              onChanged: (v) => setState(() => onlyZone = v)),
          if (running) const LinearProgressIndicator(),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text('Tekan "Pindai" untuk meranking ${popular.length} saham populer\n'
                        'berdasarkan jumlah teori yang terpenuhi.',
                        textAlign: TextAlign.center))
                : ListView(children: [for (final q in list) quickTile(q, () => widget.onOpen(q.code))]),
          ),
        ]),
      ),
    );
  }
}
