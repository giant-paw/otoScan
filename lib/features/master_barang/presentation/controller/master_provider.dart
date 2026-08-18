import 'package:flutter/material.dart';
import '../../data/barang_model.dart';
import '../../data/master_repository.dart';

// ─────────────────────────────────────────────────────────────────
// FILTER STOK — untuk tab/chip filter di Master Barang
//   semua   : tampilkan semua
//   habis   : stok = 0
//   menipis : stok 1..5 (perlu segera dipesan)
//   banyak  : stok > 20 (menumpuk)
// ─────────────────────────────────────────────────────────────────
enum FilterStok { semua, habis, menipis, banyak }

class MasterProvider extends ChangeNotifier {
  final _repo = MasterRepository();

  List<Barang> _semuaBarang = [];
  List<Barang> _tampilBarang = []; // Yang tampil di tabel (search + filter)
  bool _isLoading = false;
  String _errorMessage = '';
  String _searchKeyword = '';
  FilterStok _filterStok = FilterStok.semua;

  // Ambang batas (samakan dengan Stok & Pesanan)
  static const int batasMenipis = 5;  // 1..5
  static const int batasBanyak  = 20; // > 20

  // ─── Getters ─────────────────────────────────
  List<Barang> get tampilBarang => _tampilBarang;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get totalBarang => _semuaBarang.length;
  FilterStok get filterStok => _filterStok;

  // Hitung jumlah per kategori stok (untuk badge di chip)
  int get jumlahSemua   => _semuaBarang.length;
  int get jumlahHabis   => _semuaBarang.where((b) => b.stokSisa == 0).length;
  int get jumlahMenipis => _semuaBarang.where((b) => b.stokSisa > 0 && b.stokSisa <= batasMenipis).length;
  int get jumlahBanyak  => _semuaBarang.where((b) => b.stokSisa > batasBanyak).length;

  // ─── LOAD awal (dipanggil dari main.dart) ────
  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _semuaBarang = await _repo.getAllBarang();
      _terapkanFilter();
    } catch (e) {
      _errorMessage = 'Gagal memuat data: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── SEARCH real-time ────────────────────────
  Future<void> cariBarang(String keyword) async {
    _searchKeyword = keyword;
    _terapkanFilter();
    notifyListeners();
  }

  // ─── SET FILTER STOK ─────────────────────────
  void setFilterStok(FilterStok filter) {
    _filterStok = filter;
    _terapkanFilter();
    notifyListeners();
  }

  // ─── Terapkan search + filter stok bersama ───
  void _terapkanFilter() {
    Iterable<Barang> hasil = _semuaBarang;

    // 1. Filter stok
    switch (_filterStok) {
      case FilterStok.habis:
        hasil = hasil.where((b) => b.stokSisa == 0);
        break;
      case FilterStok.menipis:
        hasil = hasil.where((b) => b.stokSisa > 0 && b.stokSisa <= batasMenipis);
        break;
      case FilterStok.banyak:
        hasil = hasil.where((b) => b.stokSisa > batasBanyak);
        break;
      case FilterStok.semua:
        break;
    }

    // 2. Filter search keyword
    if (_searchKeyword.trim().isNotEmpty) {
      final k = _searchKeyword.toLowerCase();
      hasil = hasil.where((b) =>
          b.namaBarang.toLowerCase().contains(k) ||
          b.kodeScan.toLowerCase().contains(k));
    }

    _tampilBarang = hasil.toList();
  }

  // ─── TAMBAH barang baru ──────────────────────
  Future<String?> tambahBarang(Barang barang) async {
    final sudahAda = await _repo.isKodeExist(barang.kodeScan);
    if (sudahAda) {
      return 'Kode "${barang.kodeScan}" sudah terdaftar!';
    }

    final berhasil = await _repo.insertBarang(barang);
    if (berhasil) {
      _semuaBarang.add(barang);
      _semuaBarang.sort((a, b) => a.namaBarang.compareTo(b.namaBarang));
      _terapkanFilter();
      notifyListeners();
      return null;
    }
    return 'Gagal menyimpan barang.';
  }

  // ─── EDIT barang ─────────────────────────────
  // kodeScanLama opsional: dipakai kalau kode diubah saat edit,
  // supaya baris lama di memori tetap ketemu. Kalau tidak diisi,
  // pakai kodeScan barang itu sendiri.
  Future<String?> editBarang(Barang barang, [String? kodeScanLama]) async {
    final kodeLama = kodeScanLama ?? barang.kodeScan;
    final berhasil = await _repo.updateBarang(barang);
    if (berhasil) {
      final idx = _semuaBarang.indexWhere((b) => b.kodeScan == kodeLama);
      if (idx != -1) _semuaBarang[idx] = barang;
      _terapkanFilter();
      notifyListeners();
      return null;
    }
    return 'Gagal memperbarui data.';
  }

  // ─── HAPUS barang ────────────────────────────
  Future<String?> hapusBarang(String kodeScan) async {
    final berhasil = await _repo.deleteBarang(kodeScan);
    if (berhasil) {
      _semuaBarang.removeWhere((b) => b.kodeScan == kodeScan);
      _terapkanFilter();
      notifyListeners();
      return null;
    }
    return 'Gagal menghapus barang.';
  }
}