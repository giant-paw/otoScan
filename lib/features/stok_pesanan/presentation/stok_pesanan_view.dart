// File: lib/features/stok_pesanan/presentation/stok_pesanan_view.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/stok_pesanan_repository.dart';
import '../data/pesanan_export_service.dart';
import 'controller/stok_pesanan_provider.dart';

// ─────────────────────────────────────────────────────────────────
// STOK & PESANAN VIEW — 2 TAB
//
//   Tab 1: STOK BARANG   — filter Semua/Habis/Menipis/Banyak
//   Tab 2: SARAN PESANAN — barang perlu dipesan + export Excel
// ─────────────────────────────────────────────────────────────────

// Wrapper: menyediakan StokPesananProvider sendiri, jadi tidak perlu
// didaftarkan di main.dart. Aman walau provider global belum ada.
class StokPesananView extends StatelessWidget {
  const StokPesananView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StokPesananProvider(),
      child: const _StokPesananContent(),
    );
  }
}

class _StokPesananContent extends StatefulWidget {
  const _StokPesananContent();

  @override
  State<_StokPesananContent> createState() => _StokPesananViewState();
}

class _StokPesananViewState extends State<_StokPesananContent>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _exportService = PesananExportService();
  bool _isExporting = false;

  static const Color _biru     = Color(0xFF0277BD);
  static const Color _hijauTua = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StokPesananProvider>().init();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _rp(int n) {
    if (n == 0) return 'Rp 0';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> _exportPesanan() async {
    final p = context.read<StokPesananProvider>();
    if (p.pesananTotalItem == 0) {
      _snack('Tidak ada barang yang perlu dipesan', error: true);
      return;
    }
    setState(() => _isExporting = true);
    try {
      final path = await _exportService.exportPesanan();
      if (!mounted) return;
      setState(() => _isExporting = false);
      _dialogSukses(path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      _snack('Gagal export: $e', error: true);
    }
  }

  void _dialogSukses(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Icon(Icons.check_circle_rounded, color: _hijauTua, size: 22),
          const SizedBox(width: 8),
          const Text('Export Berhasil', style: TextStyle(fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Daftar pesanan tersimpan:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: SelectableText(path, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton.icon(
            onPressed: () async { Navigator.pop(ctx); await _bukaFolder(path); },
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
    } catch (_) {}
  }

  void _snack(String pesan, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(pesan),
      backgroundColor: error ? Colors.red.shade600 : _hijauTua,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _biru.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(color: _biru, borderRadius: BorderRadius.circular(10)),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: _biru,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [Tab(text: 'Stok Barang'), Tab(text: 'Saran Pesanan')],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: TabBarView(
          controller: _tab,
          children: [_buildTabStok(), _buildTabPesanan()],
        )),
      ]),
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _biru.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.inventory_2_rounded, color: _biru, size: 22),
      ),
      const SizedBox(width: 14),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('Stok & Pesanan', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        Text('Pantau stok & barang yang perlu dipesan',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    ]);
  }

  // ══ TAB 1: STOK ══
  Widget _buildTabStok() {
    return Consumer<StokPesananProvider>(
      builder: (_, StokPesananProvider p, _) {
        return Column(children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            _filterChip('Semua', p.semua, FilterStok.semua, p.filter, Colors.grey.shade700,
                () => p.setFilter(FilterStok.semua)),
            _filterChip('Habis', p.habis, FilterStok.habis, p.filter, Colors.red.shade700,
                () => p.setFilter(FilterStok.habis)),
            _filterChip('Menipis', p.menipis, FilterStok.menipis, p.filter, Colors.orange.shade700,
                () => p.setFilter(FilterStok.menipis)),
            _filterChip('Banyak', p.banyak, FilterStok.banyak, p.filter, _hijauTua,
                () => p.setFilter(FilterStok.banyak)),
          ]),
          const SizedBox(height: 12),
          Expanded(child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: p.isLoading
                ? const Center(child: CircularProgressIndicator())
                : p.daftarStok.isEmpty
                    ? _empty('Tidak ada barang di filter ini')
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: p.daftarStok.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (_, i) => _barisStok(p.daftarStok[i]),
                      ),
          )),
        ]);
      },
    );
  }

  Widget _filterChip(String label, int jumlah, FilterStok f, FilterStok aktif, Color warna, VoidCallback onTap) {
    final isAktif = f == aktif;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isAktif ? warna : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isAktif ? warna : Colors.grey.shade300, width: isAktif ? 0 : 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: isAktif ? FontWeight.w600 : FontWeight.normal,
            color: isAktif ? Colors.white : Colors.grey.shade700)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: isAktif ? Colors.white.withValues(alpha: 0.25) : warna.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$jumlah', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold,
              color: isAktif ? Colors.white : warna)),
          ),
        ]),
      ),
    );
  }

  Widget _barisStok(Map<String, dynamic> b) {
    final stok = b['stokSisa'] as int;
    final Color warna = stok == 0 ? Colors.red.shade700
        : stok <= 5 ? Colors.orange.shade700 : _hijauTua;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b['namaBarang'] as String,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${b['kodeScan']} • ${b['kategori']}',
              style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
        ])),
        const SizedBox(width: 8),
        Text(_rp(b['hargaJual'] as int),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: warna.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: warna.withValues(alpha: 0.3)),
          ),
          child: Text(
            stok == 0 ? 'HABIS' : '$stok pcs',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: warna),
          ),
        ),
      ]),
    );
  }

  // ══ TAB 2: SARAN PESANAN ══
  Widget _buildTabPesanan() {
    return Consumer<StokPesananProvider>(
      builder: (_, StokPesananProvider p, _) {
        return Column(children: [
          // Ringkasan + tombol export
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _hijauTua.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _hijauTua.withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p.pesananTotalItem} jenis barang perlu dipesan',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text('Total ${p.pesananTotalQty} pcs • Estimasi ${_rp(p.pesananTotalBiaya)}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              ])),
              FilledButton.icon(
                onPressed: (_isExporting || p.pesananTotalItem == 0) ? null : _exportPesanan,
                icon: _isExporting
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.file_download_rounded, size: 18),
                label: Text(_isExporting ? 'Membuat...' : 'Export Excel'),
                style: FilledButton.styleFrom(
                  backgroundColor: _hijauTua,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: p.isLoading
                ? const Center(child: CircularProgressIndicator())
                : p.saranPesanan.isEmpty
                    ? _empty('Semua stok aman — tidak ada yang perlu dipesan 🎉')
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: p.saranPesanan.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (_, i) => _barisPesanan(p.saranPesanan[i]),
                      ),
          )),
        ]);
      },
    );
  }

  Widget _barisPesanan(Map<String, dynamic> b) {
    final prioritas = b['prioritas'] as String;
    final Color warnaP = prioritas == 'TINGGI' ? Colors.red.shade700
        : prioritas == 'SEDANG' ? Colors.orange.shade700 : _hijauTua;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        // Prioritas badge
        Container(
          width: 6, height: 44,
          decoration: BoxDecoration(color: warnaP, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b['namaBarang'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            Text('Stok: ', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
            Text('${b['stokSisa']}',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: warnaP)),
            Text('  •  Terjual 30hr: ${b['terjual30']} pcs',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
          ]),
        ])),
        const SizedBox(width: 8),
        // Saran qty
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2CC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Text('Pesan ${b['saranQty']} pcs',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
          ),
          const SizedBox(height: 2),
          Text('≈ ${_rp(b['estimasiBiaya'] as int)}',
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
        ]),
      ]),
    );
  }

  Widget _empty(String pesan) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline_rounded, size: 52, color: Colors.green.shade200),
        const SizedBox(height: 10),
        Text(pesan, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ]),
    ));
  }
}