import 'package:flutter/material.dart';
import 'updater.dart';

const _items = <List<String>>[
  ['Dow Theory', 'Tren dikonfirmasi oleh puncak dan lembah yang makin tinggi.', 'Hijau jika pivot terakhir membentuk higher high dan higher low (swing 5%).'],
  ['Elliott Wave', 'Tren naik bergerak dalam 5 gelombang dorongan dan 3 gelombang koreksi.', 'Hijau jika gelombang 1-4 memenuhi aturan: gel.2 tidak di bawah awal, gel.3 lebih panjang dari gel.1, gel.4 tidak overlap gel.1. Heuristik sederhana.'],
  ['Fibonacci Retracement', 'Koreksi sering berhenti di 38,2%, 50%, 61,8% dari swing sebelumnya.', 'Hijau jika harga berada di zona 38,2–61,8% dan candle terakhir naik.'],
  ['Wyckoff (Akumulasi)', 'Smart money mengakumulasi saat harga bergerak sempit sebelum naik.', 'Hijau jika rentang 40 candle <15% dan OBV naik.'],
  ['Candlestick Bullish', 'Pola candle tertentu menandakan pembalikan naik.', 'Hijau jika candle terakhir Bullish Engulfing atau Hammer.'],
  ['Double Bottom', 'Dua dasar sejajar lalu tembus neckline menandakan pembalikan naik.', 'Hijau jika dua dasar terakhir beda <3% dan harga di atas neckline.'],
  ['Inverse Head & Shoulders', 'Tiga dasar dengan tengah terendah, tembus neckline = pembalikan naik.', 'Hijau jika bahu kiri-kanan beda <6%, head terendah, harga di atas neckline.'],
  ['Golden Cross', 'MA50 memotong ke atas MA200 menandakan tren naik jangka panjang.', 'Hijau jika MA50 > MA200.'],
  ['Ichimoku Cloud', 'Harga di atas awan menandakan tren naik.', 'Hijau jika harga di atas batas atas awan (Senkou A/B).'],
  ['RSI', 'Mengukur momentum; >70 jenuh beli, <30 jenuh jual.', 'Hijau jika RSI 50–70 atau memantul dari bawah 30.'],
  ['MACD', 'Selisih EMA12 dan EMA26 terhadap garis sinyal.', 'Hijau jika MACD di atas sinyal dan histogram menguat.'],
  ['Stochastic', 'Posisi penutupan relatif terhadap rentang 14 candle.', 'Hijau jika %K di atas %D dan %K < 80.'],
  ['Bollinger Bands', 'Pita volatilitas di sekitar MA20.', 'Hijau jika harga di atas middle band tetapi belum menembus upper band.'],
  ['ADX / DI', 'Mengukur kekuatan tren (ADX) dan arahnya (+DI/−DI).', 'Hijau jika ADX>20 dan +DI > −DI.'],
  ['Konfirmasi Volume', 'Kenaikan harga lebih dipercaya bila disertai volume besar.', 'Hijau jika volume ≥1,2x rata-rata 20 candle dan harga naik.'],
  ['Breakout Resistance', 'Penutupan di atas high sebelumnya menandakan kelanjutan naik.', 'Hijau jika close di atas high tertinggi 20 candle sebelumnya.'],
  ['PER / PBV', 'Valuasi relatif terhadap laba dan nilai buku.', 'Input manual. Hijau jika PER 0–15 dan PBV <2 (bandingkan dengan sektor).'],
  ['ROE / DER / Dividen / Pertumbuhan Laba', 'Profitabilitas, leverage, imbal hasil dividen, dan pertumbuhan.', 'Input manual. Hijau jika ROE ≥10%, DER <1x, dividend yield ≥2%, pertumbuhan laba >0%.'],
  ['Morning Star / Three White Soldiers', 'Pola 3 candle pembalikan/penguatan naik.', 'Bagian dari label Candlestick Bullish.'],
  ['Parabolic SAR', 'Titik stop-and-reverse mengikuti tren.', 'Hijau jika harga di atas SAR.'],
  ['CCI', 'Mengukur penyimpangan harga dari rata-rata.', 'Hijau jika CCI 0–200 dan menguat, atau memantul dari bawah -100.'],
  ['MFI (Money Flow)', 'RSI berbobot volume; mengukur aliran dana.', 'Hijau jika MFI 50–80 atau memantul dari bawah 20.'],
  ['Ascending Triangle', 'Resistance datar dengan dasar makin tinggi, rawan breakout.', 'Hijau jika dua high selisih <1,5%, dasar naik, dan harga ≥97% resistance.'],
  ['Relative Strength vs IHSG', 'Saham yang lebih kuat dari indeks cenderung memimpin.', 'Hijau jika return 60 candle terakhir lebih besar dari IHSG.'],
  ['Backtest', 'Menguji aturan pada data historis saham yang sedang dibuka.', 'Beli saat ≥60% teori teknikal hijau, jual saat <35%, stop 2 ATR, target 3 ATR, maks 40 candle, fee 0,4%. Hasil lalu tidak menjamin masa depan.'],
  ['Portofolio & Alert', 'Catat posisi dan pantau harga.', 'Alert harga dicek saat Watchlist dibuka. Notifikasi target portofolio (ikon lonceng di Portofolio) dicek otomatis di latar belakang kira-kira tiap 15 menit.'],
  ['Forex: Pip, Lot, Leverage', 'Pair = nilai satu mata uang terhadap yang lain. 1 pip = 0,0001 (0,01 untuk pair JPY, 0,1 untuk emas). 1 lot standar = 100.000 unit. Leverage memperbesar untung sekaligus rugi.', 'Kalkulator posisi forex menghitung lot dari modal (USD), % risiko, dan jarak stop dalam pip. Nilai pip pair silang dikonversi otomatis ke USD.'],
  ['Forex: Buy & Sell', 'Di forex kamu bisa untung dari harga naik (buy) maupun turun (sell/short).', 'Mode Sell memakai cermin logika beli: zona jual = konfluensi resistance (MA, Bollinger atas, Fibonacci, swing high, bawah awan Ichimoku), stop di atas zona, target ke swing low. Skor Sell = jumlah teori yang merah. Heuristik, bukan rekomendasi.'],
  ['Forex: Sesi & Volume', 'Pasar buka 24 jam Senin-Jumat; sesi London dan New York paling aktif.', 'Data forex Yahoo Finance tidak punya volume asli, jadi Wyckoff, Konfirmasi Volume, MFI, Relative Strength IHSG, dan fundamental dinonaktifkan untuk forex. Harga bisa tertunda. Timeframe 1 menit s/d 1 jam tersedia (batas data Yahoo: 1m ±5 hari, 5-30m ±60 hari, 1j ±6 bulan). Untuk forex & timeframe kecil, ambang swing dihitung otomatis dari rata-rata rentang candle.'],
  ['Forex: Auto-refresh & Melayang', 'Auto-refresh memperbarui data tiap beberapa detik; indikator melayang tampil di atas aplikasi broker.', 'Kartu melayang: harga, BUY/SELL/NETRAL (BUY jika >=60% teori hijau, SELL jika <=40%), jumlah teori hijau/merah, zona buy & sell beserta stop. Data Yahoo tertunda; refresh terlalu rapat bisa terkena batas permintaan. Bukan rekomendasi.'],
  ['Harga Beli Ideal', 'Area di mana beberapa support bertemu (konfluensi).', 'Dari MA20/50/200, Bollinger, Fibonacci, swing low, awan Ichimoku. Zona ±0,5 ATR, stop 1 ATR di bawah zona, target dari swing high.'],
];

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Penjelasan Teori')),
      body: SafeArea(
        child: ListView(children: [
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('Cek pembaruan aplikasi'),
            subtitle: const Text('Unduh & pasang versi terbaru langsung dari dalam aplikasi'),
            onTap: () => Updater.checkAndPrompt(context),
          ),
          const Divider(height: 1),
          for (final it in _items)
            ExpansionTile(
              title: Text(it[0]),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it[1]),
                const SizedBox(height: 6),
                Text('Aturan di aplikasi: ${it[2]}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'Analisis teknikal bersifat probabilistik. Aplikasi ini alat bantu edukasi, bukan rekomendasi investasi. Data dari Yahoo Finance bisa tertunda.',
                style: TextStyle(fontSize: 12, color: Colors.white38)),
          ),
        ]),
      ),
    );
  }
}
