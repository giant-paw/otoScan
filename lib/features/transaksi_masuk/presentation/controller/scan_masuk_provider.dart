import 'package:flutter/material.dart';
import '../../data/transaksi_masuk_model.dart';
import '../../data/transaksi_masuk_repository.dart';
import '../../../master_barang/data/barang_model.dart';
import '../../../master_barang/data/master_repository.dart';
import '../../../master_barang/presentation/controller/master_provider.dart';

// ─────────────────────────────────────────────────────────────────
// Status setelah scan satu kode
// ─────────────────────────────────────────────────────────────────
enum ScanStatus { idle, found, notFound, saving, saved, error }

class ScanMasukProvider extends ChangeNotifier {
  final _repo     = TransaksiMasukRepository();
  final _masterRepo = MasterRepository();

  // Referensi ke MasterProvider agar bisa reload stok setelah simpan
  MasterProvider? masterProvider;

  // ── State satu scan ──────────────────────────
  ScanStatus _status = ScanStatus.idle;
  Barang? _barangDitemukan;   // hasil lookup dari cache
  String _errorPesan = '';
  String _lastScannedKode = ''; // Tempat menyimpan kode terakhir yang di-scan

  // ── Riwayat sesi hari ini ────────────────────
  List<TransaksiMasuk> _riwayatSesi = [];

  // ── Cache master barang (dimuat sekali) ──────
  Map<String, Barang> _cacheBarang = {};
  bool _cacheLoaded = false;

  // ── Getters ──────────────────────────────────
  ScanStatus get status         => _status;
  Barang? get barangDitemukan   => _barangDitemukan;
  String get errorPesan         => _errorPesan;
  List<TransaksiMasuk> get riwayatSesi => _riwayatSesi;
  bool get cacheLoaded          => _cacheLoaded;
  String get lastScannedKode    => _lastScannedKode; // Getter untuk dibaca oleh UI View

  int get totalItemSesi => _riwayatSesi.fold(0, (sum, t) => sum + t.qty);
  
  // Jika di model TransaksiMasuk belum ada getter totalModal, 
  // kita hitung manual (qty * hargaAstraSatuan) agar dijamin aman tanpa error
  int get totalModalSesi => _riwayatSesi.fold(0, (sum, t) => sum + (t.qty * t.hargaAstraSatuan));

  // ─────────────────────────────────────────────
  // INIT: Muat cache + riwayat hari ini
  // ─────────────────────────────────────────────
  Future<void> init(MasterProvider mp) async {
    masterProvider = mp;
    await _muatCache();
    await _muatRiwayatHariIni();
  }

  Future<void> _muatCache() async {
    final semuaBarang = await _masterRepo.getAllBarang(limit: 99999);
    _cacheBarang = {for (final b in semuaBarang) b.kodeScan: b};
    _cacheLoaded = true;
    notifyListeners();
  }

  Future<void> _muatRiwayatHariIni() async {
    _riwayatSesi = await _repo.getRiwayatHariIni();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // PROSES SCAN: Cari di cache RAM cepat & anti-lag
  // ─────────────────────────────────────────────
  void prosesScan(String kodeScan) {
    final kode = kodeScan.trim().toUpperCase();
    if (kode.isEmpty) return;

    // ==========================================================
    // KUNCI PERBAIKAN: Rekam kode ke memori sebelum pengecekan
    // ==========================================================
    _lastScannedKode = kode; 

    final barang = _cacheBarang[kode];

    if (barang == null) {
      _status = ScanStatus.notFound;
      _barangDitemukan = null;
      _errorPesan = 'Kode "$kode" tidak terdaftar di master barang.';
    } else {
      _status = ScanStatus.found;
      _barangDitemukan = barang;
      _errorPesan = '';
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // SIMPAN: Catat transaksi + update stok otomatis
  // ─────────────────────────────────────────────
  Future<bool> simpanTransaksi(int qty) async {
    if (_barangDitemukan == null || qty <= 0) return false;

    _status = ScanStatus.saving;
    notifyListeners();

    final now = DateTime.now();
    final transaksi = TransaksiMasuk(
      kodeScan: _barangDitemukan!.kodeScan,
      qty: qty,
      hargaAstraSatuan: _barangDitemukan!.hargaAstra,
      tanggal: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      jam: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      namaBarang: _barangDitemukan!.namaBarang,
      kategori: _barangDitemukan!.kategori,
    );

    final berhasil = await _repo.simpan(transaksi);

    if (berhasil) {
      _status = ScanStatus.saved;

      // Update cache RAM secara lokal (stok langsung bertambah instant)
      final barangLama = _cacheBarang[_barangDitemukan!.kodeScan]!;
      _cacheBarang[_barangDitemukan!.kodeScan] = barangLama.copyWith(
        stokSisa: barangLama.stokSisa + qty,
      );

      await _muatRiwayatHariIni();
      masterProvider?.loadData(); // Trigger refresh tabel utama Master Barang
      reset();
    } else {
      _status = ScanStatus.error;
      _errorPesan = 'Gagal menyimpan. Coba lagi.';
    }

    notifyListeners();
    return berhasil;
  }

  // ─────────────────────────────────────────────
  // HAPUS RIWAYAT: Pembatalan transaksi (Rollback stok)
  // ─────────────────────────────────────────────
  Future<bool> hapusRiwayat(TransaksiMasuk t) async {
    if (t.id == null) return false;

    final berhasil = await _repo.hapus(t.id!, t.kodeScan, t.qty);

    if (berhasil) {
      // Kurangi stok kembali di cache RAM secara lokal
      final barang = _cacheBarang[t.kodeScan];
      if (barang != null) {
        _cacheBarang[t.kodeScan] = barang.copyWith(
          stokSisa: barang.stokSisa - t.qty,
        );
      }
      await _muatRiwayatHariIni();
      masterProvider?.loadData();
    }

    notifyListeners();
    return berhasil;
  }

  // ─────────────────────────────────────────────
  // RESET: Bersihkan state scan untuk barang berikutnya
  // ─────────────────────────────────────────────
  void reset() {
    _status = ScanStatus.idle;
    _barangDitemukan = null;
    _errorPesan = '';
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Tambah barang baru ke cache RAM setelah didaftarkan
  // ─────────────────────────────────────────────
  void tambahKeCache(Barang barang) {
    _cacheBarang[barang.kodeScan] = barang;
    notifyListeners();
  }
}