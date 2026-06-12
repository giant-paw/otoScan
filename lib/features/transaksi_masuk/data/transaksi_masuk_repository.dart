import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../../core/database/database_helper.dart';
import 'transaksi_masuk_model.dart';

// ─────────────────────────────────────────────────────────────────
// Semua method mengembalikan String? (null = sukses, String = error)
// Ini lebih informatif daripada bool karena UI bisa tampilkan
// pesan error spesifik kepada user.
// ─────────────────────────────────────────────────────────────────
class TransaksiMasukRepository {
  final _db = DatabaseHelper.instance;

  // ─────────────────────────────────────────────────────────────
  // SIMPAN: Insert + update stok dalam satu transaksi atomik
  // ─────────────────────────────────────────────────────────────
  Future<String?> simpan(TransaksiMasuk t) async {
    if (t.qty <= 0) return 'Qty tidak valid: ${t.qty}';

    final db = await _db.database;
    try {
      await db.transaction((txn) async {
        await txn.insert('transaksi_masuk', t.toMap());

        // Update stok — aman karena barang masuk selalu menambah
        final rowsAffected = await txn.rawUpdate(
          'UPDATE master_barang SET stok_sisa = stok_sisa + ? WHERE kode_scan = ?',
          [t.qty, t.kodeScan],
        );

        // Validasi: pastikan barang masih ada di master
        if (rowsAffected == 0) {
          throw Exception('Barang "${t.kodeScan}" tidak ditemukan di master.');
        }
      });
      return null; // sukses
    } on Exception catch (e) {
      return 'Gagal menyimpan: $e';
    } catch (e) {
      return 'Error tidak terduga: $e';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HAPUS: Rollback — hapus transaksi + kurangi stok kembali
  // ─────────────────────────────────────────────────────────────
  Future<String?> hapus(int id, String kodeScan, int qty) async {
    final db = await _db.database;
    try {
      await db.transaction((txn) async {
        // Cek stok tidak akan minus setelah rollback
        final rows = await txn.query(
          'master_barang',
          columns: ['stok_sisa'],
          where: 'kode_scan = ?',
          whereArgs: [kodeScan],
          limit: 1,
        );

        if (rows.isNotEmpty) {
          final stokSekarang = rows.first['stok_sisa'] as int? ?? 0;
          if (stokSekarang - qty < 0) {
            // Stok sudah berkurang dari transaksi keluar — hapus transaksi
            // saja tanpa rollback stok penuh, atau tolak
            throw Exception(
              'Stok saat ini ($stokSekarang) kurang dari qty yang akan dikembalikan ($qty). '
              'Kemungkinan sudah ada transaksi keluar. Hubungi supervisor.',
            );
          }
        }

        await txn.delete('transaksi_masuk', where: 'id = ?', whereArgs: [id]);

        await txn.rawUpdate(
          'UPDATE master_barang SET stok_sisa = stok_sisa - ? WHERE kode_scan = ?',
          [qty, kodeScan],
        );
      });
      return null;
    } on Exception catch (e) {
      return '$e';
    } catch (e) {
      return 'Error tidak terduga saat membatalkan: $e';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RIWAYAT HARI INI: JOIN ke master untuk nama & kategori
  // ─────────────────────────────────────────────────────────────
  Future<List<TransaksiMasuk>> getRiwayatHariIni() async {
    final db = await _db.database;
    final tanggal = DateTime.now().toIso8601String().substring(0, 10);

    final rows = await db.rawQuery('''
      SELECT
        tm.id,
        tm.kode_scan,
        tm.qty,
        tm.harga_astra_satuan,
        tm.tanggal,
        tm.jam,
        COALESCE(mb.nama_barang, '(barang dihapus)') AS nama_barang,
        COALESCE(mb.kategori, '-') AS kategori
      FROM transaksi_masuk tm
      LEFT JOIN master_barang mb ON tm.kode_scan = mb.kode_scan
      WHERE tm.tanggal = ?
      ORDER BY tm.id DESC
    ''', [tanggal]);

    return rows.map(TransaksiMasuk.fromMap).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // RIWAYAT RENTANG: Untuk laporan & export Excel
  // ─────────────────────────────────────────────────────────────
  Future<List<TransaksiMasuk>> getRiwayatRentang(
      String dari, String sampai) async {
    final db = await _db.database;

    final rows = await db.rawQuery('''
      SELECT
        tm.id,
        tm.kode_scan,
        tm.qty,
        tm.harga_astra_satuan,
        tm.tanggal,
        tm.jam,
        COALESCE(mb.nama_barang, '(barang dihapus)') AS nama_barang,
        COALESCE(mb.kategori, '-') AS kategori
      FROM transaksi_masuk tm
      LEFT JOIN master_barang mb ON tm.kode_scan = mb.kode_scan
      WHERE tm.tanggal BETWEEN ? AND ?
      ORDER BY tm.tanggal DESC, tm.id DESC
    ''', [dari, sampai]);

    return rows.map(TransaksiMasuk.fromMap).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // CEK STOK — helper untuk transaksi keluar
  // ─────────────────────────────────────────────────────────────
  Future<int> getStokSaatIni(String kodeScan) async {
    final db = await _db.database;
    final result = await db.query(
      'master_barang',
      columns: ['stok_sisa'],
      where: 'kode_scan = ?',
      whereArgs: [kodeScan],
      limit: 1,
    );
    if (result.isEmpty) return -1; // -1 = barang tidak ada di master
    return result.first['stok_sisa'] as int? ?? 0;
  }
}