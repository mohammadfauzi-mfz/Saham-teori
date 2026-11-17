import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const _repo = 'mohammadfauzi-mfz/Saham-teori';

class UpdateInfo {
  final int build;
  final String name, url, notes;
  UpdateInfo(this.build, this.name, this.url, this.notes);
}

class Updater {
  /// Cek rilis terbaru di GitHub. Mengembalikan null jika sudah versi terbaru.
  static Future<UpdateInfo?> check() async {
    final r = await http.get(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'});
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final tag = (j['tag_name'] ?? '') as String; // contoh: v1.0.42 -> build 42
    final build = int.tryParse(tag.split('.').last) ?? 0;
    final cur = int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
    if (build <= cur) return null;
    final assets = (j['assets'] as List?) ?? [];
    final apk = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['name'] as String).endsWith('.apk'),
        orElse: () => {});
    final url = apk['browser_download_url'] as String?;
    if (url == null) return null;
    return UpdateInfo(build, tag, url, (j['body'] ?? '') as String);
  }

  /// Unduh APK lalu buka installer Android (update menimpa aplikasi lama, data tetap).
  static Future<void> downloadAndInstall(UpdateInfo u, void Function(double) onProgress) async {
    final client = http.Client();
    try {
      final resp = await client.send(http.Request('GET', Uri.parse(u.url)));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/saham-teori-update.apk');
      final sink = f.openWrite();
      var got = 0;
      final total = resp.contentLength ?? 0;
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress(got / total);
      }
      await sink.close();
      final res = await OpenFilex.open(f.path, type: 'application/vnd.android.package-archive');
      if (res.type != ResultType.done) throw Exception(res.message);
    } finally {
      client.close();
    }
  }

  /// Cek + tampilkan dialog. [silent] = true: tidak menampilkan apa pun bila sudah terbaru / gagal.
  static Future<void> checkAndPrompt(BuildContext context, {bool silent = false}) async {
    final msg = ScaffoldMessenger.of(context);
    UpdateInfo? u;
    try {
      u = await check();
    } catch (e) {
      if (!silent) msg.showSnackBar(SnackBar(content: Text('Gagal cek pembaruan: $e')));
      return;
    }
    if (u == null) {
      if (!silent) msg.showSnackBar(const SnackBar(content: Text('Sudah versi terbaru')));
      return;
    }
    if (!context.mounted) return;
    final info = u;
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UpdateDialog(info));
  }
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo u;
  const _UpdateDialog(this.u);
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? prog;
  String? err;

  Future<void> go() async {
    setState(() {
      prog = 0;
      err = null;
    });
    try {
      await Updater.downloadAndInstall(widget.u, (p) {
        if (mounted) setState(() => prog = p);
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          prog = null;
          err = 'Gagal: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = prog != null;
    return AlertDialog(
      title: Text('Pembaruan tersedia (${widget.u.name})'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.u.notes.trim().isNotEmpty) Text(widget.u.notes.trim(), maxLines: 8, overflow: TextOverflow.ellipsis),
        if (busy) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: prog == 0 ? null : prog),
        ],
        if (err != null) Text(err!, style: const TextStyle(color: Colors.redAccent)),
        const SizedBox(height: 8),
        const Text('Data portofolio & watchlist tetap aman. Jika diminta, izinkan "Install aplikasi tidak dikenal".',
            style: TextStyle(fontSize: 11, color: Colors.white54)),
      ]),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Nanti')),
        FilledButton(onPressed: busy ? null : go, child: const Text('Update sekarang')),
      ],
    );
  }
}
