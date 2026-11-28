import 'package:flutter/material.dart';
import 'data.dart';
import 'deriv.dart';
import 'notifier.dart';
import 'signals.dart';

class SignalsPage extends StatefulWidget {
  const SignalsPage({super.key});
  @override
  State<SignalsPage> createState() => _SignalsPageState();
}

class _SignalsPageState extends State<SignalsPage> {
  List<SigRule> rules = [];
  bool on = false, smc = false, busy = false;
  final code = TextEditingController();
  String iv = '15m';
  final res = <String, String>{};

  @override
  void initState() {
    super.initState();
    () async {
      rules = await Signals.rules();
      on = await Signals.on();
      if (mounted) setState(() {});
    }();
  }

  Future<void> save() async {
    await Signals.setRules(rules);
    await Notifier.reschedule();
  }

  Future<void> toggle(bool v) async {
    setState(() => on = v);
    await Signals.setOn(v);
    if (v) await Notifier.requestPermission();
    await Notifier.reschedule();
  }

  Future<void> add() async {
    final c = code.text.trim().toUpperCase();
    if (c.isEmpty) return;
    if (rules.any((r) => r.key == '$c|$iv')) return;
    setState(() {
      rules.add(SigRule(c, iv, smc));
      code.clear();
    });
    await save();
  }

  Future<void> testAll() async {
    setState(() => busy = true);
    for (final r in rules) {
      try {
        final x = await evalSignal(r.code, r.iv);
        res[r.key] = '${x.verdict} (${x.bull}/${x.total} hijau)';
      } catch (e) {
        res[r.key] = 'gagal: ${e.toString().replaceAll('Exception: ', '')}';
      }
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi Sinyal')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktifkan notifikasi sinyal'),
              subtitle: const Text('Dicek di latar belakang tiap ±15 menit. Notifikasi hanya saat sinyal BERUBAH ke BUY atau SELL.'),
              value: on,
              onChanged: toggle),
          const Divider(),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Kode (BBCA, XAUUSD, EURUSD, R_10...)', border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 8),
            DropdownButton<String>(
                value: iv,
                items: [for (final t in tfList) DropdownMenuItem(value: t[0], child: Text(t[1]))],
                onChanged: (v) => setState(() => iv = v ?? iv)),
          ]),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Juga beri tahu saat harga masuk zona setup SMC'),
              value: smc,
              onChanged: (v) => setState(() => smc = v ?? false)),
          Row(children: [
            FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('Tambah')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: busy || rules.isEmpty ? null : testAll, child: Text(busy ? 'Memeriksa...' : 'Cek sekarang')),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 6, children: [
            for (final p in [...forexPairs.take(4), 'XAUUSD', ...derivSymbols.take(2).map((e) => e[0])])
              ActionChip(visualDensity: VisualDensity.compact, label: Text(p, style: const TextStyle(fontSize: 12)), onPressed: () => code.text = p),
          ]),
          const Divider(height: 24),
          if (rules.isEmpty) const Text('Belum ada aturan. Tambahkan kode dan timeframe di atas.', style: TextStyle(color: Colors.white54)),
          for (final r in rules)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${r.code} • ${tfLabel(r.iv)}${r.smc ? ' • +SMC' : ''}'),
              subtitle: res[r.key] == null ? null : Text(res[r.key]!),
              trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    setState(() => rules.remove(r));
                    await save();
                  }),
            ),
          const SizedBox(height: 8),
          const Text(
              'BUY = ≥60% teori hijau, SELL = ≤40%. Pengecekan latar belakang Android minimal ±15 menit sehingga tidak realtime; '
              'timeframe 1–5 menit bisa terlewat. Aplikasi perlu diizinkan berjalan di latar belakang (nonaktifkan penghemat baterai untuk aplikasi ini). '
              'Bukan rekomendasi investasi.',
              style: TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
      ),
    );
  }
}
