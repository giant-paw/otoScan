// File: lib/features/transaksi_keluar/data/piutang_pelanggan_repository.dart

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scan_go/core/database/database_helper.dart';

// ─────────────────────────────────────────────────────────────────
// PIUTANG PER-PELANGGAN REPOSITORY
//
// Menjawab pertanyaan: "Siapa saja yang punya hutang & berapa?"
//
// Query mengelompokkan hutang per pelanggan, jadi owner bisa lihat:
//   - Pak Budi: total Rp 350.000 dari 2 nota
//   - Bu Siti: total Rp 75.000 dari 1 nota
//
// Beda dengan piutang_repository (yang per-nota), ini per-ORANG.
// ─────────────────────────────────────────────────────────────────

class PiutangPelangganRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // ─────────────────────────────────────────────────────────────
  // DAFTAR PELANGGAN YANG PUNYA HUTANG (dikelompokkan)
  //
  // Return per pelanggan: nama, hp, total hutang, jumlah nota,
  // nota tertua (untuk indikator umur).
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> daftarPelangganBerhutang() async {
    final db = await _db;

    // Group by pelanggan_id, tapi handle juga yang pelanggan_id null
    // (pakai nama snapshot sebagai fallback grouping)
    final rows = await db.rawQuery('''
      SELECT
        h.pelanggan_id,
        COALESCE(p.nama, h.nama_pelanggan_snapshot) AS nama,
        COALESCE(p.no_hp, h.no_hp_snapshot)         AS no_hp,
        SUM(h.sisa_hutang)                          AS total_hutang,
        COUNT(*)                                    AS jumlah_nota,
        MIN(h.tanggal)                              AS nota_tertua,
        MAX(h.tanggal)                              AS nota_terbaru
      FROM transaksi_keluar_header h
      LEFT JOIN pelanggan p ON h.pelanggan_id = p.id
      WHERE h.status = 'HUTANG' AND h.sisa_hutang > 0
      GROUP BY h.pelanggan_id, nama
      ORDER BY total_hutang DESC
    ''');

    return rows.map((r) => {
      'pelangganId':  r['pelanggan_id'] as int?,
      'nama':         (r['nama'] as String?) ?? '(Tanpa Nama)',
      'noHp':         r['no_hp'] as String?,
      'totalHutang':  (r['total_hutang'] as int?) ?? 0,
      'jumlahNota':   (r['jumlah_nota'] as int?) ?? 0,
      'notaTertua':   r['nota_tertua'] as String?,
      'notaTerbaru':  r['nota_terbaru'] as String?,
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // DETAIL NOTA HUTANG SATU PELANGGAN
  //
  // Semua nota yang belum lunas dari pelanggan tertentu.
  // Kalau pelangganId null, cari by nama snapshot.
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> notaHutangPelanggan({
    int? pelangganId,
    String? namaSnapshot,
  }) async {
    final db = await _db;

    List<Map<String, Object?>> rows;

    if (pelangganId != null) {
      rows = await db.rawQuery('''
        SELECT no_nota, tanggal, jam, total_tagihan, total_dibayar,
               sisa_hutang, status
        FROM transaksi_keluar_header
        WHERE pelanggan_id = ? AND status = 'HUTANG' AND sisa_hutang > 0
        ORDER BY tanggal ASC
      ''', [pelangganId]);
    } else {
      rows = await db.rawQuery('''
        SELECT no_nota, tanggal, jam, total_tagihan, total_dibayar,
               sisa_hutang, status
        FROM transaksi_keluar_header
        WHERE nama_pelanggan_snapshot = ? AND pelanggan_id IS NULL
          AND status = 'HUTANG' AND sisa_hutang > 0
        ORDER BY tanggal ASC
      ''', [namaSnapshot ?? '']);
    }

    return rows.map((r) => {
      'noNota':       r['no_nota'] as String,
      'tanggal':      r['tanggal'] as String,
      'jam':          r['jam'] as String,
      'totalTagihan': (r['total_tagihan'] as int?) ?? 0,
      'totalDibayar': (r['total_dibayar'] as int?) ?? 0,
      'sisaHutang':   (r['sisa_hutang'] as int?) ?? 0,
      'status':       r['status'] as String,
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // RIWAYAT LENGKAP PELANGGAN (termasuk yang sudah lunas)
  //
  // Untuk lihat "track record" pelanggan: pernah hutang berapa,
  // sudah lunas berapa. Berguna untuk menilai pelanggan.
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> riwayatLengkapPelanggan(int pelangganId) async {
    final db = await _db;

    final agg = await db.rawQuery('''
      SELECT
        COUNT(*)                                              AS total_transaksi,
        COALESCE(SUM(total_tagihan), 0)                       AS total_belanja,
        COALESCE(SUM(CASE WHEN status='HUTANG' THEN sisa_hutang ELSE 0 END), 0) AS hutang_aktif,
        COUNT(CASE WHEN status='LUNAS' THEN 1 END)            AS nota_lunas,
        COUNT(CASE WHEN status='HUTANG' THEN 1 END)           AS nota_hutang
      FROM transaksi_keluar_header
      WHERE pelanggan_id = ?
    ''', [pelangganId]);

    final semuaNota = await db.rawQuery('''
      SELECT no_nota, tanggal, jam, total_tagihan, sisa_hutang, status
      FROM transaksi_keluar_header
      WHERE pelanggan_id = ?
      ORDER BY tanggal DESC, jam DESC
    ''', [pelangganId]);

    final a = agg.first;
    return {
      'totalTransaksi': (a['total_transaksi'] as int?) ?? 0,
      'totalBelanja':   (a['total_belanja'] as int?) ?? 0,
      'hutangAktif':    (a['hutang_aktif'] as int?) ?? 0,
      'notaLunas':      (a['nota_lunas'] as int?) ?? 0,
      'notaHutang':     (a['nota_hutang'] as int?) ?? 0,
      'semuaNota':      semuaNota.map((r) => {
        'noNota':       r['no_nota'] as String,
        'tanggal':      r['tanggal'] as String,
        'jam':          r['jam'] as String,
        'totalTagihan': (r['total_tagihan'] as int?) ?? 0,
        'sisaHutang':   (r['sisa_hutang'] as int?) ?? 0,
        'status':       r['status'] as String,
      }).toList(),
    };
  }
}