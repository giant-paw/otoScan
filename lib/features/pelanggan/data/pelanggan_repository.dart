// File: lib/features/pelanggan/data/pelanggan_repository.dart

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scan_go/core/database/database_helper.dart';
import 'pelanggan_model.dart';

class PelangganRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  String _now() => DateTime.now().toIso8601String();

  // ─────────────────────────────────────────────────────────────
  // CREATE
  // Return: id pelanggan baru, atau null jika gagal
  // ─────────────────────────────────────────────────────────────
  Future<int?> tambah(Pelanggan p) async {
    try {
      final db = await _db;
      final now = _now();
      final id = await db.insert('pelanggan', {
        'nama':                p.nama.trim(),
        'no_hp':               p.noHp?.trim(),
        'alamat':              p.alamat?.trim(),
        'catatan':             p.catatan?.trim(),
        'total_transaksi':     0,
        'total_hutang_aktif':  0,
        'created_at':          now,
        'updated_at':          now,
      });
      return id;
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UPDATE — edit data pelanggan
  // ─────────────────────────────────────────────────────────────
  Future<String?> update(Pelanggan p) async {
    if (p.id == null) return 'ID pelanggan tidak ditemukan';
    try {
      final db = await _db;
      await db.update(
        'pelanggan',
        {
          'nama':       p.nama.trim(),
          'no_hp':      p.noHp?.trim(),
          'alamat':     p.alamat?.trim(),
          'catatan':    p.catatan?.trim(),
          'updated_at': _now(),
        },
        where: 'id = ?',
        whereArgs: [p.id],
      );
      return null;
    } catch (e) {
      return 'Gagal update pelanggan: $e';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DELETE — hanya boleh jika tidak ada hutang aktif
  // ─────────────────────────────────────────────────────────────
  Future<String?> hapus(int id) async {
    try {
      final db = await _db;
      final cek = await db.query(
        'pelanggan',
        columns: ['total_hutang_aktif'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (cek.isEmpty) return 'Pelanggan tidak ditemukan';
      final hutang = cek.first['total_hutang_aktif'] as int? ?? 0;
      if (hutang > 0) {
        return 'Pelanggan masih punya hutang Rp $hutang, tidak bisa dihapus';
      }
      await db.delete('pelanggan', where: 'id = ?', whereArgs: [id]);
      return null;
    } catch (e) {
      return 'Gagal hapus: $e';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GET BY ID
  // ─────────────────────────────────────────────────────────────
  Future<Pelanggan?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'pelanggan',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Pelanggan.fromMap(rows.first);
  }

  // ─────────────────────────────────────────────────────────────
  // GET ALL — untuk cache provider
  // ─────────────────────────────────────────────────────────────
  Future<List<Pelanggan>> getAll() async {
    final db = await _db;
    final rows = await db.query('pelanggan', orderBy: 'nama ASC');
    return rows.map((r) => Pelanggan.fromMap(r)).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH — untuk autocomplete saat input nama
  // ─────────────────────────────────────────────────────────────
  Future<List<Pelanggan>> cari(String keyword) async {
    if (keyword.trim().length < 2) return [];
    final db = await _db;
    final kw = '%${keyword.trim()}%';
    final rows = await db.query(
      'pelanggan',
      where: 'nama LIKE ? OR no_hp LIKE ?',
      whereArgs: [kw, kw],
      orderBy: 'nama ASC',
      limit: 10,
    );
    return rows.map((r) => Pelanggan.fromMap(r)).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // LIST PUNYA HUTANG AKTIF — untuk buku piutang
  // ─────────────────────────────────────────────────────────────
  Future<List<Pelanggan>> getPunyaHutang() async {
    final db = await _db;
    final rows = await db.query(
      'pelanggan',
      where: 'total_hutang_aktif > 0',
      orderBy: 'total_hutang_aktif DESC',
    );
    return rows.map((r) => Pelanggan.fromMap(r)).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // UPSERT — cari berdasarkan nama+HP, kalau ada return ID,
  // kalau tidak ada buat baru. Dipakai saat checkout hutang.
  //
  // Pakai txn (transaction) agar atomic dengan checkout.
  // ─────────────────────────────────────────────────────────────
  Future<int> upsertInTransaction(
    DatabaseExecutor txn, {
    required String nama,
    String? noHp,
    String? alamat,
    String? catatan,
  }) async {
    final namaTrim = nama.trim();
    final hpTrim   = noHp?.trim() ?? '';

    // Coba cari yang persis sama (nama + HP)
    if (hpTrim.isNotEmpty) {
      final existing = await txn.query(
        'pelanggan',
        where: 'nama = ? AND no_hp = ?',
        whereArgs: [namaTrim, hpTrim],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return existing.first['id'] as int;
      }
    } else {
      // Tanpa HP, cari yang nama-nya sama (kemungkinan pelanggan walk-in)
      final existing = await txn.query(
        'pelanggan',
        where: 'nama = ? AND (no_hp IS NULL OR no_hp = ?)',
        whereArgs: [namaTrim, ''],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return existing.first['id'] as int;
      }
    }

    // Tidak ada → buat baru
    final now = _now();
    final id = await txn.insert('pelanggan', {
      'nama':                namaTrim,
      'no_hp':               hpTrim.isEmpty ? null : hpTrim,
      'alamat':              alamat?.trim(),
      'catatan':             catatan?.trim(),
      'total_transaksi':     0,
      'total_hutang_aktif':  0,
      'created_at':          now,
      'updated_at':          now,
    });
    return id;
  }

  // ─────────────────────────────────────────────────────────────
  // UPDATE STATISTIK — total_hutang_aktif & total_transaksi
  // Dipanggil dari dalam transaction checkout / pembayaran
  // ─────────────────────────────────────────────────────────────
  Future<void> updateStatistikInTransaction(
    DatabaseExecutor txn,
    int pelangganId, {
    int tambahHutang = 0,
    int kurangHutang = 0,
    bool tambahTransaksi = false,
  }) async {
    await txn.rawUpdate('''
      UPDATE pelanggan SET
        total_hutang_aktif = total_hutang_aktif + ? - ?,
        total_transaksi    = total_transaksi + ?,
        updated_at         = ?
      WHERE id = ?
    ''', [
      tambahHutang,
      kurangHutang,
      tambahTransaksi ? 1 : 0,
      _now(),
      pelangganId,
    ]);
  }
}
