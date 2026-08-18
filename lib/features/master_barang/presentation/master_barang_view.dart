import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controller/master_provider.dart';
import '../data/barang_model.dart';
import 'services/import_export_service.dart';
import 'barang_form_dialog.dart';
import 'widgets/import_export_section.dart'; // ← tombol Import/Export Excel

class MasterBarangView extends StatefulWidget {
  const MasterBarangView({super.key});

  @override
  State<MasterBarangView> createState() => _MasterBarangViewState();
}

class _MasterBarangViewState extends State<MasterBarangView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Format Rupiah ───────────────────────────
  String _formatRupiah(int angka) {
    if (angka == 0) return '-';
    return 'Rp ${angka.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  // Dialog tambah/edit sekarang pakai BarangFormDialog
  // Tambah baru  : BarangFormDialog.show(context)
  // Edit barang  : BarangFormDialog.show(context, barangEdit: barang)

  // ─── Dialog Konfirmasi Hapus ─────────────────
  Future<void> _confirmHapus(BuildContext context, Barang barang) async {
    final provider = context.read<MasterProvider>();

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
        title: const Text('Hapus Barang?'),
        content: Text(
          'Barang "${barang.namaBarang}" akan dihapus permanen.\n\nRiwayat transaksinya tetap tersimpan.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
      final error = await provider.hapusBarang(barang.kodeScan);
      if (!context.mounted) return;
      if (error != null) {
        _showSnackbar(context, error, isError: true);
      } else {
        _showSnackbar(context, 'Barang berhasil dihapus');
      }
    }
  }

  // ─── Snackbar helper ─────────────────────────
  void _showSnackbar(BuildContext context, String pesan, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Master Barang',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Daftar lengkap semua suku cadang',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
              const Spacer(),
              const ImportExportSection(),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => BarangFormDialog.show(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah Barang'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF01579B),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Search Bar ──
          Consumer<MasterProvider>(
            builder: (_, provider, __) => TextField(
              controller: _searchCtrl,
              onChanged: provider.cariBarang,
              decoration: InputDecoration(
                hintText: 'Cari nama barang atau kode scan...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          provider.cariBarang('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Filter Stok (chip) ──
          Consumer<MasterProvider>(
            builder: (_, provider, __) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterStokChip(provider, FilterStok.semua, 'Semua',
                    provider.jumlahSemua, const Color(0xFF01579B)),
                _filterStokChip(provider, FilterStok.habis, 'Habis',
                    provider.jumlahHabis, Colors.red.shade600),
                _filterStokChip(provider, FilterStok.menipis, 'Menipis (≤5)',
                    provider.jumlahMenipis, Colors.orange.shade700),
                _filterStokChip(provider, FilterStok.banyak, 'Banyak (>20)',
                    provider.jumlahBanyak, Colors.green.shade700),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Tabel ──
          Expanded(
            child: Consumer<MasterProvider>(
              builder: (_, provider, __) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage.isNotEmpty) {
                  return Center(child: Text(provider.errorMessage));
                }

                if (provider.tampilBarang.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded, size: 60, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Tidak ada barang ditemukan',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      // ── Header Tabel ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 36), // Nomor urut
                            Expanded(flex: 3, child: Text('Kode Scan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(flex: 5, child: Text('Nama Barang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(flex: 2, child: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(flex: 3, child: Text('Harga Modal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(flex: 3, child: Text('Harga Jual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(flex: 2, child: Text('Stok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                            SizedBox(width: 80), // Aksi
                          ],
                        ),
                      ),

                      // ── Isi Tabel ──
                      Expanded(
                        child: ListView.separated(
                          itemCount: provider.tampilBarang.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Colors.grey.shade100),
                          itemBuilder: (ctx, i) {
                            final barang = provider.tampilBarang[i];
                            return _buildBarangRow(context, barang, i + 1);
                          },
                        ),
                      ),

                      // ── Footer jumlah ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          border: Border(top: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Menampilkan ${provider.tampilBarang.length} barang',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Chip filter stok ────────────────────────
  Widget _filterStokChip(
    MasterProvider provider, FilterStok filter, String label, int jumlah, Color warna) {
    final aktif = provider.filterStok == filter;
    return GestureDetector(
      onTap: () => provider.setFilterStok(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: aktif ? warna : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: aktif ? warna : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: aktif ? FontWeight.w600 : FontWeight.normal,
                color: aktif ? Colors.white : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: aktif ? Colors.white.withValues(alpha: 0.25) : warna.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$jumlah',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: aktif ? Colors.white : warna,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Satu baris tabel ────────────────────────
  Widget _buildBarangRow(BuildContext context, Barang barang, int nomor) {
    final stokColor = barang.stokSisa == 0
        ? Colors.red
        : barang.stokSisa < 5
            ? Colors.orange
            : Colors.green.shade700;

    return Container(
      color: nomor.isEven ? Colors.grey.shade50 : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Nomor urut
          SizedBox(
            width: 36,
            child: Text('$nomor',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ),

          // Kode Scan
          Expanded(
            flex: 3,
            child: Text(barang.kodeScan,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),

          // Nama
          Expanded(
            flex: 5,
            child: Text(barang.namaBarang,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),

          // Kategori
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(barang.kategori,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF01579B)),
                  textAlign: TextAlign.center),
            ),
          ),

          // Harga Modal
          Expanded(
            flex: 3,
            child: Text(_formatRupiah(barang.hargaAstra),
                style: const TextStyle(fontSize: 12)),
          ),

          // Harga Jual
          Expanded(
            flex: 3,
            child: Text(_formatRupiah(barang.hargaJual),
                style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20))),
          ),

          // Stok
          Expanded(
            flex: 2,
            child: Text(
              '${barang.stokSisa}',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: stokColor, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),

          // Tombol Aksi
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit
                IconButton(
                  tooltip: 'Edit barang',
                  icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF0288D1)),
                  onPressed: () => BarangFormDialog.show(context, barangEdit: barang),
                ),
                // Hapus
                IconButton(
                  tooltip: 'Hapus barang',
                  icon: Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade400),
                  onPressed: () => _confirmHapus(context, barang),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}