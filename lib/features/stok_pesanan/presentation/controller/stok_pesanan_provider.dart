// File: lib/features/stok_pesanan/presentation/controller/stok_pesanan_provider.dart

import 'package:flutter/material.dart';
import '../../data/stok_pesanan_repository.dart';

// ─────────────────────────────────────────────────────────────────
// STOK & PESANAN PROVIDER
// ─────────────────────────────────────────────────────────────────

class StokPesananProvider extends ChangeNotifier {
  final _repo = StokPesananRepository();

  // Stok
  FilterStok _filter = FilterStok.semua;
  List<Map<String, dynamic>> _daftarStok = [];
  Map<String, int> _hitung = {};

  // Pesanan
  List<Map<String, dynamic>> _saranPesanan = [];
  Map<String, int> _ringkasanPesanan = {};

  bool _isLoading = false;
  String _errorPesan = '';

  // Getters
  FilterStok get filter => _filter;
  List<Map<String, dynamic>> get daftarStok => _daftarStok;
  Map<String, int> get hitung => _hitung;
  List<Map<String, dynamic>> get saranPesanan => _saranPesanan;
  bool get isLoading => _isLoading;
  String get errorPesan => _errorPesan;

  int get semua   => _hitung['semua'] ?? 0;
  int get habis   => _hitung['habis'] ?? 0;
  int get menipis => _hitung['menipis'] ?? 0;
  int get banyak  => _hitung['banyak'] ?? 0;

  int get pesananTotalItem  => _ringkasanPesanan['totalItem'] ?? 0;
  int get pesananTotalQty   => _ringkasanPesanan['totalQty'] ?? 0;
  int get pesananTotalBiaya => _ringkasanPesanan['totalBiaya'] ?? 0;

  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorPesan = '';
    notifyListeners();

    try {
      final results = await Future.wait([
        _repo.daftarStok(_filter),
        _repo.hitungStok(),
        _repo.saranPesanan(),
        _repo.ringkasanPesanan(),
      ]);
      _daftarStok       = results[0] as List<Map<String, dynamic>>;
      _hitung           = results[1] as Map<String, int>;
      _saranPesanan     = results[2] as List<Map<String, dynamic>>;
      _ringkasanPesanan = results[3] as Map<String, int>;
    } catch (e) {
      _errorPesan = 'Gagal memuat data: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setFilter(FilterStok f) async {
    _filter = f;
    _daftarStok = await _repo.daftarStok(f);
    notifyListeners();
  }
}