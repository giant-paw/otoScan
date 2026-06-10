import 'package:flutter/material.dart';
import '../../data/barang_model.dart';
import '../../data/master_repository.dart';

class MasterProvider extends ChangeNotifier {
  final _repo = MasterRepository();

  List<Barang> _semuaBarang = [];
  List<Barang> _tampilBarang = []; 
  bool _isLoading = false;
  String _errorMessage = '';
  String _searchKeyword = '';

  // ─── FITUR BARU: FILTER & MULTI-SELECT ────────
  String _kategoriFilter = 'Semua';
  final Set<String> _selectedItems = {}; // Menyimpan kode_scan yang dicentang

  List<Barang> get tampilBarang => _tampilBarang;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get totalBarang => _semuaBarang.length;
  
  String get kategoriFilter => _kategoriFilter;
  Set<String> get selectedItems => _selectedItems;
  bool get isMultiSelectMode => _selectedItems.isNotEmpty;

  // ─── LOAD awal ────
  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _semuaBarang = await _repo.getAllBarang();
      _terapkanFilterDanPencarian(); // Gunakan fungsi terpusat
    } catch (e) {
      _errorMessage = 'Gagal memuat data: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── GANTI FILTER KATEGORI ───────────────────
  void setKategoriFilter(String kategori) {
    _kategoriFilter = kategori;
    _selectedItems.clear(); // Bersihkan centangan jika ganti filter
    _terapkanFilterDanPencarian();
  }

  // ─── SEARCH real-time ────────────────────────
  Future<void> cariBarang(String keyword) async {
    _searchKeyword = keyword;
    
    // Jika data tidak ada di memori lokal, cari ke DB
    if (keyword.isNotEmpty) {
      final lokal = _semuaBarang.where((b) {
        return b.namaBarang.toLowerCase().contains(keyword.toLowerCase()) ||
            b.kodeScan.toLowerCase().contains(keyword.toLowerCase());
      }).toList();

      if (lokal.isEmpty) {
        // Ambil dari DB lalu gabungkan ke semuaBarang (cache)
        final dariDb = await _repo.searchBarang(keyword);
        for (var b in dariDb) {
          if (!_semuaBarang.any((seb) => seb.kodeScan == b.kodeScan)) {
            _semuaBarang.add(b);
          }
        }
      }
    }
    
    _terapkanFilterDanPencarian();
  }

  // Fungsi internal untuk memfilter data tampil
  void _terapkanFilterDanPencarian() {
    List<Barang> hasil = _semuaBarang;

    // 1. Filter Pencarian Teks
    if (_searchKeyword.isNotEmpty) {
      hasil = hasil.where((b) => 
        b.namaBarang.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
        b.kodeScan.toLowerCase().contains(_searchKeyword.toLowerCase())
      ).toList();
    }

    // 2. Filter Kategori Dropdown
    if (_kategoriFilter != 'Semua') {
      hasil = hasil.where((b) => b.kategori == _kategoriFilter).toList();
    }

    _tampilBarang = hasil;
    notifyListeners();
  }

  // ─── LOGIKA MULTI-SELECT (CENTANG BOX) ───────
  void toggleItem(String kodeScan) {
    if (_selectedItems.contains(kodeScan)) {
      _selectedItems.remove(kodeScan);
    } else {
      _selectedItems.add(kodeScan);
    }
    notifyListeners();
  }

  void toggleSelectAll() {
    // Hanya pilih/hapus yang sedang TAMPIL di layar
    final visibleKodes = _tampilBarang.map((b) => b.kodeScan).toSet();
    final allSelected = visibleKodes.every((kode) => _selectedItems.contains(kode));

    if (allSelected) {
      _selectedItems.removeAll(visibleKodes);
    } else {
      _selectedItems.addAll(visibleKodes);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedItems.clear();
    notifyListeners();
  }

  // ─── HAPUS BANYAK BARANG ─────────────────────
  Future<String?> hapusBarangTerpilih() async {
    int sukses = 0;
    for (String kode in _selectedItems) {
      final berhasil = await _repo.deleteBarang(kode);
      if (berhasil) sukses++;
    }

    if (sukses > 0) {
      _semuaBarang.removeWhere((b) => _selectedItems.contains(b.kodeScan));
      _selectedItems.clear();
      _terapkanFilterDanPencarian();
      return null; // Sukses
    }
    return 'Gagal menghapus barang yang dipilih.';
  }

  // ─── TAMBAH barang baru ──────────────────────
  Future<String?> tambahBarang(Barang barang) async {
    final sudahAda = await _repo.isKodeExist(barang.kodeScan);
    if (sudahAda) return 'Kode "${barang.kodeScan}" sudah terdaftar!';

    final berhasil = await _repo.insertBarang(barang);
    if (berhasil) {
      _semuaBarang.add(barang);
      _semuaBarang.sort((a, b) => a.namaBarang.compareTo(b.namaBarang));
      _terapkanFilterDanPencarian();
      return null; 
    }
    return 'Gagal menyimpan barang.';
  }

  // ─── EDIT barang ─────────────────────────────
  Future<String?> editBarang(Barang barang) async {
    final berhasil = await _repo.updateBarang(barang);
    if (berhasil) {
      final idx = _semuaBarang.indexWhere((b) => b.kodeScan == barang.kodeScan);
      if (idx != -1) _semuaBarang[idx] = barang;
      _terapkanFilterDanPencarian();
      return null;
    }
    return 'Gagal memperbarui data.';
  }

  // ─── HAPUS SATU barang ───────────────────────
  Future<String?> hapusBarang(String kodeScan) async {
    final berhasil = await _repo.deleteBarang(kodeScan);
    if (berhasil) {
      _semuaBarang.removeWhere((b) => b.kodeScan == kodeScan);
      _selectedItems.remove(kodeScan);
      _terapkanFilterDanPencarian();
      return null;
    }
    return 'Gagal menghapus barang.';
  }
}