import 'dart:convert';
import 'package:http/http.dart' as http;
import 'store.dart';

double? _raw(dynamic m, String k) {
  if (m is Map) {
    final v = m[k];
    if (v is Map) return (v['raw'] as num?)?.toDouble();
  }
  return null;
}

/// Mengambil data fundamental dari Yahoo Finance (butuh cookie + crumb).
/// Tidak resmi dan bisa gagal sewaktu-waktu; hasil selalu perlu diperiksa.
Future<Fund> fetchFund(String code) async {
  const ua = {'User-Agent': 'Mozilla/5.0'};
  final r1 = await http.get(Uri.parse('https://fc.yahoo.com'), headers: ua);
  final sc = r1.headers['set-cookie'] ?? '';
  final m = RegExp(r'A3=[^;]+').firstMatch(sc);
  if (m == null) throw Exception('cookie tidak didapat');
  final cookie = m.group(0)!;
  final r2 = await http.get(
      Uri.parse('https://query1.finance.yahoo.com/v1/test/getcrumb'),
      headers: {...ua, 'Cookie': cookie});
  final crumb = r2.body.trim();
  if (r2.statusCode != 200 || crumb.isEmpty || crumb.contains('<')) {
    throw Exception('crumb tidak didapat');
  }
  final url = Uri.parse(
      'https://query1.finance.yahoo.com/v10/finance/quoteSummary/$code.JK'
      '?modules=summaryDetail,defaultKeyStatistics,financialData&crumb=${Uri.encodeComponent(crumb)}');
  final r3 = await http.get(url, headers: {...ua, 'Cookie': cookie});
  if (r3.statusCode != 200) throw Exception('HTTP ${r3.statusCode}');
  final j = jsonDecode(r3.body);
  final res = j['quoteSummary']['result'];
  if (res == null || res.isEmpty) throw Exception('data kosong');
  final sd = res[0]['summaryDetail'];
  final ks = res[0]['defaultKeyStatistics'];
  final fd = res[0]['financialData'];
  final roe = _raw(fd, 'returnOnEquity');
  final der = _raw(fd, 'debtToEquity');
  final dy = _raw(sd, 'dividendYield');
  final gr = _raw(fd, 'earningsGrowth');
  return Fund(
      per: _raw(sd, 'trailingPE'),
      pbv: _raw(ks, 'priceToBook'),
      roe: roe == null ? null : roe * 100,
      der: der == null ? null : der / 100,
      dy: dy == null ? null : dy * 100,
      growth: gr == null ? null : gr * 100);
}
