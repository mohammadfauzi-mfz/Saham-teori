import 'dart:convert';
import 'package:http/http.dart' as http;

class Candle {
  final DateTime t;
  final double o, h, l, c, v;
  Candle(this.t, this.o, this.h, this.l, this.c, this.v);
}

/// true saat timeframe intraday aktif: tanggal ditampilkan beserta jam (diatur oleh halaman Analisis).
bool intradayFmt = false;

String fd(DateTime t) {
  final dd =
      '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${(t.year % 100).toString().padLeft(2, '0')}';
  if (!intradayFmt) return dd;
  return '${dd.substring(0, 5)} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// [kode Yahoo, label, range data]. Batas Yahoo: 1m maks 7 hari, 5-30m maks 60 hari, 60m maks 730 hari.
const tfList = [
  ['1m', '1 mnt', '5d'],
  ['5m', '5 mnt', '30d'],
  ['15m', '15 mnt', '60d'],
  ['30m', '30 mnt', '60d'],
  ['60m', '1 jam', '6mo'],
  ['1d', 'Harian', '2y'],
  ['1wk', 'Mingguan', '5y'],
];
String rangeFor(String iv) => tfList.firstWhere((e) => e[0] == iv, orElse: () => tfList[5])[2];
String tfLabel(String iv) => tfList.firstWhere((e) => e[0] == iv, orElse: () => tfList[5])[1];
bool isIntraday(String iv) => iv.endsWith('m');

const popular = [
  'BBCA', 'BBRI', 'BMRI', 'BBNI', 'TLKM', 'ASII', 'UNVR', 'ICBP', 'INDF', 'KLBF',
  'ADRO', 'ANTM', 'MDKA', 'GOTO', 'BRIS', 'CPIN', 'EXCL', 'INKP', 'ITMG', 'PGAS',
  'PTBA', 'SMGR', 'TOWR', 'UNTR', 'AMRT', 'ACES', 'ARTO', 'BUKA', 'EMTK', 'HRUM',
  'INCO', 'JSMR', 'MAPI', 'MEDC', 'MIKA', 'SIDO', 'TPIA', 'TBIG', 'AKRA', 'BRPT',
  'ESSA', 'MBMA', 'NCKL', 'AMMN', 'CTRA', 'PGEO',
];

const forexPairs = [
  'EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCAD', 'USDCHF', 'NZDUSD',
  'EURJPY', 'GBPJPY', 'EURGBP', 'AUDJPY', 'XAUUSD', 'USDIDR',
];
const _ccy = {'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'NZD', 'CAD', 'CHF', 'IDR', 'SGD', 'CNY', 'HKD', 'MYR'};
bool _isPair(String c) => c.length == 6 && _ccy.contains(c.substring(0, 3)) && _ccy.contains(c.substring(3));

/// Pair mata uang atau emas/perak (bukan saham IDX).
bool isForex(String c) => c == 'XAUUSD' || c == 'XAGUSD' || c.endsWith('=X') || _isPair(c);

String yahooSym(String code) {
  if (code.startsWith('^') || code.contains('=')) return code;
  if (code == 'XAUUSD') return 'GC=F';
  if (code == 'XAGUSD') return 'SI=F';
  if (_isPair(code)) return '$code=X';
  return '$code.JK';
}

/// Jumlah desimal harga untuk tampilan.
int decFor(String code) {
  if (!isForex(code)) return 0;
  if (code.contains('JPY')) return 3;
  if (code.startsWith('XAU') || code.startsWith('XAG') || code.contains('IDR')) return 2;
  return 5;
}

double pipSize(String code) =>
    code.contains('JPY') ? 0.01 : (code.startsWith('XAU') ? 0.1 : (code.contains('IDR') ? 1.0 : 0.0001));

double contractSize(String code) => code.startsWith('XAU') ? 100 : 100000;

/// Nilai 1 unit mata uang kuotasi dalam USD (untuk konversi nilai pip). null jika gagal.
Future<double?> usdPerQuote(String code, double price) async {
  if (code.startsWith('XAU') || code.startsWith('XAG')) return 1;
  final s = code.replaceAll('=X', '');
  if (s.length < 6) return null;
  final base = s.substring(0, 3), quote = s.substring(3, 6);
  if (quote == 'USD') return 1;
  if (base == 'USD') return price > 0 ? 1 / price : null;
  try {
    final c = await fetchCandles('USD$quote', range: '5d');
    if (c.isNotEmpty && c.last.c > 0) return 1 / c.last.c;
  } catch (_) {}
  try {
    final c = await fetchCandles('${quote}USD', range: '5d');
    if (c.isNotEmpty) return c.last.c;
  } catch (_) {}
  return null;
}

Future<List<Candle>> fetchCandles(String code,
    {String range = '2y', String interval = '1d'}) async {
  final sym = yahooSym(code);
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
