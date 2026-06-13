import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

// ─────────────────────────────────────────────────────────────────
// DATABASE SCHEMA v2 — OtoScan Logistik
//
// Tabel:
//   1. master_barang             — daftar produk + stok
//   2. transaksi_masuk           — log barang masuk (flat)
//   3. pelanggan                 — master pelanggan (untuk hutang)
//   4. transaksi_keluar_header   — nota / kepala transaksi
//   5. transaksi_keluar_detail   — isi keranjang per nota
//   6. pembayaran_hutang         — log cicilan pembayaran
//
// Filosofi desain:
//   - Header-detail untuk transaksi keluar → laba akurat per item
//   - Snapshot harga di detail → laba tidak rusak walau master diubah
//   - Snapshot nama pelanggan di header → riwayat tetap utuh
//   - Index lengkap untuk query laporan cepat
//   - Foreign key dengan ON DELETE yang aman
// ─────────────────────────────────────────────────────────────────

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const int _kVersion = 2;
  static const String _kDbName = 'gudang_singgah_v2.db';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_kDbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    sqfliteFfiInit();
    var databaseFactory = databaseFactoryFfi;

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, filePath);

    print("====================================");
    print("LOKASI DATABASE: $path");
    print("VERSION: $_kVersion");
    print("====================================");

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _kVersion,
        onCreate: _createDB,
        onConfigure: (db) async {
          // Enable foreign keys (SQLite default = off)
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // ═══════════════════════════════════════════════════════════
    // 1. MASTER BARANG
    // ═══════════════════════════════════════════════════════════
    await db.execute('''
      CREATE TABLE master_barang (
        kode_scan TEXT PRIMARY KEY,
        nama_barang TEXT NOT NULL,
        kategori TEXT DEFAULT 'PART',
        harga_astra INTEGER DEFAULT 0,
        harga_jual INTEGER DEFAULT 0,
        stok_sisa INTEGER DEFAULT 0
      )
    ''');

    await db.execute('CREATE INDEX idx_master_kategori ON master_barang(kategori)');
    await db.execute('CREATE INDEX idx_master_nama ON master_barang(nama_barang)');

    // ═══════════════════════════════════════════════════════════
    // 2. TRANSAKSI MASUK (flat — sederhana)
    // ═══════════════════════════════════════════════════════════
    await db.execute('''
      CREATE TABLE transaksi_masuk (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kode_scan TEXT NOT NULL,
        qty INTEGER NOT NULL DEFAULT 1,
        harga_astra_satuan INTEGER DEFAULT 0,
        tanggal DATE NOT NULL,
        jam TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_masuk_tanggal ON transaksi_masuk(tanggal)');
    await db.execute('CREATE INDEX idx_masuk_kode ON transaksi_masuk(kode_scan)');

    // ═══════════════════════════════════════════════════════════
    // 3. PELANGGAN (master pelanggan untuk sistem hutang)
    // ═══════════════════════════════════════════════════════════
    await db.execute('''
      CREATE TABLE pelanggan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        no_hp TEXT,
        alamat TEXT,
        catatan TEXT,
        total_transaksi INTEGER DEFAULT 0,
        total_hutang_aktif INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_pelanggan_nama ON pelanggan(nama)');
    await db.execute('CREATE INDEX idx_pelanggan_hp ON pelanggan(no_hp)');
    await db.execute('CREATE INDEX idx_pelanggan_hutang ON pelanggan(total_hutang_aktif)');

    // ═══════════════════════════════════════════════════════════
    // 4. TRANSAKSI KELUAR — HEADER (nota / kepala transaksi)
    // ═══════════════════════════════════════════════════════════
    await db.execute('''
      CREATE TABLE transaksi_keluar_header (
        no_nota TEXT PRIMARY KEY,
        tanggal DATE NOT NULL,
        jam TEXT NOT NULL,

        total_tagihan INTEGER NOT NULL,
        total_modal INTEGER NOT NULL,
        total_laba INTEGER NOT NULL,

        total_dibayar INTEGER NOT NULL DEFAULT 0,
        sisa_hutang INTEGER NOT NULL DEFAULT 0,
        kembalian INTEGER NOT NULL DEFAULT 0,

        status TEXT NOT NULL CHECK(status IN ('LUNAS', 'HUTANG')),

        pelanggan_id INTEGER,
        nama_pelanggan_snapshot TEXT,
        no_hp_snapshot TEXT,

        catatan TEXT,
        tanggal_lunas DATE,

        FOREIGN KEY (pelanggan_id) REFERENCES pelanggan(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_header_tanggal ON transaksi_keluar_header(tanggal)');
    await db.execute('CREATE INDEX idx_header_status ON transaksi_keluar_header(status)');
    await db.execute('CREATE INDEX idx_header_pelanggan ON transaksi_keluar_header(pelanggan_id)');
    await db.execute('CREATE INDEX idx_header_tanggal_lunas ON transaksi_keluar_header(tanggal_lunas)');

    // ═══════════════════════════════════════════════════════════
    // 5. TRANSAKSI KELUAR — DETAIL (isi keranjang per nota)
    // ═══════════════════════════════════════════════════════════
    await db.execute('''
      CREATE TABLE transaksi_keluar_detail (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        no_nota TEXT NOT NULL,
        kode_scan TEXT NOT NULL,
        nama_barang TEXT NOT NULL,
        kategori TEXT NOT NULL,
        qty INTEGER NOT NULL,
        harga_modal_saat_itu INTEGER NOT NULL,
        harga_jual_saat_itu INTEGER NOT NULL,
        subtotal_jual INTEGER NOT NULL,
        subtotal_modal INTEGER NOT NULL,
        subtotal_laba INTEGER NOT NULL,
        FOREIGN KEY (no_nota) REFERENCES transaksi_keluar_header(no_nota) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_detail_nota ON transaksi_keluar_detail(no_nota)');
    await db.execute('CREATE INDEX idx_detail_kode ON transaksi_keluar_detail(kode_scan)');
    await db.execute('CREATE INDEX idx_detail_kategori ON transaksi_keluar_detail(kategori)');

    // ═══════════════════════════════════════════════════════════
    // 6. PEMBAYARAN HUTANG (log per cicilan)
    //
    // Setiap transaksi minimal punya 1 entry pembayaran (pembayaran
    // awal saat checkout). Kalau ada cicilan, tambah entry baru.
    // ═══════════════════════════════════════════════════════════
    await db.execute('''
      CREATE TABLE pembayaran_hutang (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        no_nota TEXT NOT NULL,
        tanggal DATE NOT NULL,
        jam TEXT NOT NULL,
        jumlah INTEGER NOT NULL,
        metode TEXT NOT NULL DEFAULT 'TUNAI',
        catatan TEXT,
        FOREIGN KEY (no_nota) REFERENCES transaksi_keluar_header(no_nota) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_bayar_nota ON pembayaran_hutang(no_nota)');
    await db.execute('CREATE INDEX idx_bayar_tanggal ON pembayaran_hutang(tanggal)');
  }
}
