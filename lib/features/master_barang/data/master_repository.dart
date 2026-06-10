import '../../../core/database/database_helper.dart';
import 'barang_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MasterRepository {
  final dbHelper = DatabaseHelper.instance;

  // READ: Mengambil semua daftar barang
  Future<List<BarangModel>> getAllBarang() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('master_barang');
    
    // Konversi hasil database ke bentuk List Objek
    return List.generate(maps.length, (i) {
      return BarangModel.fromMap(maps[i]);
    });
  }

  // CREATE: Menyimpan barang baru dari hasil Scan
  Future<int> insertBarang(BarangModel barang) async {
    final db = await dbHelper.database;
    return await db.insert('master_barang', barang.toMap());
  }

  // UPDATE: Mengubah data barang (misal ganti harga atau update stok)
  Future<int> updateBarang(BarangModel barang) async {
    final db = await dbHelper.database;
    return await db.update(
      'master_barang',
      barang.toMap(),
      where: 'kode_scan = ?',
      whereArgs: [barang.kodeScan],
    );
  }

  // DELETE: Menghapus barang jika salah input
  Future<int> deleteBarang(String kodeScan) async {
    final db = await dbHelper.database;
    return await db.delete(
      'master_barang',
      where: 'kode_scan = ?',
      whereArgs: [kodeScan],
    );
  }

  Future<List<BarangModel>> searchBarang(String keyword) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'master_barang',
      where: 'nama_barang LIKE ? OR kode_scan LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      limit: 100,
      orderBy: 'nama_barang ASC',
    );
    
    return List.generate(maps.length, (i) => BarangModel.fromMap(maps[i]));
  }
}