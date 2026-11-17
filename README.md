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
