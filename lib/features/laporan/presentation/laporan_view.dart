// File: lib/features/laporan/presentation/laporan_view.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controller/laporan_provider.dart';
import '../data/laporan_export_service.dart';

// ─────────────────────────────────────────────────────────────────
// LAPORAN VIEW — dashboard laporan untuk owner
//
// Bagian:
//   1. Filter periode (Hari Ini / Bulan Ini / Custom)
//   2. KPI cards (Omzet, Laba, Nota, Piutang)
//   3. Grafik omzet harian (bar)
//   4. Top barang terlaris (bar horizontal + tabel)
//   5. Breakdown per kategori
//   6. Tombol Export Excel
// ─────────────────────────────────────────────────────────────────

class LaporanView extends StatefulWidget {
  const LaporanView({super.key});

  @override
  State<LaporanView> createState() => _LaporanViewState();
}

class _LaporanViewState extends State<LaporanView> {
  final _exportService = LaporanExportService();
  bool _isExporting = false;

  static const Color _ungu     = Color(0xFF6A1B9A);
  static const Color _hijauTua = Color(0xFF1B5E20);
  static const Color _biru     = Color(0xFF0277BD);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LaporanProvider>().init();
    });
  }

  String _rp(int n) {
    if (n == 0) return 'Rp 0';
    final neg = n < 0;
    final abs = n.abs();
    final s = 'Rp ${abs.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
    return neg ? '-$s' : s;
  }

  String _rpSingkat(int n) {
    if (n >= 1000000000) return 'Rp ${(n / 1000000000).toStringAsFixed(1)}M';
    if (n >= 1000000) return 'Rp ${(n / 1000000).toStringAsFixed(1)}jt';
    if (n >= 1000) return 'Rp ${(n / 1000).toStringAsFixed(0)}rb';
    return 'Rp $n';
  }

  // ── EXPORT ───────────────────────────────────────────────────
  Future<void> _export() async {
    final laporan = context.read<LaporanProvider>();
    if (laporan.jumlahNota == 0) {
      _showSnack('Tidak ada data transaksi di periode ini', isError: true);
      return;
    }

    setState(() => _isExporting = true);
    try {
      final path = await _exportService.exportLaporan(
        dari: laporan.dariStr,
        sampai: laporan.sampaiStr,
        labelPeriode: laporan.labelPeriode,
      );
      if (!mounted) return;
      setState(() => _isExporting = false);
      _showDialogSukses(path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      _showSnack('Gagal export: $e', isError: true);
    }
  }

  void _showDialogSukses(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Icon(Icons.check_circle_rounded, color: _hijauTua, size: 24),
          const SizedBox(width: 8),
          const Text('Export Berhasil', style: TextStyle(fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('File Excel laporan tersimpan di:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(path,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Buka folder OtoScan_Laporan untuk lihat semua file laporan.',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
              )),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _bukaFolder(path);
            },
            icon: const Icon(Icons.folder_open_rounded, size: 16),
            label: const Text('Buka Folder'),
            style: FilledButton.styleFrom(backgroundColor: _hijauTua),
          ),
        ],
      ),
    );
  }

  Future<void> _bukaFolder(String filePath) async {
    try {
      final dir = File(filePath).parent.path;
      if (Platform.isWindows) {
        await Process.run('explorer', [dir]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [dir]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dir]);
      }
    } catch (e) {
      if (mounted) _showSnack('Tidak bisa buka folder otomatis. Path sudah disalin.', isError: false);
    }
  }

  void _showSnack(String pesan, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(pesan),
      backgroundColor: isError ? Colors.red.shade600 : _hijauTua,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _pilihCustomRange() async {
    final laporan = context.read<LaporanProvider>();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: laporan.dari, end: laporan.sampai),
    );
    if (range != null) {
      await laporan.setPeriodeCustom(range.start, range.end);
    }
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildFilterPeriode(),
        const SizedBox(height: 12),
        Expanded(
          child: Consumer<LaporanProvider>(
            builder: (_, LaporanProvider p, _) {
              if (p.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (p.errorPesan.isNotEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
                  const SizedBox(height: 10),
                  Text(p.errorPesan, style: TextStyle(color: Colors.red.shade700)),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: p.refresh, child: const Text('Coba Lagi')),
                ]));
              }
              return SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildKpiCards(p),
                  const SizedBox(height: 16),
                  if (p.jumlahNota == 0)
                    _buildEmptyState()
                  else ...[
                    _buildGrafikOmzet(p),
                    const SizedBox(height: 16),
                    _buildTopBarang(p),
                    const SizedBox(height: 16),
                    _buildPerKategori(p),
                  ],
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Wrap(
      spacing: 14, runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _ungu.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.insert_chart_rounded, color: _ungu, size: 22),
        ),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Laporan & Rekap', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          Text('Ringkasan penjualan, laba, dan barang terlaris',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        const Spacer(),
        Consumer<LaporanProvider>(
          builder: (_, LaporanProvider p, _) => FilledButton.icon(
            onPressed: _isExporting ? null : _export,
            icon: _isExporting
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download_rounded, size: 18),
            label: Text(_isExporting ? 'Membuat...' : 'Export Excel'),
            style: FilledButton.styleFrom(
              backgroundColor: _hijauTua,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPeriode() {
    return Consumer<LaporanProvider>(
      builder: (_, LaporanProvider p, _) => Row(children: [
        _periodeBtn('Hari Ini', p.mode == PeriodeMode.hariIni, () => p.setPeriodeHariIni()),
        const SizedBox(width: 8),
        _periodeBtn('Bulan Ini', p.mode == PeriodeMode.bulanIni, () => p.setPeriodeBulanIni()),
        const SizedBox(width: 8),
        _periodeBtn('Pilih Tanggal', p.mode == PeriodeMode.custom, _pilihCustomRange),
        const SizedBox(width: 12),
        Flexible(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _ungu.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(p.labelPeriode,
              style: const TextStyle(fontSize: 12, color: _ungu, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        )),
      ]),
    );
  }

  Widget _periodeBtn(String label, bool aktif, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: aktif ? _ungu : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: aktif ? _ungu : Colors.grey.shade300, width: aktif ? 0 : 0.8),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12.5,
          fontWeight: aktif ? FontWeight.w600 : FontWeight.normal,
          color: aktif ? Colors.white : Colors.grey.shade700,
        )),
      ),
    );
  }

  // ── KPI CARDS ────────────────────────────────────────────────
  Widget _buildKpiCards(LaporanProvider p) {
    return LayoutBuilder(builder: (context, constraints) {
      final bool sempit = constraints.maxWidth < 700;
      final cards = [
        _kpiCard('Omzet', _rp(p.omzet), Icons.attach_money_rounded, _hijauTua,
            'Total penjualan'),
        _kpiCard('Laba Kotor', _rp(p.totalLaba), Icons.trending_up_rounded, _biru,
            'Untung dari penjualan'),
        _kpiCard('Jumlah Nota', '${p.jumlahNota}', Icons.receipt_long_rounded, _ungu,
            '${p.jumlahItem} item terjual'),
        _kpiCard('Piutang Aktif', _rp(p.totalPiutang),
            Icons.account_balance_wallet_rounded, Colors.orange.shade800,
            'Uang di luar'),
      ];

      if (sempit) {
        return Column(children: [
          Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: cards[2]), const SizedBox(width: 10), Expanded(child: cards[3])]),
        ]);
      }
      return Row(children: [
        Expanded(child: cards[0]), const SizedBox(width: 12),
        Expanded(child: cards[1]), const SizedBox(width: 12),
        Expanded(child: cards[2]), const SizedBox(width: 12),
        Expanded(child: cards[3]),
      ]);
    });
  }

  Widget _kpiCard(String label, String value, IconData icon, Color warna, String sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(
          color: warna.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: warna.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: warna, size: 18),
          ),
          const Spacer(),
        ]),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(
            fontSize: 19, fontWeight: FontWeight.bold, color: warna)),
        ),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        Icon(Icons.bar_chart_rounded, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Belum Ada Transaksi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text('Tidak ada penjualan di periode ini.\nCoba pilih periode lain.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );
  }

  // ── GRAFIK OMZET HARIAN (bar manual) ─────────────────────────
  Widget _buildGrafikOmzet(LaporanProvider p) {
    if (p.omzetHarian.isEmpty) return const SizedBox.shrink();

    final maxOmzet = p.omzetHarian
        .map((e) => e['omzet'] as int)
        .fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.show_chart_rounded, color: _hijauTua, size: 18),
          const SizedBox(width: 8),
          const Text('Tren Omzet Harian',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: p.omzetHarian.map((e) {
                final omzet = e['omzet'] as int;
                final tanggal = e['tanggal'] as String;
                final hari = tanggal.split('-').last;
                final tinggi = maxOmzet > 0 ? (omzet / maxOmzet * 120).clamp(4.0, 120.0) : 4.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(_rpSingkat(omzet),
                        style: const TextStyle(fontSize: 8.5, color: Colors.grey)),
                    const SizedBox(height: 3),
                    Container(
                      width: 28,
                      height: tinggi,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_hijauTua, _hijauTua.withValues(alpha: 0.6)],
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(hari, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                  ]),
                );
              }).toList(),
            ),
          ),
        ),
      ]),
    );
  }

  // ── TOP BARANG TERLARIS ──────────────────────────────────────
  Widget _buildTopBarang(LaporanProvider p) {
    if (p.topBarang.isEmpty) return const SizedBox.shrink();

    final maxQty = p.topBarang
        .map((e) => e['totalQty'] as int)
        .fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.emoji_events_rounded, color: Colors.amber.shade700, size: 18),
          const SizedBox(width: 8),
          const Text('Barang Terlaris',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          Text('Top ${p.topBarang.length}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 14),
        ...p.topBarang.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          final qty = b['totalQty'] as int;
          final lebar = maxQty > 0 ? (qty / maxQty) : 0.0;

          final List<Color> medalColors = [
            Colors.amber.shade600, Colors.grey.shade400, Colors.brown.shade400,
          ];
          final warnaRank = i < 3 ? medalColors[i] : Colors.grey.shade300;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 22, height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: warnaRank, shape: BoxShape.circle,
                ),
                child: Text('${i + 1}',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: i < 3 ? Colors.white : Colors.grey.shade700,
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(b['namaBarang'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                      overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text('$qty pcs',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _hijauTua)),
                ]),
                const SizedBox(height: 4),
                Stack(children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100, borderRadius: BorderRadius.circular(3)),
                  ),
                  FractionallySizedBox(
                    widthFactor: lebar,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_hijauTua, _hijauTua.withValues(alpha: 0.6)]),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Text('${b['kategori']}',
                      style: TextStyle(fontSize: 9.5, color: Colors.grey.shade400)),
                  const Spacer(),
                  Text('Laba: ${_rp(b['totalLaba'] as int)}',
                      style: TextStyle(fontSize: 9.5, color: _biru, fontWeight: FontWeight.w500)),
                ]),
              ])),
            ]),
          );
        }),
      ]),
    );
  }

  // ── PER KATEGORI ─────────────────────────────────────────────
  Widget _buildPerKategori(LaporanProvider p) {
    if (p.perKategori.isEmpty) return const SizedBox.shrink();

    final totalOmzet = p.perKategori.fold(0, (s, e) => s + (e['totalOmzet'] as int));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.category_rounded, color: _ungu, size: 18),
          const SizedBox(width: 8),
          const Text('Penjualan per Kategori',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 14),
        ...p.perKategori.map((e) {
          final omzet = e['totalOmzet'] as int;
          final persen = totalOmzet > 0 ? (omzet / totalOmzet * 100) : 0.0;
          final warna = _warnaKategori(e['kategori'] as String);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: warna, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(e['kategori'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const Spacer(),
                  Text('${persen.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(width: 8),
                  Text(_rp(omzet),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                Stack(children: [
                  Container(height: 6,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(3))),
                  FractionallySizedBox(
                    widthFactor: persen / 100,
                    child: Container(height: 6,
                        decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(3))),
                  ),
                ]),
                const SizedBox(height: 2),
                Text('${e['totalQty']} pcs • Laba ${_rp(e['totalLaba'] as int)}',
                    style: TextStyle(fontSize: 9.5, color: Colors.grey.shade400)),
              ])),
            ]),
          );
        }),
      ]),
    );
  }

  Color _warnaKategori(String kat) {
    switch (kat) {
      case 'BUSI':     return _hijauTua;
      case 'BRG SRLG': return Colors.brown.shade600;
      case 'OLI':      return _biru;
      case 'PART':     return const Color(0xFF880E4F);
      case 'NON AHM':  return Colors.orange.shade800;
      default:         return Colors.grey.shade600;
    }
  }
}
