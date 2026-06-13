// File: lib/features/laporan/presentation/controller/laporan_provider.dart

import 'package:flutter/material.dart';
import '../../data/laporan_repository.dart';

// ─────────────────────────────────────────────────────────────────
// LAPORAN PROVIDER
//
// Mengelola state laporan:
//   - Periode aktif (harian / bulanan / custom)
//   - Data ringkasan, top barang, omzet harian, per kategori
//   - Loading & error state
//
// Mode periode:
//   - hariIni    : tanggal hari ini saja
//   - bulanIni   : awal bulan s/d hari ini
//   - custom     : user pilih dari-sampai
// ─────────────────────────────────────────────────────────────────

enum PeriodeMode { hariIni, bulanIni, custom }

class LaporanProvider extends ChangeNotifier {
  final _repo = LaporanRepository();

  // ── State periode ────────────────────────────────────────────
  PeriodeMode _mode = PeriodeMode.hariIni;
  DateTime _dari = DateTime.now();
  DateTime _sampai = DateTime.now();

  // ── State data ───────────────────────────────────────────────
  Map<String, int> _ringkasan = {};
  List<Map<String, dynamic>> _topBarang = [];
  List<Map<String, dynamic>> _omzetHarian = [];
  List<Map<String, dynamic>> _perKategori = [];
  Map<String, int> _modalTidakBerputar = {};
  int _totalPiutang = 0;

  bool _isLoading = false;
  String _errorPesan = '';

  // ── Getters ──────────────────────────────────────────────────
  PeriodeMode get mode    => _mode;
  DateTime    get dari    => _dari;
  DateTime    get sampai  => _sampai;
  bool        get isLoading => _isLoading;
  String      get errorPesan => _errorPesan;

  Map<String, int>           get ringkasan   => _ringkasan;
  List<Map<String, dynamic>> get topBarang   => _topBarang;
  List<Map<String, dynamic>> get omzetHarian => _omzetHarian;
  List<Map<String, dynamic>> get perKategori => _perKategori;
  Map<String, int>           get modalTidakBerputar => _modalTidakBerputar;
  int                        get totalPiutang => _totalPiutang;

  // Helper: ringkasan values dengan default 0
  int get omzet           => _ringkasan['omzet'] ?? 0;
  int get totalLaba       => _ringkasan['totalLaba'] ?? 0;
  int get totalModal      => _ringkasan['totalModal'] ?? 0;
  int get totalDibayar    => _ringkasan['totalDibayar'] ?? 0;
  int get totalHutangBaru => _ringkasan['totalHutangBaru'] ?? 0;
  int get jumlahNota      => _ringkasan['jumlahNota'] ?? 0;
  int get jumlahItem      => _ringkasan['jumlahItem'] ?? 0;
  int get rataRataPerNota => _ringkasan['rataRataPerNota'] ?? 0;

  String get labelPeriode {
    switch (_mode) {
      case PeriodeMode.hariIni:  return 'Hari Ini (${_fmtTampil(_dari)})';
      case PeriodeMode.bulanIni: return 'Bulan Ini';
      case PeriodeMode.custom:   return '${_fmtTampil(_dari)} s/d ${_fmtTampil(_sampai)}';
    }
  }

  String get dariStr   => _fmtDB(_dari);
  String get sampaiStr => _fmtDB(_sampai);

  // ── INIT ─────────────────────────────────────────────────────
  Future<void> init() async {
    setPeriodeHariIni();
  }

  // ── SET PERIODE ──────────────────────────────────────────────
  Future<void> setPeriodeHariIni() async {
    _mode = PeriodeMode.hariIni;
    final now = DateTime.now();
    _dari = DateTime(now.year, now.month, now.day);
    _sampai = _dari;
    await _muatData();
  }

  Future<void> setPeriodeBulanIni() async {
    _mode = PeriodeMode.bulanIni;
    final now = DateTime.now();
    _dari = DateTime(now.year, now.month, 1);
    _sampai = DateTime(now.year, now.month, now.day);
    await _muatData();
  }

  Future<void> setPeriodeCustom(DateTime dari, DateTime sampai) async {
    _mode = PeriodeMode.custom;
    _dari = dari;
    _sampai = sampai;
    await _muatData();
  }

  Future<void> refresh() async {
    await _muatData();
  }

  // ── MUAT DATA ────────────────────────────────────────────────
  Future<void> _muatData() async {
    _isLoading = true;
    _errorPesan = '';
    notifyListeners();

    try {
      final dari = _fmtDB(_dari);
      final sampai = _fmtDB(_sampai);

      // Jalankan paralel untuk kecepatan
      final results = await Future.wait([
        _repo.ringkasanPeriode(dari: dari, sampai: sampai),
        _repo.topBarangTerlaris(dari: dari, sampai: sampai, limit: 10),
        _repo.omzetHarian(dari: dari, sampai: sampai),
        _repo.ringkasanPerKategori(dari: dari, sampai: sampai),
        _repo.modalTidakBerputar(dari: dari, sampai: sampai),
        _repo.totalPiutangAktif(),
      ]);

      _ringkasan          = results[0] as Map<String, int>;
      _topBarang          = results[1] as List<Map<String, dynamic>>;
      _omzetHarian        = results[2] as List<Map<String, dynamic>>;
      _perKategori        = results[3] as List<Map<String, dynamic>>;
      _modalTidakBerputar = results[4] as Map<String, int>;
      _totalPiutang       = results[5] as int;
    } catch (e) {
      _errorPesan = 'Gagal memuat laporan: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── FORMAT HELPER ────────────────────────────────────────────
  String _fmtDB(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  String _fmtTampil(DateTime d) {
    const bulan = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
                   'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${bulan[d.month]} ${d.year}';
  }
}
