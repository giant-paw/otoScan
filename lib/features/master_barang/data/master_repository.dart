import '../../../core/database/database_helper.dart';
import 'barang_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MasterRepository {
  final _db = DatabaseHelper.instance;
 
  Future<List<Barang>> getAllBarang({int limit = 150, int offset = 0}) async {
    final db = await _db.database;
    final result = await db.query(
      'master_barang',
      limit: limit,
      offset: offset,
      orderBy: 'nama_barang ASC',
    );
    return result.map((row) => Barang.fromMap(row)).toList();
  }
 
  Future<List<Barang>> searchBarang(String keyword) async {
    final db = await _db.database;
    final result = await db.query(
      'master_barang',
      where: 'nama_barang LIKE ? OR kode_scan LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: 'nama_barang ASC',
      limit: 200,
    );
    return result.map((row) => Barang.fromMap(row)).toList();
  }
 
  Future<bool> insertBarang(Barang barang) async {
    try {
      final db = await _db.database;
      await db.insert(
        'master_barang',
        barang.toMap(),
        // Jika kode sudah ada, tolak (jangan timpa)
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return true;
    } catch (e) {
      // Kode sudah terdaftar
      return false;
    }
  }
 
  // =============================================
  // UPDATE: Edit data barang
  // =============================================
  Future<bool> updateBarang(Barang barang) async {
    try {
      final db = await _db.database;
      final rowsAffected = await db.update(
        'master_barang',
        barang.toMap(),
        where: 'kode_scan = ?',
        whereArgs: [barang.kodeScan],
      );
      return rowsAffected > 0;
    } catch (e) {
      return false;
    }
  }
 
  Future<bool> deleteBarang(String kodeScan) async {
    try {
      final db = await _db.database;
      final rowsAffected = await db.delete(
        'master_barang',
        where: 'kode_scan = ?',
        whereArgs: [kodeScan],
      );
      return rowsAffected > 0;
    } catch (e) {
      return false;
    }
  }
 
  // =============================================
  // CHECK: Cek apakah kode sudah terdaftar
  // =============================================
  Future<bool> isKodeExist(String kodeScan) async {
    final db = await _db.database;
    final result = await db.query(
      'master_barang',
      where: 'kode_scan = ?',
      whereArgs: [kodeScan],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}