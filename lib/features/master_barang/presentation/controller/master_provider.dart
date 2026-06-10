import 'package:flutter/material.dart';
import '../../data/barang_model.dart';
import '../../data/master_repository.dart';

class MasterProvider extends ChangeNotifier {
  final MasterRepository _repository = MasterRepository();
  
  List<BarangModel> _listBarang = [];
  bool _isLoading = false;

  List<BarangModel> get listBarang => _listBarang;
  bool get isLoading => _isLoading;

  Future<void> loadData([String keyword = '']) async {
    _isLoading = true;
    notifyListeners();

    _listBarang = await _repository.searchBarang(keyword);

    _isLoading = false;
    notifyListeners();
  }

  // Fungsi Tambah Barang Baru
  Future<void> tambahBarang(BarangModel barang) async {
    await _repository.insertBarang(barang);
    await loadData();
  }

  // Fungsi Hapus Barang
  Future<void> hapusBarang(String kodeScan) async {
    await _repository.deleteBarang(kodeScan);
    await loadData(); // Otomatis refresh
  }
}