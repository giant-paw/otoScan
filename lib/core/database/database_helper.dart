import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();


  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gudang_singgah_v1.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Inisialisasi khusus untuk Windows Desktop
    sqfliteFfiInit();
    var databaseFactory = databaseFactoryFfi;
    
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, filePath);

    print("====================================");
    print("LOKASI DATABASE: ");
    print(path);
    print("====================================");

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
      ),
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. TABEL MASTER BARANG
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

    await db.execute('''
      CREATE TABLE transaksi_keluar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kode_scan TEXT NOT NULL,
        qty INTEGER NOT NULL DEFAULT 1,
        harga_astra_satuan INTEGER DEFAULT 0,
        harga_jual_satuan INTEGER DEFAULT 0,
        tanggal DATE NOT NULL,
        jam TEXT NOT NULL
      )
    ''');
  }
}