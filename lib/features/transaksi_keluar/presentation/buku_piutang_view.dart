// File: lib/features/transaksi_keluar/presentation/buku_piutang_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/transaksi_keluar_header_model.dart';
import 'controller/piutang_provider.dart';
import 'widgets/dialog_detail_nota.dart';

// ─────────────────────────────────────────────────────────────────
// BUKU PIUTANG VIEW
//
// Layar untuk list semua hutang aktif:
//   - Filter: semua / < 7 hari / 7-30 hari / > 30 hari
//   - Search: nama pelanggan atau no_nota
//   - Klik baris → buka detail nota
// ─────────────────────────────────────────────────────────────────

class BukuPiutangView extends StatefulWidget {
  const BukuPiutangView({super.key});

  @override
  State<BukuPiutangView> createState() => _BukuPiutangViewState();
}

class _BukuPiutangViewState extends State<BukuPiutangView> {
  final _searchCtrl = TextEditingController();

  static const Color _ungu     = Color(0xFF6A1B9A);
  static const Color _unguMuda = Color(0xFFF3E5F5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PiutangProvider>().init();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _rp(int n) {
    if (n == 0) return 'Rp 0';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> _bukaDetail(String noNota) async {
    await DialogDetailNota.show(context, noNota);
    // Setelah dialog tutup, list otomatis ter-refresh via PiutangProvider
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildFilterRow(),
        const SizedBox(height: 12),
        Expanded(child: _buildListHutang()),
      ]),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Wrap(
      spacing: 14, runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _unguMuda, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.book_rounded, color: _ungu, size: 22),
        ),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Buku Piutang', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          Text('Daftar hutang pelanggan yang belum lunas',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        Consumer<PiutangProvider>(
          builder: (_, PiutangProvider p, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.totalPiutangSistem > 0 ? Colors.red.shade50 : _unguMuda,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: p.totalPiutangSistem > 0 ? Colors.red.shade200 : _ungu.withValues(alpha: 0.2),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('TOTAL PIUTANG LUAR',
                  style: TextStyle(
                      fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              Text(_rp(p.totalPiutangSistem),
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: p.totalPiutangSistem > 0 ? Colors.red.shade800 : _ungu)),
            ]),
          ),
        ),
      ],
    );
  }

  // ── FILTER & SEARCH ──────────────────────────────────────────
  Widget _buildFilterRow() {
    return Consumer<PiutangProvider>(
      builder: (_, PiutangProvider p, _) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Search
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => p.setSearchKeyword(v),
            decoration: InputDecoration(
              hintText: 'Cari nama pelanggan atau no nota...',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _ungu),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () { _searchCtrl.clear(); p.setSearchKeyword(''); },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _ungu, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // Filter chips
          Wrap(spacing: 6, runSpacing: 6, children: [
            _filterChip('Semua',     FilterUmur.semua,    p.filter, () => p.setFilter(FilterUmur.semua)),
            _filterChip('< 7 hari',  FilterUmur.kurang7,  p.filter, () => p.setFilter(FilterUmur.kurang7)),
            _filterChip('7-30 hari', FilterUmur.kurang30, p.filter, () => p.setFilter(FilterUmur.kurang30)),
            _filterChip('> 30 hari ⚠', FilterUmur.lebih30,  p.filter, () => p.setFilter(FilterUmur.lebih30)),
            const SizedBox(width: 12),
            if (p.jumlahHutangAktif > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _unguMuda,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${p.jumlahHutangAktif} nota • ${_rp(p.totalPiutangTerfilter)}',
                  style: const TextStyle(fontSize: 11, color: _ungu, fontWeight: FontWeight.w600),
                ),
              ),
          ]),
        ]);
      },
    );
  }

  Widget _filterChip(String label, FilterUmur f, FilterUmur active, VoidCallback onTap) {
    final bool aktif = f == active;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: aktif ? _ungu : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: aktif ? _ungu : Colors.grey.shade300,
            width: aktif ? 0 : 0.8,
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11.5,
          fontWeight: aktif ? FontWeight.w600 : FontWeight.normal,
          color: aktif ? Colors.white : Colors.grey.shade700,
        )),
      ),
    );
  }

  // ── LIST ─────────────────────────────────────────────────────
  Widget _buildListHutang() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Consumer<PiutangProvider>(
        builder: (_, PiutangProvider p, _) {
          if (p.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (p.errorPesan.isNotEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline_rounded, color: Colors.red.shade300, size: 48),
              const SizedBox(height: 10),
              Text(p.errorPesan,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              const SizedBox(height: 10),
              FilledButton(onPressed: p.refresh, child: const Text('Coba Lagi')),
            ]));
          }
          final list = p.hutangAktifTerfilter;
          if (list.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 56, color: Colors.green.shade200),
                const SizedBox(height: 10),
                Text(
                  p.hutangAktif.isEmpty ? 'Tidak Ada Hutang Aktif' : 'Tidak Ada Hasil',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  p.hutangAktif.isEmpty
                      ? 'Semua transaksi sudah lunas. Mantap! 🎉'
                      : 'Coba ubah filter atau search keyword',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ]),
            ));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: list.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (_, int i) => _baris(list[i], p),
          );
        },
      ),
    );
  }

  Widget _baris(TransaksiKeluarHeader h, PiutangProvider p) {
    final Color warnaUmur = p.warnaUmur(h);
    final String labelUmur = p.labelUmur(h);

    return InkWell(
      onTap: () => _bukaDetail(h.noNota),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          // Indikator warna umur
          Container(
            width: 4, height: 44,
            decoration: BoxDecoration(
              color: warnaUmur,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),

          // Info pelanggan + nota
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(
                h.namaPelangganSnapshot ?? '(Tanpa Nama)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              )),
              if (h.noHpSnapshot != null && h.noHpSnapshot!.isNotEmpty)
                Text(h.noHpSnapshot!,
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey, fontFamily: 'monospace')),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Text(h.noNota,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
              const Text(' • ', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text(labelUmur,
                  style: TextStyle(fontSize: 10.5, color: warnaUmur, fontWeight: FontWeight.w600)),
            ]),
          ])),

          const SizedBox(width: 8),

          // Sisa hutang
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_rp(h.sisaHutang),
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold,
                  color: warnaUmur,
                )),
            Text('dari ${_rp(h.totalTagihan)}',
                style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
          ]),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
        ]),
      ),
    );
  }
}
