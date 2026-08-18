// File: lib/features/auth/data/auth_service.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scan_go/core/database/database_helper.dart';

// ─────────────────────────────────────────────────────────────────
// AUTH SERVICE — login sederhana tapi aman untuk bengkel
//
//   - Password di-hash SHA-256 + salt (tidak plain text)
//   - Default admin/admin saat pertama install
//   - Bisa ganti password/username lewat Pengaturan
//   - Disimpan di tabel app_settings
//
// SELF-HEAL: setiap operasi memastikan tabel app_settings ada
//   (CREATE TABLE IF NOT EXISTS), jadi TIDAK perlu hapus DB lama
//   hanya untuk fitur login.
// ─────────────────────────────────────────────────────────────────

class AuthService {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  static const String _keyPasswordHash = 'password_hash';
  static const String _keySalt = 'password_salt';
  static const String _keyUsername = 'username';

  static const String _defaultUsername = 'admin';
  static const String _defaultPassword = 'admin';

  // ── Pastikan tabel app_settings ada (self-heal) ──────────────
  Future<void> _pastikanTabel() async {
    final db = await _db;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ── Hash password dengan salt ────────────────────────────────
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }

  String _generateSalt() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return sha256.convert(utf8.encode('otoscan_$now')).toString().substring(0, 16);
  }

  // ── INIT — pastikan ada kredensial default ───────────────────
  Future<void> pastikanAdaKredensial() async {
    await _pastikanTabel();
    final db = await _db;

    final existing = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [_keyPasswordHash],
      limit: 1,
    );

    if (existing.isEmpty) {
      final salt = _generateSalt();
      final hash = _hashPassword(_defaultPassword, salt);
      await db.insert('app_settings', {'key': _keyUsername, 'value': _defaultUsername});
      await db.insert('app_settings', {'key': _keySalt, 'value': salt});
      await db.insert('app_settings', {'key': _keyPasswordHash, 'value': hash});
    }
  }

  // ── LOGIN ────────────────────────────────────────────────────
  // Return: null jika sukses, pesan error jika gagal
  Future<String?> login(String username, String password) async {
    await pastikanAdaKredensial();
    final db = await _db;

    final rows = await db.query('app_settings',
        where: 'key IN (?, ?, ?)',
        whereArgs: [_keyUsername, _keySalt, _keyPasswordHash]);

    final Map<String, String> settings = {
      for (final r in rows) r['key'] as String: r['value'] as String
    };

    final savedUsername = settings[_keyUsername] ?? _defaultUsername;
    final savedSalt = settings[_keySalt] ?? '';
    final savedHash = settings[_keyPasswordHash] ?? '';

    if (username.trim() != savedUsername) {
      return 'Username salah';
    }

    final inputHash = _hashPassword(password, savedSalt);
    if (inputHash != savedHash) {
      return 'Password salah';
    }

    return null; // sukses
  }

  // ── GANTI PASSWORD ───────────────────────────────────────────
  Future<String?> gantiPassword({
    required String passwordLama,
    required String passwordBaru,
  }) async {
    if (passwordBaru.length < 4) {
      return 'Password baru minimal 4 karakter';
    }

    final username = await getUsername();
    final cekLama = await login(username, passwordLama);
    if (cekLama != null) {
      return 'Password lama salah';
    }

    await _pastikanTabel();
    final db = await _db;
    final salt = _generateSalt();
    final hash = _hashPassword(passwordBaru, salt);

    await db.update('app_settings', {'value': salt},
        where: 'key = ?', whereArgs: [_keySalt]);
    await db.update('app_settings', {'value': hash},
        where: 'key = ?', whereArgs: [_keyPasswordHash]);

    return null;
  }

  // ── GANTI USERNAME ───────────────────────────────────────────
  Future<String?> gantiUsername(String usernameBaru) async {
    if (usernameBaru.trim().length < 3) {
      return 'Username minimal 3 karakter';
    }
    await pastikanAdaKredensial();
    final db = await _db;
    await db.update('app_settings', {'value': usernameBaru.trim()},
        where: 'key = ?', whereArgs: [_keyUsername]);
    return null;
  }

  Future<String> getUsername() async {
    await pastikanAdaKredensial();
    final db = await _db;
    final rows = await db.query('app_settings',
        where: 'key = ?', whereArgs: [_keyUsername], limit: 1);
    if (rows.isEmpty) return _defaultUsername;
    return rows.first['value'] as String;
  }

  // ── RESET KE DEFAULT (darurat, lupa password) ────────────────
  Future<void> resetKeDefault() async {
    await pastikanAdaKredensial();
    final db = await _db;
    final salt = _generateSalt();
    final hash = _hashPassword(_defaultPassword, salt);

    await db.update('app_settings', {'value': _defaultUsername},
        where: 'key = ?', whereArgs: [_keyUsername]);
    await db.update('app_settings', {'value': salt},
        where: 'key = ?', whereArgs: [_keySalt]);
    await db.update('app_settings', {'value': hash},
        where: 'key = ?', whereArgs: [_keyPasswordHash]);
  }
}