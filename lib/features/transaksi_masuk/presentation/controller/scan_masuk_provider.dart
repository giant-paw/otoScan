import 'package:flutter/material.dart';
import '../../data/transaksi_masuk_model.dart';
import '../../data/transaksi_masuk_repository.dart';
import '../../../master_barang/data/barang_model.dart';
import '../../../master_barang/data/master_repository.dart';
import '../../../master_barang/presentation/controller/master_provider.dart';

// ─────────────────────────────────────────────────────────────────
// STATE MACHINE
//
//  idle ──scan/pilih barang───────────────────► found
//  found ──scan KODE SAMA──────────────────────► found (qty +1)
//  found ──scan KODE BEDA──────────────────────► pendingSwitch
//  found ──scan tidak ada di master────────────► found (snack)
//  pendingSwitch ──simpan & ganti──────────────► simpan lama, jadi found baru
//  pendingSwitch ──abaikan─────────────────────► found (kembali ke aktif)
//  found / pendingSwitch ──simpan──────────────► idle
//  found ──batal───────────────────────────────► idle
//  idle ──scan tidak ada──────────────────────► notFound
//  notFound ──tutup────────────────────────────► idle
// ─────────────────────────────────────────────────────────────────

enum ScanStatus { idle, found, pendingSwitch, notFound, saving, error }

enum ScanResult {
  ignored,
  newFound,
  accumulated,
  switchNeeded,
  notFound,
  notFoundWhileActive,
}

class ScanMasukProvider extends ChangeNotifier {
  final _repo       = TransaksiMasukRepository();
  final _masterRepo = MasterRepository();
  MasterProvider? _masterProvider;

  ScanStatus _status       = ScanStatus.idle;
  Barang?    _barangAktif;
  Barang?    _barangPending;
  int        _qty          = 0;
  String     _errorPesan   = '';
  bool       _isLoading    = false;

  Map<String, Barang> _cache = {};
  bool _cacheLoaded = false;

  List<TransaksiMasuk> _riwayatSesi = [];

  static const int _maxQty = 9999;

  // ── Getters ──────────────────────────────────────────────────
  ScanStatus           get status        => _status;
  Barang?              get barangAktif   => _barangAktif;
  Barang?              get barangPending => _barangPending;
  int                  get qty           => _qty;
  String               get errorPesan    => _errorPesan;
  bool                 get isLoading     => _isLoading;
  bool                 get cacheLoaded   => _cacheLoaded;
  List<TransaksiMasuk> get riwayatSesi   => _riwayatSesi;

  int get totalItemSesi  => _riwayatSesi.fold(0, (s, t) => s + t.qty);
  int get totalModalSesi => _riwayatSesi.fold(0, (s, t) => s + t.totalModal);

  List<Barang> get allBarangForManual {
    final list = _cache.values.toList();
    list.sort((a, b) => a.namaBarang.compareTo(b.namaBarang));
    return list;
  }

  // ── INIT ──────────────────────────────────────────────────────
  Future<void> init(MasterProvider mp) async {
    _masterProvider = mp;
    _isLoading = true;
    notifyListeners();
    await Future.wait([_muatCache(), _muatRiwayat()]);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _muatCache() async {
    try {
      final list = await _masterRepo.getAllBarang(limit: 999999);
      _cache = {for (final b in list) b.kodeScan: b};
      _cacheLoaded = true;
    } catch (e) {
      _errorPesan = 'Gagal memuat data: $e';
      _cacheLoaded = false;
    }
  }

  Future<void> _muatRiwayat() async {
    try {
      _riwayatSesi = await _repo.getRiwayatHariIni();
    } catch (_) {
      _riwayatSesi = [];
    }
    notifyListeners();
  }

  // ── AUTOCOMPLETE / SEARCH ──────────────────────────────────────
  List<Barang> cariByKode(String keyword) {
    if (keyword.length < 2) return [];
    final kw = keyword.toUpperCase();
    return _cache.values
      .where((b) => b.kodeScan.toUpperCase().contains(kw))
      .take(10)
      .toList();
  }

  List<Barang> cariByNama(String keyword) {
    if (keyword.length < 2) return [];
    final kw = keyword.toLowerCase();
    return _cache.values
      .where((b) => b.namaBarang.toLowerCase().contains(kw))
      .take(10)
      .toList();
  }

  // ─────────────────────────────────────────────────────────────
  // PROSES SCAN
  // ─────────────────────────────────────────────────────────────
  ScanResult prosesScan(String kodeScan) {
    final kode = kodeScan.trim().toUpperCase();
    if (kode.isEmpty) return ScanResult.ignored;
    if (_status == ScanStatus.saving) return ScanResult.ignored;
    if (_status == ScanStatus.pendingSwitch) return ScanResult.ignored;

    final barang = _cache[kode];

    if (barang == null) {
      _errorPesan = 'Kode "$kode" tidak terdaftar di master barang.';
      if (_status == ScanStatus.found) {
        notifyListeners();
        return ScanResult.notFoundWhileActive;
      }
      _status = ScanStatus.notFound;
      notifyListeners();
      return ScanResult.notFound;
    }

    if (_status == ScanStatus.found && _barangAktif != null) {
      if (barang.kodeScan == _barangAktif!.kodeScan) {
        _qty = (_qty + 1).clamp(1, _maxQty);
        notifyListeners();
        return ScanResult.accumulated;
      } else {
        _barangPending = barang;
        _status = ScanStatus.pendingSwitch;
        notifyListeners();
        return ScanResult.switchNeeded;
      }
    }

    _barangAktif   = barang;
    _barangPending = null;
    _qty           = 1;
    _errorPesan    = '';
    _status        = ScanStatus.found;
    notifyListeners();
    return ScanResult.newFound;
  }

  // ─────────────────────────────────────────────────────────────
  // PILIH DARI AUTOCOMPLETE
  // ─────────────────────────────────────────────────────────────
  ScanResult pilihBarang(Barang barang) {
    if (_status == ScanStatus.saving) return ScanResult.ignored;
    if (_status == ScanStatus.pendingSwitch) return ScanResult.ignored;

    if (_status == ScanStatus.found && _barangAktif != null) {
      if (barang.kodeScan == _barangAktif!.kodeScan) {
        _qty = (_qty + 1).clamp(1, _maxQty);
        notifyListeners();
        return ScanResult.accumulated;
      } else {
        _barangPending = barang;
        _status = ScanStatus.pendingSwitch;
        notifyListeners();
        return ScanResult.switchNeeded;
      }
    }

    _barangAktif   = barang;
    _barangPending = null;
    _qty           = 1;
    _errorPesan    = '';
    _status        = ScanStatus.found;
    notifyListeners();
    return ScanResult.newFound;
  }

  // Alias untuk kompatibilitas mundur
  ScanResult pilihBarangManual(Barang barang) => pilihBarang(barang);

  // ─────────────────────────────────────────────────────────────
  // ★★★ FIX BUG NULL CHECK ★★★
  //
  // ROOT CAUSE bug sebelumnya:
  //   _doSimpan() me-reset _barangPending = null saat sukses,
  //   lalu kode di sini coba: _barangAktif = _barangPending → null
  //   Status di-set found tapi _barangAktif null → CRASH null check.
  //
  // FIX: Simpan _barangPending ke variabel lokal SEBELUM _doSimpan,
  //      lalu gunakan variabel itu setelah simpan selesai.
  // ─────────────────────────────────────────────────────────────
  Future<String?> konfirmasiSwitch() async {
    if (_barangPending == null || _barangAktif == null) return null;

    // SIMPAN reference sebelum _doSimpan menghapusnya
    final Barang pendingTemp = _barangPending!;

    // _doSimpan akan reset _barangPending dan _barangAktif jadi null
    final err = await _doSimpan(_qty);
    if (err != null) {
      // Kalau gagal simpan, biarkan _barangPending tetap utuh
      // agar user bisa coba lagi atau batal
      _barangPending = pendingTemp;
      _status = ScanStatus.pendingSwitch;
      notifyListeners();
      return err;
    }

    // Sukses: pindahkan pending → aktif
    _barangAktif   = pendingTemp;   // ← pakai variabel lokal, bukan _barangPending
    _barangPending = null;
    _qty           = 1;
    _errorPesan    = '';
    _status        = ScanStatus.found;
    notifyListeners();
    return null;
  }

  void batalSwitch() {
    _barangPending = null;
    _status        = ScanStatus.found;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // QTY CONTROL
  // ─────────────────────────────────────────────────────────────
  void setQty(int nilai) {
    _qty = nilai.clamp(0, _maxQty);
    notifyListeners();
  }

  void resetQty() {
    _qty = 1;
    notifyListeners();
  }

  // Kosongkan qty (untuk tombol "Hapus angka")
  void kosongkanQty() {
    _qty = 0;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // SIMPAN
  // ─────────────────────────────────────────────────────────────
  Future<String?> simpanTransaksi() async {
    if (_barangAktif == null) return 'Tidak ada barang yang dipilih.';
    if (_qty <= 0)             return 'Jumlah harus lebih dari 0.';
    if (_qty > _maxQty)        return 'Jumlah terlalu besar (maks $_maxQty).';
    return _doSimpan(_qty);
  }

  Future<String?> _doSimpan(int qty) async {
    if (_barangAktif == null || qty <= 0) return 'Data tidak valid.';

    _status = ScanStatus.saving;
    notifyListeners();

    final now = DateTime.now();
    final t = TransaksiMasuk(
      kodeScan:         _barangAktif!.kodeScan,
      qty:              qty,
      hargaAstraSatuan: _barangAktif!.hargaAstra,
      tanggal:          _fmt(now),
      jam:              _jam(now),
      namaBarang:       _barangAktif!.namaBarang,
      kategori:         _barangAktif!.kategori,
    );

    final err = await _repo.simpan(t);

    if (err == null) {
      final lama = _cache[_barangAktif!.kodeScan];
      if (lama != null) {
        _cache[lama.kodeScan] = lama.copyWith(stokSisa: lama.stokSisa + qty);
      }
      _status        = ScanStatus.idle;
      _barangAktif   = null;
      _barangPending = null;
      _qty           = 0;
      _errorPesan    = '';
      await _muatRiwayat();
      _masterProvider?.loadData();
    } else {
      _status     = ScanStatus.error;
      _errorPesan = err;
    }

    notifyListeners();
    return err;
  }

  // ─────────────────────────────────────────────────────────────
  // HAPUS RIWAYAT
  // ─────────────────────────────────────────────────────────────
  Future<String?> hapusRiwayat(TransaksiMasuk t) async {
    if (t.id == null) return 'ID transaksi tidak ditemukan.';
    final err = await _repo.hapus(t.id!, t.kodeScan, t.qty);
    if (err == null) {
      final b = _cache[t.kodeScan];
      if (b != null) {
        _cache[t.kodeScan] = b.copyWith(
          stokSisa: (b.stokSisa - t.qty).clamp(0, 999999),
        );
      }
      await _muatRiwayat();
      _masterProvider?.loadData();
    }
    notifyListeners();
    return err;
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  Future<void> refreshCache(MasterProvider mp) async {
    _masterProvider = mp;
    await _muatCache();
    notifyListeners();
  }

  void tambahKeCache(Barang barang) {
    _cache[barang.kodeScan] = barang;
    notifyListeners();
  }

  void reset() {
    _status        = ScanStatus.idle;
    _barangAktif   = null;
    _barangPending = null;
    _qty           = 0;
    _errorPesan    = '';
    notifyListeners();
  }

  String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  String _jam(DateTime d) =>
    '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}:${d.second.toString().padLeft(2,'0')}';
}