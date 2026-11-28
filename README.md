# Saham Teori (IDX)
Build otomatis lewat GitHub Actions saat push ke `main`. APK ditandatangani dengan keystore tetap
(`keystore/saham-teori.jks`) sehingga tiap versi baru bisa MENIMPA versi lama tanpa uninstall.

**Update aplikasi:** tiap build menerbitkan GitHub Release (`v1.0.N`). Di aplikasi: tab Teori -> "Cek pembaruan"
(juga dicek otomatis saat aplikasi dibuka).

**Keystore:** alias `sahamteori`, password bawaan ada di workflow. Untuk lebih aman, buat GitHub Secrets
`KS_PASS` dan `KS_KEYPASS` (workflow otomatis memakainya). JANGAN mengganti/menghapus keystore: kalau berubah,
Android menolak update dan aplikasi harus di-uninstall dulu.

Fitur: grafik candlestick (geser/cubit zoom/crosshair), harian & mingguan, 21 teori teknikal + fundamental
(manual atau otomatis), zona beli ideal + stop + target, kalkulator posisi, backtest, watchlist + alert,
portofolio + notifikasi target untung (latar belakang), screener, IHSG, pengaturan, penjelasan teori.

**Forex & emas:** ketik pair (mis. `EURUSD`, `USDJPY`, `XAUUSD`) atau pilih dari chip di halaman Analisis. Ada mode Buy/Sell, harga desimal, kalkulator lot/pip (modal USD), dan tombol "Forex" di Screener. Data dari Yahoo Finance (tanpa volume).

**Forex live:** saklar Auto-refresh (5-60 dtk) memperbarui grafik & skor tanpa spinner. Tombol "Indikator melayang" menampilkan kartu kecil (harga, BUY/SELL/NETRAL, jumlah teori hijau/merah, zona buy/sell + SL) di atas aplikasi lain; kartu memuat & menganalisis data sendiri sehingga tetap jalan saat aplikasi di latar belakang. Perlu izin "Tampil di atas aplikasi lain".

**SMC (forex):** struktur BOS/CHoCH, Order Block, FVG, EQH/EQL, sweep, premium/discount + setup entry/SL/TP dan kalkulator lot dari setup. Timeframe H4 disusun dari candle 1 jam.
