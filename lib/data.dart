import 'dart:convert';
import 'package:http/http.dart' as http;

class Candle {
  final DateTime t;
  final double o, h, l, c, v;
  Candle(this.t, this.o, this.h, this.l, this.c, this.v);
}

String fd(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${(t.year % 100).toString().padLeft(2, '0')}';

const popular = [
  'BBCA', 'BBRI', 'BMRI', 'BBNI', 'TLKM', 'ASII', 'UNVR', 'ICBP', 'INDF', 'KLBF',
  'ADRO', 'ANTM', 'MDKA', 'GOTO', 'BRIS', 'CPIN', 'EXCL', 'INKP', 'ITMG', 'PGAS',
  'PTBA', 'SMGR', 'TOWR', 'UNTR', 'AMRT', 'ACES', 'ARTO', 'BUKA', 'EMTK', 'HRUM',
  'INCO', 'JSMR', 'MAPI', 'MEDC', 'MIKA', 'SIDO', 'TPIA', 'TBIG', 'AKRA', 'BRPT',
  'ESSA', 'MBMA', 'NCKL', 'AMMN', 'CTRA', 'PGEO',
];

Future<List<Candle>> fetchCandles(String code,
    {String range = '2y', String interval = '1d'}) async {
  final sym = code.startsWith('^') ? code : '$code.JK';
  final url = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(sym)}?range=$range&interval=$interval');
  final r = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
  if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode} (cek kode saham)');
  final j = jsonDecode(r.body);
  final res = j['chart']['result'];
  if (res == null || res.isEmpty) throw Exception('Data tidak ditemukan');
  final ts = res[0]['timestamp'] as List;
  final q = res[0]['indicators']['quote'][0];
  final o = q['open'] as List, h = q['high'] as List, l = q['low'] as List;
  final c = q['close'] as List, v = q['volume'] as List;
  final out = <Candle>[];
  for (var i = 0; i < ts.length; i++) {
    if (o[i] == null || h[i] == null || l[i] == null || c[i] == null) continue;
    out.add(Candle(
        DateTime.fromMillisecondsSinceEpoch((ts[i] as int) * 1000),
        (o[i] as num).toDouble(),
        (h[i] as num).toDouble(),
        (l[i] as num).toDouble(),
        (c[i] as num).toDouble(),
        ((v[i] ?? 0) as num).toDouble()));
  }
  return out;
}
