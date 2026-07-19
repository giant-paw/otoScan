// File: lib/features/dashboard/data/dashboard_repository.dart

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scan_go/core/database/database_helper.dart';

// ─────────────────────────────────────────────────────────────────
// DASHBOARD REPOSITORY — data ringkasan untuk halaman pembuka
//
// Mengumpulkan:
//   - Ringkasan hari ini (omzet, laba, transaksi, item)
//   - Peringatan (stok menipis, stok habis, piutang overdue)
//   - Top barang bulan ini
//   - Transaksi terakhir
//
// Semua query ringan & pakai index → dashboard load cepat.
// ─────────────────────────────────────────────────────────────────

class DashboardRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  static const int _batasStokMenipis = 5; // stok <= 5 dianggap menipis

  String _fmtDB(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  // ─────────────────────────────────────────────────────────────
  // RINGKASAN HARI INI
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, int>> ringkasanHariIni() async {
    final db = await _db;
    final today = _fmtDB(DateTime.now());

    final headerAgg = await db.rawQuery('''
      SELECT
        COALESCE(SUM(total_tagihan), 0) AS omzet,
        COALESCE(SUM(total_laba), 0)    AS laba,
        COALESCE(SUM(total_dibayar), 0) AS tunai,
        COALESCE(SUM(sisa_hutang), 0)   AS hutang_baru,
        COUNT(*)                        AS jumlah_nota
      FROM transaksi_keluar_header
      WHERE tanggal = ?
    ''', [today]);

    final itemAgg = await db.rawQuery('''
      SELECT COALESCE(SUM(d.qty), 0) AS jumlah_item
      FROM transaksi_keluar_detail d
      JOIN transaksi_keluar_header h ON d.no_nota = h.no_nota
      WHERE h.tanggal = ?
    ''', [today]);

    final h = headerAgg.first;
    return {
      'omzet':       (h['omzet'] as int?) ?? 0,
      'laba':        (h['laba'] as int?) ?? 0,
      'tunai':       (h['tunai'] as int?) ?? 0,
      'hutangBaru':  (h['hutang_baru'] as int?) ?? 0,
      'jumlahNota':  (h['jumlah_nota'] as int?) ?? 0,
      'jumlahItem':  (itemAgg.first['jumlah_item'] as int?) ?? 0,
    };
  }

  // ─────────────────────────────────────────────────────────────
  // PERINGATAN: hitung stok menipis, habis, piutang
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> peringatan() async {
    final db = await _db;

    // Stok habis (= 0)
    final habisAgg = await db.rawQuery('''
      SELECT COUNT(*) AS jumlah
      FROM master_barang
      WHERE stok_sisa = 0
    ''');

    // Stok menipis (1 s/d batas)
    final menipisAgg = await db.rawQuery('''
      SELECT COUNT(*) AS jumlah
      FROM master_barang
      WHERE stok_sisa > 0 AND stok_sisa <= ?
    ''', [_batasStokMenipis]);

    // Total piutang aktif
    final piutangAgg = await db.rawQuery('''
      SELECT
        COALESCE(SUM(sisa_hutang), 0) AS total,
        COUNT(*)                      AS jumlah_nota
      FROM transaksi_keluar_header
      WHERE status = 'HUTANG' AND sisa_hutang > 0
    ''');

    // Piutang overdue (> 30 hari)
    final batas30 = _fmtDB(DateTime.now().subtract(const Duration(days: 30)));
    final overdueAgg = await db.rawQuery('''
      SELECT
        COALESCE(SUM(sisa_hutang), 0) AS total,
        COUNT(*)                      AS jumlah_nota
      FROM transaksi_keluar_header
      WHERE status = 'HUTANG' AND sisa_hutang > 0 AND tanggal <= ?
    ''', [batas30]);

    return {
      'stokHabis':        (habisAgg.first['jumlah'] as int?) ?? 0,
      'stokMenipis':      (menipisAgg.first['jumlah'] as int?) ?? 0,
      'piutangTotal':     (piutangAgg.first['total'] as int?) ?? 0,
      'piutangNota':      (piutangAgg.first['jumlah_nota'] as int?) ?? 0,
      'overdueTotal':     (overdueAgg.first['total'] as int?) ?? 0,
      'overdueNota':      (overdueAgg.first['jumlah_nota'] as int?) ?? 0,
    };
  }

  // ─────────────────────────────────────────────────────────────
  // DAFTAR BARANG STOK MENIPIS (untuk detail kalau diklik)
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> barangStokMenipis({int limit = 20}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT kode_scan, nama_barang, kategori, stok_sisa
      FROM master_barang
      WHERE stok_sisa <= ?
      ORDER BY stok_sisa ASC, nama_barang ASC
      LIMIT ?
    ''', [_batasStokMenipis, limit]);

    return rows.map((r) => {
      'kodeScan':   r['kode_scan'] as String,
      'namaBarang': r['nama_barang'] as String,
      'kategori':   r['kategori'] as String,
      'stokSisa':   (r['stok_sisa'] as int?) ?? 0,
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // TOP BARANG BULAN INI
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> topBarangBulanIni({int limit = 5}) async {
    final db = await _db;
    final now = DateTime.now();
    final awalBulan = _fmtDB(DateTime(now.year, now.month, 1));
    final hariIni = _fmtDB(now);

    final rows = await db.rawQuery('''
      SELECT
        d.nama_barang,
        d.kategori,
        SUM(d.qty)            AS total_qty,
        SUM(d.subtotal_laba)  AS total_laba
      FROM transaksi_keluar_detail d
      JOIN transaksi_keluar_header h ON d.no_nota = h.no_nota
      WHERE h.tanggal >= ? AND h.tanggal <= ?
      GROUP BY d.kode_scan, d.nama_barang, d.kategori
      ORDER BY total_qty DESC
      LIMIT ?
    ''', [awalBulan, hariIni, limit]);

    return rows.map((r) => {
      'namaBarang': r['nama_barang'] as String,
      'kategori':   r['kategori'] as String,
      'totalQty':   (r['total_qty'] as int?) ?? 0,
      'totalLaba':  (r['total_laba'] as int?) ?? 0,
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // TRANSAKSI TERAKHIR
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> transaksiTerakhir({int limit = 6}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        no_nota, tanggal, jam, total_tagihan, sisa_hutang, status,
        nama_pelanggan_snapshot
      FROM transaksi_keluar_header
      ORDER BY tanggal DESC, jam DESC
      LIMIT ?
    ''', [limit]);

    return rows.map((r) => {
      'noNota':        r['no_nota'] as String,
      'tanggal':       r['tanggal'] as String,
      'jam':           r['jam'] as String,
      'totalTagihan':  (r['total_tagihan'] as int?) ?? 0,
      'sisaHutang':    (r['sisa_hutang'] as int?) ?? 0,
      'status':        r['status'] as String,
      'namaPelanggan': r['nama_pelanggan_snapshot'] as String?,
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // TREN 7 HARI TERAKHIR (untuk mini grafik)
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> tren7Hari() async {
    final db = await _db;
    final now = DateTime.now();
    final awal = _fmtDB(now.subtract(const Duration(days: 6)));
    final akhir = _fmtDB(now);

    final rows = await db.rawQuery('''
      SELECT
        tanggal,
        COALESCE(SUM(total_tagihan), 0) AS omzet
      FROM transaksi_keluar_header
      WHERE tanggal >= ? AND tanggal <= ?
      GROUP BY tanggal
      ORDER BY tanggal ASC
    ''', [awal, akhir]);

    // Buat map tanggal → omzet
    final Map<String, int> omzetMap = {
      for (final r in rows) r['tanggal'] as String: (r['omzet'] as int?) ?? 0
    };

    // Isi 7 hari lengkap (termasuk yang omzet 0)
    final List<Map<String, dynamic>> hasil = [];
    for (int i = 6; i >= 0; i--) {
      final tgl = now.subtract(Duration(days: i));
      final tglStr = _fmtDB(tgl);
      hasil.add({
        'tanggal': tglStr,
        'hari': tgl.day,
        'omzet': omzetMap[tglStr] ?? 0,
      });
    }
    return hasil;
  }

  // ─────────────────────────────────────────────────────────────
  // JUMLAH MASTER BARANG (info umum)
  // ─────────────────────────────────────────────────────────────
  Future<int> jumlahMasterBarang() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) AS jumlah FROM master_barang');
    return (r.first['jumlah'] as int?) ?? 0;
  }
}
