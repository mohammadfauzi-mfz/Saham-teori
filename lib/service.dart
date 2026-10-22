import 'data.dart';
import 'indicators.dart';
import 'store.dart';
import 'theories.dart';

class Quick {
  final String code;
  final double price, chg;
  final Reco reco;
  Quick(this.code, this.price, this.chg, this.reco);
  double get ratio => reco.ratio;
}

final Map<String, List<Candle>> _idx = {};

Future<List<Candle>?> indexCandles(String interval) async {
  if (_idx.containsKey(interval)) return _idx[interval];
  try {
    final d = await fetchCandles('^JKSE',
        range: interval == '1d' ? '2y' : '5y', interval: interval);
    _idx[interval] = d;
    return d;
  } catch (_) {
    return null;
  }
}

Future<Quick> quick(String code) async {
  final d = await fetchCandles(code);
  if (d.length < 80) throw Exception('Data kurang');
  final x = Indicators(d);
  final f = await Store.fund(code);
  final idxc = await indexCandles('1d');
  final s = analyze(d, x, f, idx: idxc);
  final r = recommend(d, x, s);
  final chg = (d.last.c / d[d.length - 2].c - 1) * 100;
  return Quick(code, d.last.c, chg, r);
}
