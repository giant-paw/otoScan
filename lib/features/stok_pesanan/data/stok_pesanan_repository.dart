// File: lib/features/stok_pesanan/data/stok_pesanan_repository.dart

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scan_go/core/database/database_helper.dart';

// ─────────────────────────────────────────────────────────────────
// STOK & PESANAN REPOSITORY
//
// Menjawab:
//   1. Barang apa saja yang kosong / menipis / banyak (filter stok)
//   2. Saran barang yang perlu dipesan (berdasar penjualan 30 hari)
//   3. Data untuk export daftar pesanan ke Excel
//
// Logika saran pesan:
//   - Lihat penjualan 30 hari terakhir per barang
//   - Kalau stok <= batas & barang LAKU → saran pesan
//   - Barang tidak laku (30 hari 0 terjual) TIDAK disaran pesan
//     (supaya modal tidak menumpuk di barang mati)
// ─────────────────────────────────────────────────────────────────

enum FilterStok { semua, habis, menipis, banyak }

class StokPesananRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  static const int batasMenipis = 5;   // stok 1..5 = menipis
  static const int batasBanyak  = 20;  // stok > 20 = banyak

  String _fmtDB(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  // ─────────────────────────────────────────────────────────────
  // DAFTAR STOK (dengan filter)
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> daftarStok(FilterStok filter) async {
    final db = await _db;

    String where;
    switch (filter) {
      case FilterStok.habis:   where = 'stok_sisa = 0'; break;
      case FilterStok.menipis: where = 'stok_sisa > 0 AND stok_sisa <= $batasMenipis'; break;
      case FilterStok.banyak:  where = 'stok_sisa > $batasBanyak'; break;
      case FilterStok.semua:   where = '1=1'; break;
    }

    final rows = await db.rawQuery('''
      SELECT kode_scan, nama_barang, kategori, stok_sisa, harga_astra, harga_jual
      FROM master_barang
      WHERE $where
      ORDER BY stok_sisa ASC, nama_barang ASC
    ''');

    return rows.map((r) => {
      'kodeScan':   r['kode_scan'] as String,
      'namaBarang': r['nama_barang'] as String,
      'kategori':   r['kategori'] as String,
      'stokSisa':   (r['stok_sisa'] as int?) ?? 0,
      'hargaAstra': (r['harga_astra'] as int?) ?? 0,
      'hargaJual':  (r['harga_jual'] as int?) ?? 0,
    }).toList();
  }

  // ── Hitung jumlah per kategori filter (untuk badge tab) ──────
  Future<Map<String, int>> hitungStok() async {
    final db = await _db;
    final r = await db.rawQuery('''
      SELECT
        COUNT(*)                                                   AS semua,
        COUNT(CASE WHEN stok_sisa = 0 THEN 1 END)                  AS habis,
        COUNT(CASE WHEN stok_sisa > 0 AND stok_sisa <= $batasMenipis THEN 1 END) AS menipis,
        COUNT(CASE WHEN stok_sisa > $batasBanyak THEN 1 END)       AS banyak
      FROM master_barang
    ''');
    final a = r.first;
    return {
      'semua':   (a['semua'] as int?) ?? 0,
      'habis':   (a['habis'] as int?) ?? 0,
      'menipis': (a['menipis'] as int?) ?? 0,
      'banyak':  (a['banyak'] as int?) ?? 0,
    };
  }

  // ─────────────────────────────────────────────────────────────
  // SARAN PESANAN — barang yang perlu dipesan
  //
  // Return per barang:
  //   kode, nama, kategori, stokSisa, terjual30, saranQty,
  //   hargaAstra, estimasiBiaya, prioritas
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> saranPesanan() async {
    final db = await _db;
    final now = DateTime.now();
    final awal30 = _fmtDB(now.subtract(const Duration(days: 30)));
    final hariIni = _fmtDB(now);

    // Ambil barang stok menipis/habis + penjualan 30 hari
    final rows = await db.rawQuery('''
      SELECT
        mb.kode_scan,
        mb.nama_barang,
        mb.kategori,
        mb.stok_sisa,
        mb.harga_astra,
        COALESCE((
          SELECT SUM(d.qty)
          FROM transaksi_keluar_detail d
          JOIN transaksi_keluar_header h ON d.no_nota = h.no_nota
          WHERE d.kode_scan = mb.kode_scan
            AND h.tanggal >= ? AND h.tanggal <= ?
        ), 0) AS terjual30
      FROM master_barang mb
      WHERE mb.stok_sisa <= $batasMenipis
      ORDER BY mb.stok_sisa ASC
    ''', [awal30, hariIni]);

    final List<Map<String, dynamic>> hasil = [];

    for (final r in rows) {
      final stokSisa  = (r['stok_sisa'] as int?) ?? 0;
      final terjual30 = (r['terjual30'] as int?) ?? 0;
      final hargaAstra = (r['harga_astra'] as int?) ?? 0;

      // Barang tidak laku 30 hari → jangan saran pesan (hemat modal)
      if (terjual30 == 0) continue;

      // Saran: cukup untuk ~1.5 bulan penjualan, dikurangi stok sekarang
      final target = (terjual30 * 1.5).ceil();
      final saranQty = (target - stokSisa).clamp(1, 999999);

      String prioritas;
      if (stokSisa == 0) {
        prioritas = 'TINGGI';   // habis & laku → mendesak
      } else if (stokSisa <= 2) {
        prioritas = 'SEDANG';
      } else {
        prioritas = 'RENDAH';
      }

      hasil.add({
        'kodeScan':      r['kode_scan'] as String,
        'namaBarang':    r['nama_barang'] as String,
        'kategori':      r['kategori'] as String,
        'stokSisa':      stokSisa,
        'terjual30':     terjual30,
        'saranQty':      saranQty,
        'hargaAstra':    hargaAstra,
        'estimasiBiaya': saranQty * hargaAstra,
        'prioritas':     prioritas,
      });
    }

    // Urutkan: prioritas TINGGI dulu, lalu terjual terbanyak
    hasil.sort((a, b) {
      const urutan = {'TINGGI': 0, 'SEDANG': 1, 'RENDAH': 2};
      final pa = urutan[a['prioritas']] ?? 3;
      final pb = urutan[b['prioritas']] ?? 3;
      if (pa != pb) return pa.compareTo(pb);
      return (b['terjual30'] as int).compareTo(a['terjual30'] as int);
    });

    return hasil;
  }

  // ── Ringkasan pesanan (total item & estimasi biaya) ──────────
  Future<Map<String, int>> ringkasanPesanan() async {
    final saran = await saranPesanan();
    int totalItem = saran.length;
    int totalBiaya = saran.fold(0, (s, e) => s + (e['estimasiBiaya'] as int));
    int totalQty = saran.fold(0, (s, e) => s + (e['saranQty'] as int));
    return {
      'totalItem':  totalItem,
      'totalQty':   totalQty,
      'totalBiaya': totalBiaya,
    };
  }
}