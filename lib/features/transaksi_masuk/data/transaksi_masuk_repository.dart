import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../../core/database/database_helper.dart';
import 'transaksi_masuk_model.dart';

class TransaksiMasukRepository {
  final _db = DatabaseHelper.instance;

  // ─────────────────────────────────────────────────────────────────
  // SIMPAN: Insert transaksi + update stok dalam satu transaksi atomik
  // Kembalikan true jika sukses, false jika gagal (stok tidak cukup
  // tidak relevan di masuk, tapi bisa ditambahkan validasi lain)
  // ─────────────────────────────────────────────────────────────────
  Future<bool> simpan(TransaksiMasuk t) async {
    final db = await _db.database;

    try {
      await db.transaction((txn) async {
        // 1. Catat transaksi
        await txn.insert('transaksi_masuk', t.toMap());

        // 2. Tambah stok di master_barang — atomik dalam transaksi yang sama
        await txn.rawUpdate(
          'UPDATE master_barang SET stok_sisa = stok_sisa + ? WHERE kode_scan = ?',
          [t.qty, t.kodeScan],
        );
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // HAPUS: Hapus satu transaksi + kembalikan stok (rollback manual)
  // Dipakai saat admin salah scan di sesi yang sama
  // ─────────────────────────────────────────────────────────────────
  Future<bool> hapus(int id, String kodeScan, int qty) async {
    final db = await _db.database;

    try {
      await db.transaction((txn) async {
        await txn.delete(
          'transaksi_masuk',
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.rawUpdate(
          'UPDATE master_barang SET stok_sisa = stok_sisa - ? WHERE kode_scan = ?',
          [qty, kodeScan],
        );
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // RIWAYAT HARI INI: JOIN ke master_barang untuk nama & kategori
  // ─────────────────────────────────────────────────────────────────
  Future<List<TransaksiMasuk>> getRiwayatHariIni() async {
    final db = await _db.database;

    final tanggalHariIni = DateTime.now().toIso8601String().substring(0, 10);

    final rows = await db.rawQuery(
      '''
      SELECT
        tm.id,
        tm.kode_scan,
        tm.qty,
        tm.harga_astra_satuan,
        tm.tanggal,
        tm.jam,
        mb.nama_barang,
        mb.kategori
      FROM transaksi_masuk tm
      LEFT JOIN master_barang mb ON tm.kode_scan = mb.kode_scan
      WHERE tm.tanggal = ?
      ORDER BY tm.id DESC
      ''',
      [tanggalHariIni],
    );

    return rows.map(TransaksiMasuk.fromMap).toList();
  }

  // ─────────────────────────────────────────────────────────────────
  // RIWAYAT RENTANG TANGGAL: Untuk fitur laporan nanti
  // ─────────────────────────────────────────────────────────────────
  Future<List<TransaksiMasuk>> getRiwayatRentang(
    String dari,
    String sampai,
  ) async {
    final db = await _db.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        tm.id,
        tm.kode_scan,
        tm.qty,
        tm.harga_astra_satuan,
        tm.tanggal,
        tm.jam,
        mb.nama_barang,
        mb.kategori
      FROM transaksi_masuk tm
      LEFT JOIN master_barang mb ON tm.kode_scan = mb.kode_scan
      WHERE tm.tanggal BETWEEN ? AND ?
      ORDER BY tm.tanggal DESC, tm.id DESC
      ''',
      [dari, sampai],
    );

    return rows.map(TransaksiMasuk.fromMap).toList();
  }

  // ─────────────────────────────────────────────────────────────────
  // CEK STOK SAAT INI: Helper untuk validasi sebelum transaksi keluar
  // ─────────────────────────────────────────────────────────────────
  Future<int> getStokSaatIni(String kodeScan) async {
    final db = await _db.database;
    final result = await db.query(
      'master_barang',
      columns: ['stok_sisa'],
      where: 'kode_scan = ?',
      whereArgs: [kodeScan],
      limit: 1,
    );
    if (result.isEmpty) return 0;
    return result.first['stok_sisa'] as int? ?? 0;
  }
}
