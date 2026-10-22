import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'service.dart';
import 'store.dart';
import 'theories.dart';

class PortfolioPage extends StatefulWidget {
  final void Function(String) onOpen;
  const PortfolioPage({super.key, required this.onOpen});
  @override
  State<PortfolioPage> createState() => PortfolioPageState();
}

class PortfolioPageState extends State<PortfolioPage> {
  List<Holding> hs = [];
  final Map<String, Quick> res = {};
  bool loading = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    hs = await Store.holdings();
    if (mounted) setState(() {});
    for (var k = 0; k < hs.length; k += 4) {
      final part = hs.skip(k).take(4).toList();
      await Future.wait(part.map((h) async {
        try {
          res[h.code] = await quick(h.code);
        } catch (_) {}
      }));
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> addDialog() async {
    final code = TextEditingController();
    final lot = TextEditingController(text: '1');
    final avg = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Tambah posisi'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Kode saham', isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 8),
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
    final c = code.text.trim().toUpperCase().replaceAll('.JK', '');
    final l = int.tryParse(lot.text.trim());
    final a = double.tryParse(avg.text.trim().replaceAll(',', '.'));
    if (c.isEmpty || l == null || l <= 0 || a == null || a <= 0) return;
    final list = await Store.holdings();
    final k = list.indexWhere((h) => h.code == c);
    if (k >= 0) {
      final h = list[k];
      final tl = h.lots + l;
      list[k] = Holding(c, tl, (h.avg * h.lots + a * l) / tl);
    } else {
      list.add(Holding(c, l, a));
    }
    await Store.setHoldings(list);
    await refresh();
  }

  Future<void> remove(Holding h) async {
    final list = await Store.holdings();
    list.removeWhere((e) => e.code == h.code);
    await Store.setHoldings(list);
    res.remove(h.code);
    setState(() => hs = list);
  }

  void copyCsv() {
    final b = StringBuffer('kode,lot,harga_beli,harga_sekarang,pl_rp,pl_persen\n');
    for (final h in hs) {
      final q = res[h.code];
      if (q == null) continue;
      final cost = h.lots * 100 * h.avg;
      final pl = h.lots * 100 * q.price - cost;
      b.writeln('${h.code},${h.lots},${f0(h.avg)},${f0(q.price)},${f0(pl)},${(pl / cost * 100).toStringAsFixed(2)}');
    }
    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV disalin')));
  }

  @override
  Widget build(BuildContext context) {
    var cost = 0.0, value = 0.0;
    for (final h in hs) {
      final q = res[h.code];
      cost += h.lots * 100 * h.avg;
      value += h.lots * 100 * (q?.price ?? h.avg);
    }
    final pl = value - cost;
    final plc = pl >= 0 ? Colors.greenAccent : Colors.redAccent;
    return Scaffold(
      appBar: AppBar(title: const Text('Portofolio'), actions: [
        IconButton(onPressed: hs.isEmpty ? null : copyCsv, icon: const Icon(Icons.copy)),
        IconButton(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh)),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: addDialog, child: const Icon(Icons.add)),
      body: SafeArea(
        child: Column(children: [
          if (loading) const LinearProgressIndicator(),
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Modal: Rp ${rp(cost)}'),
                Text('Nilai sekarang: Rp ${rp(value)}'),
                Text('P/L: Rp ${rp(pl)}  (${cost == 0 ? '0.0' : (pl / cost * 100).toStringAsFixed(2)}%)',
                    style: TextStyle(color: plc, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          Expanded(
            child: hs.isEmpty
                ? const Center(
                    child: Text('Belum ada posisi.\nTekan + atau "Ke portofolio" di halaman Analisis.',
                        textAlign: TextAlign.center))
                : ListView(children: [
                    for (final h in hs) _row(h),
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                            'Level stop/target di sini hasil perhitungan teknikal aplikasi, bukan perintah jual/beli. '
                            'Harga bisa tertunda dan belum termasuk fee/pajak.',
                            style: TextStyle(fontSize: 11, color: Colors.white38))),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(Holding h) {
    final q = res[h.code];
    if (q == null) {
      return ListTile(
          title: Text('${h.code}  ${h.lots} lot'),
          subtitle: const Text('Memuat...'),
          trailing: IconButton(onPressed: () => remove(h), icon: const Icon(Icons.delete_outline)));
    }
    final cost = h.lots * 100 * h.avg;
    final pl = h.lots * 100 * q.price - cost;
    final col = pl >= 0 ? Colors.greenAccent : Colors.redAccent;
    final r = q.reco;
    final status = q.price <= r.stop
        ? '⚠ Di bawah level stop hasil analisis (${f0(r.stop)})'
        : q.price >= r.t2
            ? '🎯 Mencapai Target 2 (${f0(r.t2)})'
            : q.price >= r.t1
                ? '🎯 Mencapai Target 1 (${f0(r.t1)})'
                : r.inZone
                    ? 'Harga di zona beli analisis'
                    : '';
    return ListTile(
      onTap: () => widget.onOpen(h.code),
      title: Text('${h.code}  •  ${h.lots} lot', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
          'Avg ${rp(h.avg)} → ${rp(q.price)}\nP/L Rp ${rp(pl)} (${(pl / cost * 100).toStringAsFixed(2)}%)'
          '${status.isEmpty ? '' : '\n$status'}',
          style: TextStyle(color: col, fontSize: 12)),
      isThreeLine: true,
      trailing: IconButton(onPressed: () => remove(h), icon: const Icon(Icons.delete_outline)),
    );
  }
}
