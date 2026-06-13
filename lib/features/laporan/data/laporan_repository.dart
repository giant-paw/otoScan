// File: lib/features/laporan/data/laporan_repository.dart

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scan_go/core/database/database_helper.dart';

// ─────────────────────────────────────────────────────────────────
// LAPORAN REPOSITORY — semua query agregasi untuk laporan
//
// Sumber data:
//   - transaksi_keluar_header  → omzet, laba, hutang
//   - transaksi_keluar_detail  → top barang, laporan per kategori
//   - transaksi_masuk          → barang masuk
//   - master_barang            → stok, modal tidak berputar
//
// Semua query pakai index dari database_helper v2 → cepat.
// ─────────────────────────────────────────────────────────────────

class LaporanRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // ── RINGKASAN PERIODE (KPI utama) ────────────────────────────
  Future<Map<String, int>> ringkasanPeriode({
    required String dari,
    required String sampai,
  }) async {
    final db = await _db;

    final headerAgg = await db.rawQuery('''
      SELECT
        COALESCE(SUM(total_tagihan), 0) AS omzet,
        COALESCE(SUM(total_laba), 0)    AS total_laba,
        COALESCE(SUM(total_modal), 0)   AS total_modal,
        COALESCE(SUM(total_dibayar), 0) AS total_dibayar,
        COALESCE(SUM(sisa_hutang), 0)   AS total_hutang_baru,
        COUNT(*)                        AS jumlah_nota
      FROM transaksi_keluar_header
      WHERE tanggal >= ? AND tanggal <= ?
    ''', [dari, sampai]);

    final itemAgg = await db.rawQuery('''
      SELECT COALESCE(SUM(d.qty), 0) AS jumlah_item
      FROM transaksi_keluar_detail d
      JOIN transaksi_keluar_header h ON d.no_nota = h.no_nota
      WHERE h.tanggal >= ? AND h.tanggal <= ?
    ''', [dari, sampai]);

    final h = headerAgg.first;
    final omzet = (h['omzet'] as int?) ?? 0;
    final jumlahNota = (h['jumlah_nota'] as int?) ?? 0;

    return {
      'omzet':            omzet,
      'totalLaba':        (h['total_laba'] as int?) ?? 0,
      'totalModal':       (h['total_modal'] as int?) ?? 0,
      'totalDibayar':     (h['total_dibayar'] as int?) ?? 0,
      'totalHutangBaru':  (h['total_hutang_baru'] as int?) ?? 0,
      'jumlahNota':       jumlahNota,
      'jumlahItem':       (itemAgg.first['jumlah_item'] as int?) ?? 0,
      'rataRataPerNota':  jumlahNota > 0 ? (omzet ~/ jumlahNota) : 0,
    };
  }

  // ── TOP BARANG TERLARIS ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> topBarangTerlaris({
    required String dari,
    required String sampai,
    int limit = 10,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        d.kode_scan,
        d.nama_barang,
        d.kategori,
        SUM(d.qty)            AS total_qty,
        SUM(d.subtotal_jual)  AS total_omzet,
        SUM(d.subtotal_laba)  AS total_laba
      FROM transaksi_keluar_detail d
      JOIN transaksi_keluar_header h ON d.no_nota = h.no_nota
      WHERE h.tanggal >= ? AND h.tanggal <= ?
      GROUP BY d.kode_scan, d.nama_barang, d.kategori
      ORDER BY total_qty DESC
      LIMIT ?
    ''', [dari, sampai, limit]);

    return rows.map((r) => {
      'kodeScan':   r['kode_scan'] as String,
      'namaBarang': r['nama_barang'] as String,
      'kategori':   r['kategori'] as String,
      'totalQty':   (r['total_qty'] as int?) ?? 0,
      'totalOmzet': (r['total_omzet'] as int?) ?? 0,
      'totalLaba':  (r['total_laba'] as int?) ?? 0,
    }).toList();
  }

  // ── OMZET HARIAN (untuk grafik tren) ─────────────────────────
  Future<List<Map<String, dynamic>>> omzetHarian({
    required String dari,
    required String sampai,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        tanggal,
        COALESCE(SUM(total_tagihan), 0) AS omzet,
        COALESCE(SUM(total_laba), 0)    AS laba,
        COUNT(*)                        AS jumlah_nota
      FROM transaksi_keluar_header
      WHERE tanggal >= ? AND tanggal <= ?
      GROUP BY tanggal
      ORDER BY tanggal ASC
    ''', [dari, sampai]);

    return rows.map((r) => {
      'tanggal':    r['tanggal'] as String,
      'omzet':      (r['omzet'] as int?) ?? 0,
      'laba':       (r['laba'] as int?) ?? 0,
      'jumlahNota': (r['jumlah_nota'] as int?) ?? 0,
    }).toList();
  }

  // ── LAPORAN PER KATEGORI (untuk Excel) ───────────────────────
  Future<List<Map<String, dynamic>>> laporanPerKategori({
    required String kategori,
    required String dari,
    required String sampai,
  }) async {
    final db = await _db;

    final barangRows = await db.query(
      'master_barang',
      where: 'kategori = ?',
      whereArgs: [kategori],
      orderBy: 'nama_barang ASC',
    );

    final List<Map<String, dynamic>> hasil = [];

    for (final b in barangRows) {
      final kode = b['kode_scan'] as String;

      final masukAgg = await db.rawQuery('''
        SELECT COALESCE(SUM(qty), 0) AS qty_masuk
        FROM transaksi_masuk
        WHERE kode_scan = ? AND tanggal >= ? AND tanggal <= ?
      ''', [kode, dari, sampai]);

      final keluarAgg = await db.rawQuery('''
        SELECT COALESCE(SUM(d.qty), 0) AS qty_keluar
        FROM transaksi_keluar_detail d
        JOIN transaksi_keluar_header h ON d.no_nota = h.no_nota
        WHERE d.kode_scan = ? AND h.tanggal >= ? AND h.tanggal <= ?
      ''', [kode, dari, sampai]);

      final qtyMasuk  = (masukAgg.first['qty_masuk'] as int?) ?? 0;
      final qtyKeluar = (keluarAgg.first['qty_keluar'] as int?) ?? 0;
      final stokSisa = (b['stok_sisa'] as int?) ?? 0;

      // Skip kalau benar-benar tidak ada aktivitas & stok 0
      if (qtyMasuk == 0 && qtyKeluar == 0 && stokSisa == 0) continue;

      hasil.add({
        'kodeScan':   kode,
        'namaBarang': b['nama_barang'] as String,
        'qtyMasuk':   qtyMasuk,
        'hargaAstra': (b['harga_astra'] as int?) ?? 0,
        'qtyKeluar':  qtyKeluar,
        'hargaJual':  (b['harga_jual'] as int?) ?? 0,
        'stokSisa':   stokSisa,
      });
    }

    return hasil;
  }

  // ── RINGKASAN PER KATEGORI (pie chart) ───────────────────────
  Future<List<Map<String, dynamic>>> ringkasanPerKategori({
    required String dari,
    required String sampai,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        d.kategori,
        SUM(d.qty)            AS total_qty,
        SUM(d.subtotal_jual)  AS total_omzet,
        SUM(d.subtotal_laba)  AS total_laba
      FROM transaksi_keluar_detail d
      JOIN transaksi_keluar_header h ON d.no_nota = h.no_nota
      WHERE h.tanggal >= ? AND h.tanggal <= ?
      GROUP BY d.kategori
      ORDER BY total_omzet DESC
    ''', [dari, sampai]);

    return rows.map((r) => {
      'kategori':   r['kategori'] as String,
      'totalQty':   (r['total_qty'] as int?) ?? 0,
      'totalOmzet': (r['total_omzet'] as int?) ?? 0,
      'totalLaba':  (r['total_laba'] as int?) ?? 0,
    }).toList();
  }

  // ── MODAL TIDAK BERPUTAR ─────────────────────────────────────
  Future<Map<String, int>> modalTidakBerputar({
    required String dari,
    required String sampai,
  }) async {
    final db = await _db;

    final totalStok = await db.rawQuery('''
      SELECT COALESCE(SUM(stok_sisa * harga_astra), 0) AS total
      FROM master_barang
    ''');

    final tidakLaku = await db.rawQuery('''
      SELECT COALESCE(SUM(mb.stok_sisa * mb.harga_astra), 0) AS total
      FROM master_barang mb
      WHERE mb.stok_sisa > 0
        AND mb.kode_scan NOT IN (
          SELECT DISTINCT d.kode_scan
          FROM transaksi_keluar_detail d
          JOIN transaksi_keluar_header h ON d.no_nota = h.no_nota
          WHERE h.tanggal >= ? AND h.tanggal <= ?
        )
    ''', [dari, sampai]);

    return {
      'totalModalStok': (totalStok.first['total'] as int?) ?? 0,
      'modalTidakLaku': (tidakLaku.first['total'] as int?) ?? 0,
    };
  }

  // ── TOTAL PIUTANG AKTIF (semua waktu) ────────────────────────
  Future<int> totalPiutangAktif() async {
    final db = await _db;
    final r = await db.rawQuery('''
      SELECT COALESCE(SUM(sisa_hutang), 0) AS total
      FROM transaksi_keluar_header
      WHERE status = 'HUTANG' AND sisa_hutang > 0
    ''');
    return (r.first['total'] as int?) ?? 0;
  }

  // ── DAFTAR KATEGORI ──────────────────────────────────────────
  Future<List<String>> daftarKategori() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT DISTINCT kategori FROM master_barang ORDER BY kategori
    ''');
    return rows.map((r) => r['kategori'] as String).toList();
  }
}
