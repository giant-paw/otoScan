// File: lib/features/pelanggan/presentation/controller/pelanggan_provider.dart

import 'package:flutter/material.dart';
import '../../data/pelanggan_model.dart';
import '../../data/pelanggan_repository.dart';

// ─────────────────────────────────────────────────────────────────
// PELANGGAN PROVIDER
//
// Bertanggung jawab:
//   - Cache list pelanggan untuk autocomplete cepat di dialog kasir
//   - CRUD pelanggan (kalau nanti dibuat menu master pelanggan)
//   - Refresh cache setelah checkout (pelanggan baru otomatis dibuat)
//
// PENTING: cache di-refresh otomatis setelah simpan nota
//          (dipanggil dari KasirProvider via callback)
// ─────────────────────────────────────────────────────────────────

class PelangganProvider extends ChangeNotifier {
  final _repo = PelangganRepository();

  List<Pelanggan> _cache = [];
  bool _isLoading = false;
  String _errorPesan = '';

  // ── Getters ──────────────────────────────────────────────────
  List<Pelanggan> get all       => _cache;
  bool            get isLoading => _isLoading;
  String          get errorPesan => _errorPesan;

  // Pelanggan yang punya hutang aktif (untuk buku piutang)
  List<Pelanggan> get punyaHutang =>
    _cache.where((p) => p.punyaHutang).toList()
      ..sort((a, b) => b.totalHutangAktif.compareTo(a.totalHutangAktif));

  int get totalPiutangSemuaPelanggan =>
    _cache.fold(0, (sum, p) => sum + p.totalHutangAktif);

  // ─────────────────────────────────────────────────────────────
  // INIT — load semua pelanggan ke cache
  // ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    await _muatCache();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _muatCache() async {
    try {
      _cache = await _repo.getAll();
      _errorPesan = '';
    } catch (e) {
      _errorPesan = 'Gagal memuat pelanggan: $e';
      _cache = [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // REFRESH — dipanggil setelah checkout sukses (pelanggan baru)
  // ─────────────────────────────────────────────────────────────
  Future<void> refresh() async {
    await _muatCache();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH AUTOCOMPLETE — untuk dialog kasir
  // Cari di cache (instant), tidak query DB
  // ─────────────────────────────────────────────────────────────
  List<Pelanggan> cari(String keyword) {
    if (keyword.trim().length < 2) return [];
    final kw = keyword.trim().toLowerCase();
    return _cache.where((p) {
      final namaMatch = p.nama.toLowerCase().contains(kw);
      final hpMatch   = (p.noHp ?? '').toLowerCase().contains(kw);
      return namaMatch || hpMatch;
    }).take(10).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // CRUD (untuk menu master pelanggan nanti)
  // ─────────────────────────────────────────────────────────────
  Future<String?> tambah(Pelanggan p) async {
    final id = await _repo.tambah(p);
    if (id == null) return 'Gagal menambah pelanggan';
    await refresh();
    return null;
  }

  Future<String?> update(Pelanggan p) async {
    final err = await _repo.update(p);
    if (err == null) await refresh();
    return err;
  }

  Future<String?> hapus(int id) async {
    final err = await _repo.hapus(id);
    if (err == null) await refresh();
    return err;
  }

  Pelanggan? getById(int id) {
    try {
      return _cache.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
