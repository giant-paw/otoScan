// File: lib/features/transaksi_keluar/presentation/controller/cart_provider.dart

import 'package:flutter/material.dart';
import '../../../master_barang/data/barang_model.dart';
import '../../../master_barang/data/master_repository.dart';
import '../../data/transaksi_keluar_detail_model.dart';

// ─────────────────────────────────────────────────────────────────
// CART PROVIDER — state keranjang belanja
//
// Skenario yang ditangani:
//   - Scan barang → masuk cart (qty=1) atau akumulasi jika sudah ada
//   - Edit qty (+/-, manual input) dengan validasi stok
//   - Hapus item dari cart
//   - Kosongkan cart
//   - Validasi: stok cukup, harga jual > 0
//
// State machine:
//   idle      → empty atau ada item
//   adding    → barang baru di-add ke cart
//   updating  → qty di-edit
//   error     → stok kurang, dll
//
// Cache barang di-load saat init untuk performa scan.
// ─────────────────────────────────────────────────────────────────

enum CartStatus { idle, ready, error }

enum AddResult {
  added,          // barang baru masuk cart
  accumulated,    // kode sama → qty +1
  stokHabis,      // stok 0
  stokTidakCukup, // stok < qty diminta
  hargaJualKosong,// harga jual = 0 (tolak)
  notFound,       // kode tidak ada di master
}

class CartProvider extends ChangeNotifier {
  final _masterRepo = MasterRepository();

  // ── State ────────────────────────────────────────────────────
  final List<CartItem> _items = [];
  CartStatus _status = CartStatus.idle;
  String _errorPesan = '';
  bool _isLoading = false;

  // ── Cache master untuk scan cepat ────────────────────────────
  Map<String, Barang> _cache = {};
  bool _cacheLoaded = false;

  // ── Getters ──────────────────────────────────────────────────
  List<CartItem> get items        => List.unmodifiable(_items);
  CartStatus     get status       => _status;
  String         get errorPesan   => _errorPesan;
  bool           get isLoading    => _isLoading;
  bool           get cacheLoaded  => _cacheLoaded;
  bool           get isEmpty      => _items.isEmpty;
  bool           get isNotEmpty   => _items.isNotEmpty;
  int            get jumlahItem   => _items.length;
  int            get totalQty     => _items.fold(0, (s, i) => s + i.qty);

  int get totalTagihan => _items.fold(0, (s, i) => s + i.subtotalJual);
  int get totalModal   => _items.fold(0, (s, i) => s + i.subtotalModal);
  int get totalLaba    => _items.fold(0, (s, i) => s + i.subtotalLaba);

  // ─────────────────────────────────────────────────────────────
  // INIT — load cache barang
  // ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    await _muatCache();
    _isLoading = false;
    _status = _cacheLoaded ? CartStatus.ready : CartStatus.error;
    notifyListeners();
  }

  Future<void> _muatCache() async {
    try {
      final list = await _masterRepo.getAllBarang(limit: 999999);
      _cache = {for (final b in list) b.kodeScan: b};
      _cacheLoaded = true;
      _errorPesan = '';
    } catch (e) {
      _errorPesan = 'Gagal memuat data barang: $e';
      _cacheLoaded = false;
    }
  }

  // Refresh cache setelah ada perubahan stok dari fitur lain
  Future<void> refreshCache() async {
    await _muatCache();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH untuk autocomplete (kode atau nama)
  // ─────────────────────────────────────────────────────────────
  List<Barang> cariByKode(String kw) {
    if (kw.length < 2) return [];
    final s = kw.toUpperCase();
    return _cache.values
        .where((b) => b.kodeScan.toUpperCase().contains(s))
        .take(10).toList();
  }

  List<Barang> cariByNama(String kw) {
    if (kw.length < 2) return [];
    final s = kw.toLowerCase();
    return _cache.values
        .where((b) => b.namaBarang.toLowerCase().contains(s))
        .take(10).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // ★ SCAN / TAMBAH BARANG KE CART ★
  //
  // Skenario:
  //   - Kode tidak ada di master → notFound
  //   - Stok 0 → stokHabis (TOLAK, sesuai Aturan Besi A)
  //   - Harga jual 0 → hargaJualKosong (TOLAK, untuk safety)
  //   - Sudah ada di cart → akumulasi qty (cek stok)
  //   - Belum ada → tambah baru
  // ─────────────────────────────────────────────────────────────
  AddResult tambahByKode(String kodeScan) {
    final kode = kodeScan.trim().toUpperCase();
    if (kode.isEmpty) return AddResult.notFound;

    final barang = _cache[kode];
    if (barang == null) {
      _errorPesan = 'Kode "$kode" tidak terdaftar';
      notifyListeners();
      return AddResult.notFound;
    }

    return tambahBarang(barang);
  }

  AddResult tambahBarang(Barang barang) {
    // Aturan Besi A: stok 0 = tolak
    if (barang.stokSisa <= 0) {
      _errorPesan = '${barang.namaBarang} stok habis';
      notifyListeners();
      return AddResult.stokHabis;
    }

    // Aturan: harga jual harus > 0
    if (barang.hargaJual <= 0) {
      _errorPesan = '${barang.namaBarang} belum punya harga jual';
      notifyListeners();
      return AddResult.hargaJualKosong;
    }

    // Cek apakah sudah ada di cart
    final existingIdx = _items.indexWhere(
      (i) => i.barang.kodeScan == barang.kodeScan,
    );

    if (existingIdx >= 0) {
      // ── Akumulasi qty ──
      final item = _items[existingIdx];
      // Cek stok: qty di cart + 1 tidak boleh melebihi stok master
      if (item.qty + 1 > barang.stokSisa) {
        _errorPesan =
          'Stok ${barang.namaBarang} tidak cukup '
          '(tersedia ${barang.stokSisa}, di keranjang ${item.qty})';
        notifyListeners();
        return AddResult.stokTidakCukup;
      }
      item.qty += 1;
      _errorPesan = '';
      notifyListeners();
      return AddResult.accumulated;
    }

    // ── Tambah baru ──
    _items.add(CartItem(barang: barang, qty: 1));
    _errorPesan = '';
    notifyListeners();
    return AddResult.added;
  }

  // ─────────────────────────────────────────────────────────────
  // EDIT QTY MANUAL — dari TextField di cart
  // ─────────────────────────────────────────────────────────────
  String? setQty(int index, int qtyBaru) {
    if (index < 0 || index >= _items.length) return 'Item tidak valid';
    if (qtyBaru <= 0) return 'Qty harus lebih dari 0';

    final item = _items[index];
    if (qtyBaru > item.barang.stokSisa) {
      return 'Stok ${item.barang.namaBarang} hanya ${item.barang.stokSisa}';
    }

    item.qty = qtyBaru;
    _errorPesan = '';
    notifyListeners();
    return null;
  }

  String? tambahQty(int index) {
    if (index < 0 || index >= _items.length) return 'Item tidak valid';
    final item = _items[index];
    if (item.qty + 1 > item.barang.stokSisa) {
      return 'Stok hanya ${item.barang.stokSisa}';
    }
    item.qty += 1;
    notifyListeners();
    return null;
  }

  String? kurangQty(int index) {
    if (index < 0 || index >= _items.length) return 'Item tidak valid';
    final item = _items[index];
    if (item.qty <= 1) {
      // Qty 1 dan dikurangi → hapus item
      _items.removeAt(index);
    } else {
      item.qty -= 1;
    }
    notifyListeners();
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // HAPUS ITEM dari cart
  // ─────────────────────────────────────────────────────────────
  void hapusItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // KOSONGKAN cart (setelah checkout sukses atau klik "Kosongkan")
  // ─────────────────────────────────────────────────────────────
  void kosongkan() {
    _items.clear();
    _errorPesan = '';
    _status = CartStatus.ready;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // SETELAH CHECKOUT: update cache stok lokal
  // Dipanggil oleh KasirProvider setelah simpan nota sukses
  // ─────────────────────────────────────────────────────────────
  void updateCacheStokSetelahCheckout(List<CartItem> cartTersimpan) {
    for (final item in cartTersimpan) {
      final b = _cache[item.barang.kodeScan];
      if (b != null) {
        _cache[b.kodeScan] = b.copyWith(
          stokSisa: (b.stokSisa - item.qty).clamp(0, 999999),
        );
      }
    }
    notifyListeners();
  }

  void clearError() {
    _errorPesan = '';
    notifyListeners();
  }
}
