// File: lib/features/transaksi_keluar/data/transaksi_keluar_repository.dart

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scan_go/core/database/database_helper.dart';
import 'package:scan_go/features/pelanggan/data/pelanggan_repository.dart';
import 'transaksi_keluar_header_model.dart';
import 'transaksi_keluar_detail_model.dart';
import 'pembayaran_hutang_model.dart';

// ─────────────────────────────────────────────────────────────────
// REPOSITORY UNTUK CHECKOUT (BAYAR) DAN LIST TRANSAKSI KELUAR
//
// Fokus utama:
//   - simpanNota: 1 atomic transaction yang melibatkan 4 tabel
//   - generateNoNota: format OUT-YYYYMMDD-NNN, reset harian
//   - listNota / detailNota: untuk laporan & history
// ─────────────────────────────────────────────────────────────────

class TransaksiKeluarRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;
  final _pelangganRepo = PelangganRepository();

  String _fmtTanggal(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  String _fmtJam(DateTime d) =>
    '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}:${d.second.toString().padLeft(2,'0')}';

  // ─────────────────────────────────────────────────────────────
  // GENERATE NO NOTA: OUT-YYYYMMDD-NNN
  //
  // Cari nomor terakhir di tanggal yang sama, +1.
  // Kalau belum ada di tanggal itu, mulai dari 001.
  // ─────────────────────────────────────────────────────────────
  Future<String> generateNoNotaInTransaction(
    DatabaseExecutor txn,
    DateTime now,
  ) async {
    final tgl = _fmtTanggal(now);
    final tglCompact = '${now.year}'
                       '${now.month.toString().padLeft(2,'0')}'
                       '${now.day.toString().padLeft(2,'0')}';
    final prefix = 'OUT-$tglCompact-';

    final rows = await txn.rawQuery('''
      SELECT no_nota FROM transaksi_keluar_header
      WHERE tanggal = ?
      ORDER BY no_nota DESC
      LIMIT 1
    ''', [tgl]);

    int next = 1;
    if (rows.isNotEmpty) {
      final last = rows.first['no_nota'] as String;
      // Ambil 3 digit terakhir
      final lastNum = int.tryParse(last.substring(last.length - 3)) ?? 0;
      next = lastNum + 1;
    }

    return '$prefix${next.toString().padLeft(3, '0')}';
  }

  // ─────────────────────────────────────────────────────────────
  // ★★★ SIMPAN NOTA — INTI APLIKASI POS ★★★
  //
  // Atomic operation yang melibatkan:
  //   1. Upsert pelanggan (jika hutang)
  //   2. Generate no_nota
  //   3. Insert header
  //   4. Insert N detail items
  //   5. Update stok master (kurangi)
  //   6. Insert pembayaran pertama
  //   7. Update statistik pelanggan
  //
  // Semua dalam 1 db.transaction → rollback otomatis kalau ada error.
  //
  // Return: { 'noNota': String, 'error': String? }
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, String?>> simpanNota({
    required List<CartItem> cart,
    required int uangDiterima,
    String? namaPelanggan,
    String? noHpPelanggan,
    String? alamatPelanggan,
    String? catatan,
  }) async {
    if (cart.isEmpty) {
      return {'noNota': null, 'error': 'Keranjang kosong'};
    }

    final db = await _db;
    final now = DateTime.now();
    final tanggal = _fmtTanggal(now);
    final jam = _fmtJam(now);

    // Hitung total
    int totalTagihan = 0;
    int totalModal   = 0;
    for (final item in cart) {
      totalTagihan += item.subtotalJual;
      totalModal   += item.subtotalModal;
    }
    final totalLaba = totalTagihan - totalModal;

    // Tentukan status
    final bool isLunas    = uangDiterima >= totalTagihan;
    final int kembalian   = isLunas ? (uangDiterima - totalTagihan) : 0;
    final int sisaHutang  = isLunas ? 0 : (totalTagihan - uangDiterima);
    final int dibayar     = isLunas ? totalTagihan : uangDiterima;

    // Validasi: jika hutang, nama wajib
    if (!isLunas) {
      if (namaPelanggan == null || namaPelanggan.trim().isEmpty) {
        return {'noNota': null, 'error': 'Nama pelanggan wajib diisi untuk hutang'};
      }
    }

    try {
      String? noNotaResult;

      await db.transaction((txn) async {
        // ── 1. Upsert pelanggan (jika hutang ATAU ada nama diisi) ──
        int? pelangganId;
        if (!isLunas || (namaPelanggan != null && namaPelanggan.trim().isNotEmpty)) {
          pelangganId = await _pelangganRepo.upsertInTransaction(
            txn,
            nama: namaPelanggan!,
            noHp: noHpPelanggan,
            alamat: alamatPelanggan,
          );
        }

        // ── 2. Generate no_nota ──
        final noNota = await generateNoNotaInTransaction(txn, now);
        noNotaResult = noNota;

        // ── 3. Insert header ──
        final header = TransaksiKeluarHeader(
          noNota:                noNota,
          tanggal:               tanggal,
          jam:                   jam,
          totalTagihan:          totalTagihan,
          totalModal:            totalModal,
          totalLaba:             totalLaba,
          totalDibayar:          dibayar,
          sisaHutang:            sisaHutang,
          kembalian:             kembalian,
          status:                isLunas ? StatusNota.lunas : StatusNota.hutang,
          pelangganId:           pelangganId,
          namaPelangganSnapshot: namaPelanggan?.trim(),
          noHpSnapshot:          noHpPelanggan?.trim(),
          catatan:               catatan?.trim(),
          tanggalLunas:          isLunas ? tanggal : null,
        );
        await txn.insert('transaksi_keluar_header', header.toMap());

        // ── 4. Insert detail items + 5. Update stok ──
        for (final cartItem in cart) {
          // Cek stok terkini di DB (defensive — cegah race condition)
          final stokRow = await txn.query(
            'master_barang',
            columns: ['stok_sisa'],
            where: 'kode_scan = ?',
            whereArgs: [cartItem.barang.kodeScan],
            limit: 1,
          );
          if (stokRow.isEmpty) {
            throw Exception(
              'Barang ${cartItem.barang.namaBarang} sudah dihapus dari master',
            );
          }
          final stokTerkini = stokRow.first['stok_sisa'] as int? ?? 0;
          if (stokTerkini < cartItem.qty) {
            throw Exception(
              'Stok ${cartItem.barang.namaBarang} tidak cukup. '
              'Tersedia $stokTerkini, diminta ${cartItem.qty}',
            );
          }

          // Insert detail
          final detail = cartItem.toDetail(noNota);
          await txn.insert('transaksi_keluar_detail', detail.toMap());

          // Update stok master (kurangi)
          await txn.rawUpdate('''
            UPDATE master_barang
            SET stok_sisa = stok_sisa - ?
            WHERE kode_scan = ?
          ''', [cartItem.qty, cartItem.barang.kodeScan]);
        }

        // ── 6. Insert pembayaran pertama ──
        // Selalu ada minimal 1 entry (untuk audit trail)
        if (dibayar > 0) {
          await txn.insert('pembayaran_hutang', {
            'no_nota':  noNota,
            'tanggal':  tanggal,
            'jam':      jam,
            'jumlah':   dibayar,
            'metode':   'TUNAI',
            'catatan':  isLunas ? 'Pembayaran lunas' : 'Pembayaran awal',
          });
        }

        // ── 7. Update statistik pelanggan ──
        if (pelangganId != null) {
          await _pelangganRepo.updateStatistikInTransaction(
            txn,
            pelangganId,
            tambahHutang: sisaHutang,
            tambahTransaksi: true,
          );
        }
      });

      return {'noNota': noNotaResult, 'error': null};
    } catch (e) {
      return {'noNota': null, 'error': e.toString().replaceAll('Exception: ', '')};
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LIST NOTA — untuk halaman riwayat
  // ─────────────────────────────────────────────────────────────
  Future<List<TransaksiKeluarHeader>> listNota({
    String? dari,
    String? sampai,
    String? statusFilter,    // 'LUNAS' atau 'HUTANG' atau null
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _db;

    final where = <String>[];
    final args  = <Object>[];

    if (dari != null) {
      where.add('tanggal >= ?');
      args.add(dari);
    }
    if (sampai != null) {
      where.add('tanggal <= ?');
      args.add(sampai);
    }
    if (statusFilter != null) {
      where.add('status = ?');
      args.add(statusFilter);
    }

    final rows = await db.query(
      'transaksi_keluar_header',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'tanggal DESC, jam DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map((r) => TransaksiKeluarHeader.fromMap(r)).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // DETAIL NOTA — header + isi + history pembayaran
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> detailNota(String noNota) async {
    final db = await _db;

    // Header
    final headerRows = await db.query(
      'transaksi_keluar_header',
      where: 'no_nota = ?',
      whereArgs: [noNota],
      limit: 1,
    );
    if (headerRows.isEmpty) return null;
    final header = TransaksiKeluarHeader.fromMap(headerRows.first);

    // Detail (isi keranjang)
    final detailRows = await db.query(
      'transaksi_keluar_detail',
      where: 'no_nota = ?',
      whereArgs: [noNota],
      orderBy: 'id ASC',
    );
    final details = detailRows.map((r) => TransaksiKeluarDetail.fromMap(r)).toList();

    // Pembayaran (riwayat cicilan)
    final bayarRows = await db.query(
      'pembayaran_hutang',
      where: 'no_nota = ?',
      whereArgs: [noNota],
      orderBy: 'tanggal ASC, jam ASC',
    );
    final pembayarans = bayarRows.map((r) => PembayaranHutang.fromMap(r)).toList();

    return {
      'header': header,
      'details': details,
      'pembayarans': pembayarans,
    };
  }

  // ─────────────────────────────────────────────────────────────
  // RIWAYAT HARI INI
  // ─────────────────────────────────────────────────────────────
  Future<List<TransaksiKeluarHeader>> getRiwayatHariIni() async {
    final today = _fmtTanggal(DateTime.now());
    return listNota(dari: today, sampai: today, limit: 100);
  }
}
