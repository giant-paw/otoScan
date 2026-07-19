// File: lib/features/dashboard/presentation/controller/dashboard_provider.dart

import 'package:flutter/material.dart';
import '../../data/dashboard_repository.dart';

// ─────────────────────────────────────────────────────────────────
// DASHBOARD PROVIDER — state halaman pembuka
//
// Load semua data dashboard secara paralel saat init/refresh.
// ─────────────────────────────────────────────────────────────────

class DashboardProvider extends ChangeNotifier {
  final _repo = DashboardRepository();

  Map<String, int>            _ringkasan = {};
  Map<String, dynamic>        _peringatan = {};
  List<Map<String, dynamic>>  _topBarang = [];
  List<Map<String, dynamic>>  _transaksiTerakhir = [];
  List<Map<String, dynamic>>  _tren7Hari = [];
  int _jumlahMaster = 0;

  bool _isLoading = false;
  String _errorPesan = '';

  // ── Getters ──────────────────────────────────────────────────
  bool   get isLoading  => _isLoading;
  String get errorPesan => _errorPesan;

  List<Map<String, dynamic>> get topBarang         => _topBarang;
  List<Map<String, dynamic>> get transaksiTerakhir => _transaksiTerakhir;
  List<Map<String, dynamic>> get tren7Hari         => _tren7Hari;
  int                        get jumlahMaster      => _jumlahMaster;

  // Ringkasan hari ini
  int get omzetHariIni  => _ringkasan['omzet'] ?? 0;
  int get labaHariIni   => _ringkasan['laba'] ?? 0;
  int get tunaiHariIni  => _ringkasan['tunai'] ?? 0;
  int get hutangBaruHariIni => _ringkasan['hutangBaru'] ?? 0;
  int get notaHariIni   => _ringkasan['jumlahNota'] ?? 0;
  int get itemHariIni   => _ringkasan['jumlahItem'] ?? 0;

  // Peringatan
  int get stokHabis     => (_peringatan['stokHabis'] as int?) ?? 0;
  int get stokMenipis   => (_peringatan['stokMenipis'] as int?) ?? 0;
  int get piutangTotal  => (_peringatan['piutangTotal'] as int?) ?? 0;
  int get piutangNota   => (_peringatan['piutangNota'] as int?) ?? 0;
  int get overdueTotal  => (_peringatan['overdueTotal'] as int?) ?? 0;
  int get overdueNota   => (_peringatan['overdueNota'] as int?) ?? 0;

  bool get adaPeringatan =>
    stokHabis > 0 || stokMenipis > 0 || piutangTotal > 0;

  // ── INIT / REFRESH ───────────────────────────────────────────
  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorPesan = '';
    notifyListeners();

    try {
      final results = await Future.wait([
        _repo.ringkasanHariIni(),
        _repo.peringatan(),
        _repo.topBarangBulanIni(limit: 5),
        _repo.transaksiTerakhir(limit: 6),
        _repo.tren7Hari(),
        _repo.jumlahMasterBarang(),
      ]);

      _ringkasan         = results[0] as Map<String, int>;
      _peringatan        = results[1] as Map<String, dynamic>;
      _topBarang         = results[2] as List<Map<String, dynamic>>;
      _transaksiTerakhir = results[3] as List<Map<String, dynamic>>;
      _tren7Hari         = results[4] as List<Map<String, dynamic>>;
      _jumlahMaster      = results[5] as int;
    } catch (e) {
      _errorPesan = 'Gagal memuat dashboard: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Ambil daftar barang stok menipis (untuk dialog detail)
  Future<List<Map<String, dynamic>>> getBarangStokMenipis() async {
    try {
      return await _repo.barangStokMenipis();
    } catch (_) {
      return [];
    }
  }
}
