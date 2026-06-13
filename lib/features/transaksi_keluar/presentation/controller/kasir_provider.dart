// File: lib/features/transaksi_keluar/presentation/controller/kasir_provider.dart

import 'package:flutter/material.dart';
import '../../data/transaksi_keluar_detail_model.dart';
import '../../data/transaksi_keluar_repository.dart';
import '../../../master_barang/presentation/controller/master_provider.dart';
import '../../../pelanggan/presentation/controller/pelanggan_provider.dart';
import 'cart_provider.dart';

// ─────────────────────────────────────────────────────────────────
// KASIR PROVIDER — state dialog pembayaran (checkout)
//
// Lifecycle:
//   1. View buka dialog → KasirProvider.mulai(totalTagihan)
//   2. User input "uang diterima" → setUangDiterima()
//      → auto-hitung: status (LUNAS/HUTANG), kembalian, sisaHutang
//   3. Jika HUTANG → form pelanggan muncul (nama wajib)
//   4. User isi nama + HP (autocomplete) → set fields
//   5. User klik SIMPAN → simpanNota() → atomic transaction
//   6. Reset state untuk transaksi berikutnya
//
// PENTING: provider ini tidak persist data. Hanya state sementara
//          selama dialog terbuka. Setelah submit, reset.
// ─────────────────────────────────────────────────────────────────

enum StatusBayar { lunas, hutang }

class KasirProvider extends ChangeNotifier {
  final _repo = TransaksiKeluarRepository();

  // ── State pembayaran ─────────────────────────────────────────
  int _totalTagihan = 0;
  int _uangDiterima = 0;

  // ── State pelanggan (saat hutang) ────────────────────────────
  int? _pelangganIdSelected;  // dari autocomplete (null = pelanggan baru)
  String _namaPelanggan = '';
  String _noHpPelanggan = '';
  String _alamatPelanggan = '';
  String _catatan = '';

  // ── State proses ─────────────────────────────────────────────
  bool _isSaving = false;
  String _errorPesan = '';
  String? _lastNoNota; // nota terakhir yang berhasil disimpan

  // ── Getters ──────────────────────────────────────────────────
  int  get totalTagihan      => _totalTagihan;
  int  get uangDiterima      => _uangDiterima;
  int? get pelangganIdSelected => _pelangganIdSelected;
  String get namaPelanggan   => _namaPelanggan;
  String get noHpPelanggan   => _noHpPelanggan;
  String get alamatPelanggan => _alamatPelanggan;
  String get catatan         => _catatan;
  bool   get isSaving        => _isSaving;
  String get errorPesan      => _errorPesan;
  String? get lastNoNota     => _lastNoNota;

  // ── Computed getters ─────────────────────────────────────────
  StatusBayar get status =>
    _uangDiterima >= _totalTagihan ? StatusBayar.lunas : StatusBayar.hutang;

  bool get isLunas  => status == StatusBayar.lunas;
  bool get isHutang => status == StatusBayar.hutang;

  int get kembalian =>
    isLunas ? (_uangDiterima - _totalTagihan) : 0;

  int get sisaHutang =>
    isHutang ? (_totalTagihan - _uangDiterima) : 0;

  // Apakah form pelanggan valid (untuk enable tombol Simpan)
  bool get isValid {
    if (_totalTagihan <= 0) return false;
    if (_uangDiterima < 0) return false;
    if (isHutang) {
      // Hutang: nama WAJIB
      if (_namaPelanggan.trim().isEmpty) return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────
  // MULAI — buka dialog kasir dengan total tagihan dari cart
  // ─────────────────────────────────────────────────────────────
  void mulai(int totalTagihan) {
    _totalTagihan = totalTagihan;
    _uangDiterima = totalTagihan; // default: pas (lunas)
    _pelangganIdSelected = null;
    _namaPelanggan = '';
    _noHpPelanggan = '';
    _alamatPelanggan = '';
    _catatan = '';
    _isSaving = false;
    _errorPesan = '';
    _lastNoNota = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // SET UANG DITERIMA
  // ─────────────────────────────────────────────────────────────
  void setUangDiterima(int nilai) {
    _uangDiterima = nilai.clamp(0, 999999999);
    notifyListeners();
  }

  // Quick buttons
  void setUangPas() {
    _uangDiterima = _totalTagihan;
    notifyListeners();
  }

  void tambahUang(int nominal) {
    _uangDiterima = (_uangDiterima + nominal).clamp(0, 999999999);
    notifyListeners();
  }

  // Round up ke nominal terdekat
  void setUangRoundUp(int nominal) {
    // Misal total 87.500, klik 100K → set ke 100.000
    final hasil = ((_totalTagihan / nominal).ceil()) * nominal;
    _uangDiterima = hasil;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // SET PELANGGAN (dari autocomplete atau manual)
  // ─────────────────────────────────────────────────────────────
  void pilihPelangganDariAutocomplete({
    required int id,
    required String nama,
    String? noHp,
    String? alamat,
  }) {
    _pelangganIdSelected = id;
    _namaPelanggan = nama;
    _noHpPelanggan = noHp ?? '';
    _alamatPelanggan = alamat ?? '';
    notifyListeners();
  }

  void setNamaPelanggan(String nama) {
    _namaPelanggan = nama;
    // Reset selected jika user ngetik manual (mungkin pelanggan baru)
    _pelangganIdSelected = null;
    notifyListeners();
  }

  void setNoHpPelanggan(String hp) {
    _noHpPelanggan = hp;
    notifyListeners();
  }

  void setAlamatPelanggan(String alamat) {
    _alamatPelanggan = alamat;
    notifyListeners();
  }

  void setCatatan(String c) {
    _catatan = c;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // ★★★ SIMPAN NOTA ★★★
  //
  // Validasi → panggil repository → handle hasil.
  // Setelah sukses, refresh provider lain (cart, pelanggan, master).
  // ─────────────────────────────────────────────────────────────
  Future<String?> simpanNota({
    required CartProvider cartProvider,
    required PelangganProvider pelangganProvider,
    required MasterProvider masterProvider,
  }) async {
    if (!isValid) {
      _errorPesan = isHutang && _namaPelanggan.trim().isEmpty
          ? 'Nama pelanggan wajib diisi untuk hutang'
          : 'Data tidak valid';
      notifyListeners();
      return _errorPesan;
    }

    if (cartProvider.isEmpty) {
      _errorPesan = 'Keranjang kosong';
      notifyListeners();
      return _errorPesan;
    }

    _isSaving = true;
    _errorPesan = '';
    notifyListeners();

    final result = await _repo.simpanNota(
      cart: cartProvider.items,
      uangDiterima: _uangDiterima,
      namaPelanggan: _namaPelanggan.trim().isEmpty ? null : _namaPelanggan.trim(),
      noHpPelanggan: _noHpPelanggan.trim().isEmpty ? null : _noHpPelanggan.trim(),
      alamatPelanggan: _alamatPelanggan.trim().isEmpty ? null : _alamatPelanggan.trim(),
      catatan: _catatan.trim().isEmpty ? null : _catatan.trim(),
    );

    _isSaving = false;

    if (result['error'] != null) {
      _errorPesan = result['error']!;
      notifyListeners();
      return _errorPesan;
    }

    // ── Sukses: update state ──
    _lastNoNota = result['noNota'];

    // Update cache stok di CartProvider (sebelum cart di-clear)
    cartProvider.updateCacheStokSetelahCheckout(cartProvider.items);

    // Kosongkan cart
    cartProvider.kosongkan();

    // Refresh pelanggan (kalau ada pelanggan baru terdaftar)
    await pelangganProvider.refresh();

    // Refresh master barang (stok berubah)
    masterProvider.loadData();

    notifyListeners();
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // RESET — setelah dialog ditutup
  // ─────────────────────────────────────────────────────────────
  void reset() {
    _totalTagihan = 0;
    _uangDiterima = 0;
    _pelangganIdSelected = null;
    _namaPelanggan = '';
    _noHpPelanggan = '';
    _alamatPelanggan = '';
    _catatan = '';
    _isSaving = false;
    _errorPesan = '';
    _lastNoNota = null;
    notifyListeners();
  }

  void clearError() {
    _errorPesan = '';
    notifyListeners();
  }
}
