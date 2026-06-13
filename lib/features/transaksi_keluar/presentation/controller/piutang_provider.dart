// File: lib/features/transaksi_keluar/presentation/controller/piutang_provider.dart

import 'package:flutter/material.dart';
import '../../data/transaksi_keluar_header_model.dart';
import '../../data/transaksi_keluar_repository.dart';
import '../../data/piutang_repository.dart';
import '../../data/pembayaran_hutang_model.dart';
import '../../../pelanggan/presentation/controller/pelanggan_provider.dart';
import '../../../master_barang/presentation/controller/master_provider.dart';

// ─────────────────────────────────────────────────────────────────
// PIUTANG PROVIDER — state buku piutang & catat cicilan
//
// Bertanggung jawab:
//   - List hutang aktif dengan filter umur (< 7 hari, < 30 hari, > 30 hari)
//   - Detail nota + history pembayaran
//   - Catat pembayaran cicilan
//   - Batalkan pembayaran (koreksi admin)
//   - Total piutang sistem (untuk dashboard)
// ─────────────────────────────────────────────────────────────────

enum FilterUmur { semua, kurang7, kurang30, lebih30 }

class PiutangProvider extends ChangeNotifier {
  final _piutangRepo  = PiutangRepository();
  final _transaksiRepo = TransaksiKeluarRepository();

  // ── State list hutang aktif ──────────────────────────────────
  List<TransaksiKeluarHeader> _hutangAktif = [];
  bool _isLoading = false;
  String _errorPesan = '';
  FilterUmur _filter = FilterUmur.semua;
  String _searchKeyword = '';
  int _totalPiutangSistem = 0;

  // ── State detail nota (saat user buka detail) ────────────────
  TransaksiKeluarHeader?     _notaTerpilih;
  List<PembayaranHutang>     _historyPembayaran = [];
  bool _isLoadingDetail = false;

  // ── State catat pembayaran ───────────────────────────────────
  bool _isProcessingBayar = false;

  // ── Getters ──────────────────────────────────────────────────
  List<TransaksiKeluarHeader> get hutangAktif => _hutangAktif;
  bool                        get isLoading   => _isLoading;
  String                      get errorPesan  => _errorPesan;
  FilterUmur                  get filter      => _filter;
  String                      get searchKeyword => _searchKeyword;
  int                         get totalPiutangSistem => _totalPiutangSistem;
  int                         get jumlahHutangAktif => hutangAktifTerfilter.length;

  TransaksiKeluarHeader? get notaTerpilih => _notaTerpilih;
  List<PembayaranHutang> get historyPembayaran => _historyPembayaran;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isProcessingBayar => _isProcessingBayar;

  // List hutang yang sudah difilter (umur + search)
  List<TransaksiKeluarHeader> get hutangAktifTerfilter {
    var hasil = _hutangAktif;

    // Filter umur
    if (_filter != FilterUmur.semua) {
      final now = DateTime.now();
      hasil = hasil.where((h) {
        final umur = _hitungUmurHari(h.tanggal, now);
        switch (_filter) {
          case FilterUmur.kurang7:  return umur < 7;
          case FilterUmur.kurang30: return umur >= 7 && umur < 30;
          case FilterUmur.lebih30:  return umur >= 30;
          case FilterUmur.semua:    return true;
        }
      }).toList();
    }

    // Search (nama pelanggan / no_nota)
    if (_searchKeyword.trim().isNotEmpty) {
      final kw = _searchKeyword.toLowerCase();
      hasil = hasil.where((h) {
        final nama = (h.namaPelangganSnapshot ?? '').toLowerCase();
        final nota = h.noNota.toLowerCase();
        return nama.contains(kw) || nota.contains(kw);
      }).toList();
    }

    return hasil;
  }

  int get totalPiutangTerfilter =>
    hutangAktifTerfilter.fold(0, (s, h) => s + h.sisaHutang);

  // ─────────────────────────────────────────────────────────────
  // INIT / REFRESH list hutang aktif
  // ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorPesan = '';
    notifyListeners();

    try {
      _hutangAktif = await _piutangRepo.listHutangAktif();
      _totalPiutangSistem = await _piutangRepo.totalPiutangAktif();
    } catch (e) {
      _errorPesan = 'Gagal memuat data piutang: $e';
      _hutangAktif = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // FILTER & SEARCH
  // ─────────────────────────────────────────────────────────────
  void setFilter(FilterUmur f) {
    _filter = f;
    notifyListeners();
  }

  void setSearchKeyword(String kw) {
    _searchKeyword = kw;
    notifyListeners();
  }

  void clearFilter() {
    _filter = FilterUmur.semua;
    _searchKeyword = '';
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // BUKA DETAIL NOTA — load header + history pembayaran
  // ─────────────────────────────────────────────────────────────
  Future<void> bukaDetail(String noNota) async {
    _isLoadingDetail = true;
    _errorPesan = '';
    notifyListeners();

    try {
      final detail = await _transaksiRepo.detailNota(noNota);
      if (detail == null) {
        _errorPesan = 'Nota tidak ditemukan';
        _notaTerpilih = null;
        _historyPembayaran = [];
      } else {
        _notaTerpilih = detail['header'] as TransaksiKeluarHeader;
        _historyPembayaran = detail['pembayarans'] as List<PembayaranHutang>;
      }
    } catch (e) {
      _errorPesan = 'Gagal memuat detail: $e';
    }

    _isLoadingDetail = false;
    notifyListeners();
  }

  void tutupDetail() {
    _notaTerpilih = null;
    _historyPembayaran = [];
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // ★ CATAT PEMBAYARAN CICILAN ★
  //
  // Return: null jika sukses, error string jika gagal.
  // Setelah sukses, refresh list & pelanggan.
  // ─────────────────────────────────────────────────────────────
  Future<String?> catatPembayaran({
    required String noNota,
    required int jumlah,
    String metode = 'TUNAI',
    String? catatan,
    required PelangganProvider pelangganProvider,
  }) async {
    _isProcessingBayar = true;
    _errorPesan = '';
    notifyListeners();

    final err = await _piutangRepo.catatPembayaran(
      noNota: noNota,
      jumlah: jumlah,
      metode: metode,
      catatan: catatan,
    );

    if (err == null) {
      // Reload detail nota (untuk update sisa hutang & history)
      await bukaDetail(noNota);
      // Refresh list hutang aktif
      await refresh();
      // Refresh pelanggan (total_hutang_aktif berubah)
      await pelangganProvider.refresh();
    } else {
      _errorPesan = err;
    }

    _isProcessingBayar = false;
    notifyListeners();
    return err;
  }

  // ─────────────────────────────────────────────────────────────
  // BATALKAN PEMBAYARAN (koreksi admin)
  // ─────────────────────────────────────────────────────────────
  Future<String?> batalkanPembayaran({
    required int idPembayaran,
    required String noNota,
    required PelangganProvider pelangganProvider,
  }) async {
    final err = await _piutangRepo.batalkanPembayaran(idPembayaran);

    if (err == null) {
      await bukaDetail(noNota);
      await refresh();
      await pelangganProvider.refresh();
    } else {
      _errorPesan = err;
      notifyListeners();
    }

    return err;
  }

  // ─────────────────────────────────────────────────────────────
  // HELPER: hitung umur hari hutang
  // ─────────────────────────────────────────────────────────────
  int umurHari(TransaksiKeluarHeader h) {
    return _hitungUmurHari(h.tanggal, DateTime.now());
  }

  int _hitungUmurHari(String tanggalStr, DateTime now) {
    try {
      final parts = tanggalStr.split('-');
      final tgl = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return now.difference(tgl).inDays;
    } catch (_) {
      return 0;
    }
  }

  // Indikator warna berdasarkan umur
  Color warnaUmur(TransaksiKeluarHeader h) {
    final umur = umurHari(h);
    if (umur >= 30) return Colors.red.shade700;
    if (umur >= 14) return Colors.orange.shade700;
    if (umur >= 7)  return Colors.amber.shade700;
    return Colors.green.shade700;
  }

  String labelUmur(TransaksiKeluarHeader h) {
    final umur = umurHari(h);
    if (umur == 0)  return 'Hari ini';
    if (umur == 1)  return 'Kemarin';
    if (umur < 7)   return '$umur hari lalu';
    if (umur < 30)  return '$umur hari lalu';
    if (umur < 365) return '${(umur / 30).floor()} bulan lalu';
    return '${(umur / 365).floor()} tahun lalu';
  }

  void clearError() {
    _errorPesan = '';
    notifyListeners();
  }
}
