import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'controller/master_provider.dart';
import '../data/barang_model.dart';
import 'services/import_export_service.dart';

class MasterBarangView extends StatefulWidget {
  const MasterBarangView({super.key});

  @override
  State<MasterBarangView> createState() => _MasterBarangViewState();
}

class _MasterBarangViewState extends State<MasterBarangView> {
  final _searchCtrl = TextEditingController();
  final _importExportService = ImportExportService();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatRupiah(int angka) {
    if (angka == 0) return '-';
    return 'Rp ${angka.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  // ─── Dialog Tambah / Edit (Sama Seperti Sebelumnya) ───
  Future<void> _showFormDialog(BuildContext context, {Barang? barangEdit}) async {
    final isEdit = barangEdit != null;
    final provider = context.read<MasterProvider>();

    final kodeCtrl = TextEditingController(text: barangEdit?.kodeScan ?? '');
    final namaCtrl = TextEditingController(text: barangEdit?.namaBarang ?? '');
    final hargaAstraCtrl = TextEditingController(text: barangEdit != null && barangEdit.hargaAstra > 0 ? barangEdit.hargaAstra.toString() : '');
    final hargaJualCtrl = TextEditingController(text: barangEdit != null && barangEdit.hargaJual > 0 ? barangEdit.hargaJual.toString() : '');
    
    final kategoriValid = ['PART', 'BUSI', 'OLI', 'BRG SLRG', 'NON AHM'];
    String kategoriDipilih = barangEdit?.kategori ?? 'PART';
    if (!kategoriValid.contains(kategoriDipilih)) kategoriDipilih = 'PART';
    
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Barang' : 'Tambah Barang Baru'),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: kodeCtrl, readOnly: isEdit,
                          decoration: InputDecoration(labelText: 'Kode Scan *', filled: isEdit, fillColor: isEdit ? Colors.grey.shade100 : null),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Kode scan tidak boleh kosong' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: namaCtrl,
                          decoration: const InputDecoration(labelText: 'Nama Barang *'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama barang tidak boleh kosong' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: kategoriDipilih,
                          decoration: const InputDecoration(labelText: 'Kategori'),
                          items: kategoriValid.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                          onChanged: (v) => setDialogState(() => kategoriDipilih = v!),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: TextFormField(controller: hargaAstraCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Harga Modal (Rp)'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(controller: hargaJualCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Harga Jual (Rp)'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final barang = Barang(
                      kodeScan: kodeCtrl.text.trim(), namaBarang: namaCtrl.text.trim(), kategori: kategoriDipilih,
                      hargaAstra: int.tryParse(hargaAstraCtrl.text) ?? 0, hargaJual: int.tryParse(hargaJualCtrl.text) ?? 0, stokSisa: barangEdit?.stokSisa ?? 0,
                    );
                    String? error = isEdit ? await provider.editBarang(barang) : await provider.tambahBarang(barang);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _showSnackbar(context, error ?? (isEdit ? 'Barang diperbarui' : 'Barang ditambahkan'), isError: error != null);
                  },
                  child: Text(isEdit ? 'Simpan' : 'Tambah'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Dialog Konfirmasi Hapus SATU / BANYAK ───
  Future<void> _confirmHapus(BuildContext context, {Barang? barang}) async {
    final provider = context.read<MasterProvider>();
    final isBulk = barang == null;
    final jumlah = isBulk ? provider.selectedItems.length : 1;

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
        title: Text(isBulk ? 'Hapus $jumlah Barang Terpilih?' : 'Hapus Barang?'),
        content: Text(
          isBulk ? 'Semua barang yang dicentang akan dihapus permanen.' : 'Barang "${barang!.namaBarang}" akan dihapus permanen.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600), onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Hapus')),
        ],
      ),
    );

    if (konfirmasi == true) {
      final error = isBulk ? await provider.hapusBarangTerpilih() : await provider.hapusBarang(barang!.kodeScan);
      if (!context.mounted) return;
      _showSnackbar(context, error ?? (isBulk ? '$jumlah barang dihapus' : 'Barang dihapus'), isError: error != null);
    }
  }

  // ─── Dialog Hasil Import Excel (BARU) ────────
  Future<void> _showImportResultDialog(BuildContext context, dynamic hasil) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF0288D1)),
              SizedBox(width: 10),
              Text('Laporan Import Excel'),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Berhasil ditambahkan: ${hasil.berhasil} barang', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                if (hasil.listDuplikat.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('⚠️ Duplikat (Dilewati): ${hasil.listDuplikat.length} barang', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ),
                if (hasil.error > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('❌ Gagal / Error: ${hasil.error} baris', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ),

                // ── TAMPILKAN DAFTAR KODE DUPLIKAT JIKA ADA ──
                if (hasil.listDuplikat.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(height: 1)),
                  const Text('Daftar Kode Duplikat (Dilewati):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 8),
                  Container(
                    height: 120, // Ketinggian list agar bisa discroll
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: hasil.listDuplikat.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text('• ${hasil.listDuplikat[index]}', style: const TextStyle(fontSize: 13, color: Colors.deepOrange)),
                        );
                      },
                    ),
                  ),
                ],

                // ── TAMPILKAN PESAN ERROR JIKA ADA ──
                if (hasil.pesanError.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(height: 1)),
                  const Text('Detail Masalah Format:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 120, 
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50, border: Border.all(color: Colors.red.shade200), borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: hasil.pesanError.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text('• ${hasil.pesanError[index]}', style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
                        );
                      },
                    ),
                  ),
                ]
              ],
            ),
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup Laporan'))
          ],
        );
      }
    );
  }
  
  void _showSnackbar(BuildContext context, String pesan, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan), backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Master Barang', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Daftar lengkap semua suku cadang', style: TextStyle(color: Colors.grey)),
                ],
              ),
              const Spacer(),
              
              // TAMPILKAN TOMBOL HAPUS JIKA ADA YANG DICENTANG
              Consumer<MasterProvider>(
                builder: (_, provider, __) {
                  if (!provider.isMultiSelectMode) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FilledButton.icon(
                      onPressed: () => _confirmHapus(context),
                      icon: const Icon(Icons.delete_sweep_rounded),
                      label: Text('Hapus Terpilih (${provider.selectedItems.length})'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
                    ),
                  );
                },
              ),

              PopupMenuButton<String>(
                tooltip: 'Import/Export Excel',
                onSelected: (value) async {
                  if (value == 'download') {
                    final path = await _importExportService.downloadTemplate();
                    if (path != null && context.mounted) _showSnackbar(context, 'Template disimpan:\n$path');
                  } else if (value == 'import') {
                    final hasil = await _importExportService.importDariExcel();
                    if (hasil != null && context.mounted) {
                      // PANGGIL MODAL POP-UP DI SINI (Gantikan Snackbar lama)
                      await _showImportResultDialog(context, hasil);
                      
                      context.read<MasterProvider>().loadData();
                    }
                  } else if (value == 'export') {
                    final semuaBarang = context.read<MasterProvider>().tampilBarang;
                    final path = await _importExportService.exportKeExcel(semuaBarang);
                    if (path != null && context.mounted) _showSnackbar(context, 'Diexport ke:\n$path');
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'download', child: Text('⬇️ Download Template')),
                  const PopupMenuItem(value: 'import', child: Text('📥 Import Data Excel')),
                  const PopupMenuItem(value: 'export', child: Text('📤 Export Data Excel')),
                ],
                child: Container(
                  margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(20)),
                  child: const Row(children: [Icon(Icons.table_view_rounded, color: Colors.white, size: 20), SizedBox(width: 8), Text('Excel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                ),
              ),

              FilledButton.icon(
                onPressed: () => _showFormDialog(context),
                icon: const Icon(Icons.add_rounded), label: const Text('Tambah Barang'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF01579B), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── FILTER & SEARCH BAR ──
          Row(
            children: [
              // DROPDOWN FILTER KATEGORI (BARU)
              Consumer<MasterProvider>(
                builder: (_, provider, __) => Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(12), 
                    border: Border.all(color: Colors.grey.shade300)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: provider.kategoriFilter,
                      isExpanded: true,
                      icon: const Icon(Icons.filter_list_rounded, color: Colors.grey),
                      items: ['Semua', 'PART', 'BUSI', 'OLI', 'BRG SLRG', 'NON AHM']
                          .map((k) => DropdownMenuItem(
                                value: k, 
                                child: Text(
                                  k, // <--- Langsung tampilkan 'Semua', 'PART', dst.
                                  style: TextStyle(
                                    color: k == 'Semua' ? Colors.grey.shade700 : Colors.black87,
                                    fontWeight: k == 'Semua' ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => provider.setKategoriFilter(v!),
                    ),
                  ),
                ),
              ),

              // KOLOM PENCARIAN
              Expanded(
                child: Consumer<MasterProvider>(
                  builder: (_, provider, __) => TextField(
                    controller: _searchCtrl,
                    onChanged: provider.cariBarang,
                    decoration: InputDecoration(
                      hintText: 'Cari nama barang atau kode...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _searchCtrl.clear(); provider.cariBarang(''); }) : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey)),
                      filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── TABEL ──
          Expanded(
            child: Consumer<MasterProvider>(
              builder: (_, provider, __) {
                if (provider.isLoading) return const Center(child: CircularProgressIndicator());
                if (provider.errorMessage.isNotEmpty) return Center(child: Text(provider.errorMessage));
                if (provider.tampilBarang.isEmpty) {
                  return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.inbox_rounded, size: 60, color: Colors.grey), SizedBox(height: 12), Text('Tidak ada barang ditemukan', style: TextStyle(color: Colors.grey, fontSize: 16))]));
                }

                // Cek apakah semua barang yang tampil saat ini tercentang
                final isAllVisibleSelected = provider.tampilBarang.isNotEmpty && 
                    provider.tampilBarang.every((b) => provider.selectedItems.contains(b.kodeScan));

                return Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    children: [
                      // HEADER TABEL
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: const BoxDecoration(color: Color(0xFFE3F2FD), borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))),
                        child: Row(
                          children: [
                            Checkbox(value: isAllVisibleSelected, onChanged: (_) => provider.toggleSelectAll()),
                            const Expanded(flex: 3, child: Text('Kode Scan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            const Expanded(flex: 5, child: Text('Nama Barang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            const Expanded(flex: 2, child: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            const Expanded(flex: 3, child: Text('Harga Modal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            const Expanded(flex: 3, child: Text('Harga Jual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            const Expanded(flex: 2, child: Text('Stok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                            const SizedBox(width: 80), 
                          ],
                        ),
                      ),
                      // ISI TABEL
                      Expanded(
                        child: ListView.separated(
                          itemCount: provider.tampilBarang.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                          itemBuilder: (ctx, i) => _buildBarangRow(context, provider, provider.tampilBarang[i], i),
                        ),
                      ),
                      // FOOTER
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)), border: Border(top: BorderSide(color: Colors.grey.shade200))),
                        child: Row(
                          children: [
                            Text('Menampilkan ${provider.tampilBarang.length} barang', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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

  // ── ROW TABEL DENGAN CHECKBOX ──
  Widget _buildBarangRow(BuildContext context, MasterProvider provider, Barang barang, int index) {
    final isSelected = provider.selectedItems.contains(barang.kodeScan);
    final stokColor = barang.stokSisa == 0 ? Colors.red : barang.stokSisa < 5 ? Colors.orange : Colors.green.shade700;

    return Container(
      color: isSelected ? Colors.blue.shade50 : (index.isEven ? Colors.grey.shade50 : Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Checkbox(value: isSelected, onChanged: (_) => provider.toggleItem(barang.kodeScan)),
          Expanded(flex: 3, child: Text(barang.kodeScan, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
          Expanded(flex: 5, child: Text(barang.namaBarang, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(6)), child: Text(barang.kategori, style: const TextStyle(fontSize: 11, color: Color(0xFF01579B)), textAlign: TextAlign.center))),
          Expanded(flex: 3, child: Text(_formatRupiah(barang.hargaAstra), style: const TextStyle(fontSize: 12))),
          Expanded(flex: 3, child: Text(_formatRupiah(barang.hargaJual), style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20)))),
          Expanded(flex: 2, child: Text('${barang.stokSisa}', style: TextStyle(fontWeight: FontWeight.bold, color: stokColor, fontSize: 13), textAlign: TextAlign.center)),
          SizedBox(width: 80, child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(tooltip: 'Edit barang', icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF0288D1)), onPressed: () => _showFormDialog(context, barangEdit: barang)),
              IconButton(tooltip: 'Hapus barang', icon: Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade400), onPressed: () => _confirmHapus(context, barang: barang)),
            ],
          )),
        ],
      ),
    );
  }
}