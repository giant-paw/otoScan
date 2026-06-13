// File: lib/features/transaksi_keluar/data/piutang_repository.dart

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scan_go/core/database/database_helper.dart';
import 'package:scan_go/features/pelanggan/data/pelanggan_repository.dart';
import 'transaksi_keluar_header_model.dart';
import 'pembayaran_hutang_model.dart';

// ─────────────────────────────────────────────────────────────────
// REPOSITORY UNTUK BUKU PIUTANG (HUTANG AKTIF)
//
// Fokus utama:
//   - listHutangAktif: semua nota status=HUTANG dengan sisa > 0
//   - catatPembayaran: input cicilan, auto-update status & pelanggan
//   - dalam 1 atomic transaction
// ─────────────────────────────────────────────────────────────────

class PiutangRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;
  final _pelangganRepo = PelangganRepository();

  String _fmtTanggal(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  String _fmtJam(DateTime d) =>
    '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}:${d.second.toString().padLeft(2,'0')}';

  // ─────────────────────────────────────────────────────────────
  // LIST HUTANG AKTIF — untuk halaman buku piutang
  //
  // Filter: semua | minggu ini | bulan ini | > 30 hari (overdue)
  // ─────────────────────────────────────────────────────────────
  Future<List<TransaksiKeluarHeader>> listHutangAktif({
    int? pelangganId,
    int? umurHariMin,   // minimal umur hutang (untuk filter overdue)
  }) async {
    final db = await _db;

    final where = <String>['status = ?', 'sisa_hutang > 0'];
    final args  = <Object>['HUTANG'];

    if (pelangganId != null) {
      where.add('pelanggan_id = ?');
      args.add(pelangganId);
    }
    if (umurHariMin != null) {
      final batas = DateTime.now().subtract(Duration(days: umurHariMin));
      where.add('tanggal <= ?');
      args.add(_fmtTanggal(batas));
    }

    final rows = await db.query(
      'transaksi_keluar_header',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'tanggal ASC, jam ASC',
    );

    return rows.map((r) => TransaksiKeluarHeader.fromMap(r)).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // TOTAL HUTANG SISTEM — untuk dashboard widget
  // Return: total semua sisa_hutang yang masih aktif
  // ─────────────────────────────────────────────────────────────
  Future<int> totalPiutangAktif() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(sisa_hutang), 0) AS total
      FROM transaksi_keluar_header
      WHERE status = 'HUTANG' AND sisa_hutang > 0
    ''');
    return (result.first['total'] as int?) ?? 0;
  }

  // ─────────────────────────────────────────────────────────────
  // HISTORY PEMBAYARAN PER NOTA
  // ─────────────────────────────────────────────────────────────
  Future<List<PembayaranHutang>> historyPembayaran(String noNota) async {
    final db = await _db;
    final rows = await db.query(
      'pembayaran_hutang',
      where: 'no_nota = ?',
      whereArgs: [noNota],
      orderBy: 'tanggal ASC, jam ASC',
    );
    return rows.map((r) => PembayaranHutang.fromMap(r)).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // ★★★ CATAT PEMBAYARAN CICILAN ★★★
  //
  // Atomic operation:
  //   1. Validasi: jumlah > 0 dan <= sisa_hutang
  //   2. Insert ke pembayaran_hutang
  //   3. Update header: total_dibayar +=, sisa_hutang -=
  //   4. Jika sisa = 0: status → LUNAS, tanggal_lunas = today
  //   5. Update pelanggan: total_hutang_aktif -=
  //
  // Return: null jika sukses, error string jika gagal
  // ─────────────────────────────────────────────────────────────
  Future<String?> catatPembayaran({
    required String noNota,
    required int jumlah,
    String metode = 'TUNAI',
    String? catatan,
  }) async {
    if (jumlah <= 0) return 'Jumlah harus lebih dari 0';

    final db = await _db;
    final now = DateTime.now();
    final tanggal = _fmtTanggal(now);
    final jam = _fmtJam(now);

    try {
      await db.transaction((txn) async {
        // ── 1. Ambil header & validasi ──
        final headerRows = await txn.query(
          'transaksi_keluar_header',
          where: 'no_nota = ?',
          whereArgs: [noNota],
          limit: 1,
        );
        if (headerRows.isEmpty) {
          throw Exception('Nota $noNota tidak ditemukan');
        }
        final header = TransaksiKeluarHeader.fromMap(headerRows.first);

        if (header.isLunas) {
          throw Exception('Nota sudah lunas');
        }
        if (jumlah > header.sisaHutang) {
          throw Exception(
            'Jumlah pembayaran (Rp $jumlah) melebihi sisa hutang (Rp ${header.sisaHutang})',
          );
        }

        // ── 2. Insert pembayaran ──
        await txn.insert('pembayaran_hutang', {
          'no_nota':  noNota,
          'tanggal':  tanggal,
          'jam':      jam,
          'jumlah':   jumlah,
          'metode':   metode,
          'catatan':  catatan?.trim(),
        });

        // ── 3. Hitung total baru ──
        final totalDibayarBaru = header.totalDibayar + jumlah;
        final sisaBaru = header.sisaHutang - jumlah;
        final bool lunasSekarang = sisaBaru <= 0;

        // ── 4. Update header ──
        await txn.update(
          'transaksi_keluar_header',
          {
            'total_dibayar': totalDibayarBaru,
            'sisa_hutang':   sisaBaru,
            'status':        lunasSekarang ? 'LUNAS' : 'HUTANG',
            'tanggal_lunas': lunasSekarang ? tanggal : null,
          },
          where: 'no_nota = ?',
          whereArgs: [noNota],
        );

        // ── 5. Update pelanggan ──
        if (header.pelangganId != null) {
          await _pelangganRepo.updateStatistikInTransaction(
            txn,
            header.pelangganId!,
            kurangHutang: jumlah,
          );
        }
      });

      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BATALKAN PEMBAYARAN — kalau admin salah catat
  //
  // Hapus 1 entry pembayaran, kembalikan total_dibayar &
  // sisa_hutang. Status mungkin balik dari LUNAS → HUTANG.
  //
  // ⚠ Hati-hati pakai ini. Hanya untuk koreksi.
  // ─────────────────────────────────────────────────────────────
  Future<String?> batalkanPembayaran(int idPembayaran) async {
    final db = await _db;

    try {
      await db.transaction((txn) async {
        // Ambil pembayaran
        final rows = await txn.query(
          'pembayaran_hutang',
          where: 'id = ?',
          whereArgs: [idPembayaran],
          limit: 1,
        );
        if (rows.isEmpty) throw Exception('Pembayaran tidak ditemukan');
        final bayar = PembayaranHutang.fromMap(rows.first);

        // Ambil header
        final headerRows = await txn.query(
          'transaksi_keluar_header',
          where: 'no_nota = ?',
          whereArgs: [bayar.noNota],
          limit: 1,
        );
        if (headerRows.isEmpty) throw Exception('Nota tidak ditemukan');
        final header = TransaksiKeluarHeader.fromMap(headerRows.first);

        // Hapus pembayaran
        await txn.delete(
          'pembayaran_hutang',
          where: 'id = ?',
          whereArgs: [idPembayaran],
        );

        // Hitung ulang status
        final totalDibayarBaru = header.totalDibayar - bayar.jumlah;
        final sisaBaru = header.totalTagihan - totalDibayarBaru;

        if (totalDibayarBaru < 0) {
          throw Exception('Total dibayar tidak boleh negatif');
        }

        // Update header
        await txn.update(
          'transaksi_keluar_header',
          {
            'total_dibayar': totalDibayarBaru,
            'sisa_hutang':   sisaBaru,
            'status':        sisaBaru > 0 ? 'HUTANG' : 'LUNAS',
            'tanggal_lunas': sisaBaru > 0 ? null : header.tanggalLunas,
          },
          where: 'no_nota = ?',
          whereArgs: [bayar.noNota],
        );

        // Update pelanggan: kembalikan hutang
        if (header.pelangganId != null) {
          await _pelangganRepo.updateStatistikInTransaction(
            txn,
            header.pelangganId!,
            tambahHutang: bayar.jumlah,
          );
        }
      });

      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }
}
