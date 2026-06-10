import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/master_provider.dart';
import '../services/import_export_service.dart';

// ─────────────────────────────────────────────────────────────
// Widget ini dipasang di header MasterBarangView, sejajar
// dengan tombol "Tambah Barang".
//
// Letakkan di presentation/widgets/import_export_section.dart
//
// CARA PAKAI di master_barang_view.dart:
//   Row(children: [
//     ...judul...,
//     const Spacer(),
//     const ImportExportSection(),   // ← tambahkan ini
//     const SizedBox(width: 12),
//     FilledButton.icon(...)         // tombol Tambah Barang
//   ])
// ─────────────────────────────────────────────────────────────

class ImportExportSection extends StatelessWidget {
  const ImportExportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Tombol Import ──────────────────────
        OutlinedButton.icon(
          onPressed: () => _showImportDialog(context),
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: const Text('Import Excel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF01579B),
            side: const BorderSide(color: Color(0xFF01579B)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(width: 8),

        // ── Tombol Export ──────────────────────
        OutlinedButton.icon(
          onPressed: () => _showExportDialog(context),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Export Excel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2E7D32),
            side: const BorderSide(color: Color(0xFF2E7D32)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ── Dialog Import ────────────────────────────
  Future<void> _showImportDialog(BuildContext context) async {
    final svc = ImportExportService();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upload_file_rounded, color: Color(0xFF01579B)),
            SizedBox(width: 10),
            Text('Import Data dari Excel'),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panduan singkat 2 kalimat
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF90CAF9)),
                ),
                child: const Text(
                  'Unduh template Excel di bawah, isi data barang sesuai sheet '
                  'kategorinya (AHM, BRG SLRG, NON AHM), lalu pilih file '
                  'tersebut untuk diimpor ke aplikasi.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),

              // Langkah visual
              _buildLangkah('1', Icons.download_rounded,
                  'Unduh template', 'Klik tombol di bawah untuk mendapat file Excel kosong'),
              _buildLangkah('2', Icons.edit_rounded,
                  'Isi data', 'Buka file, isi barang di sheet sesuai kategori'),
              _buildLangkah('3', Icons.upload_file_rounded,
                  'Import', 'Klik "Pilih File & Import", lalu pilih file yang sudah diisi'),

              const SizedBox(height: 20),

              // Tombol download template
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final path = await svc.downloadTemplate();
                    if (!ctx.mounted) return;
                    if (path != null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('Template disimpan di:\n$path'),
                        backgroundColor: Colors.green.shade600,
                        duration: const Duration(seconds: 5),
                        behavior: SnackBarBehavior.floating,
                      ));
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Gagal mengunduh template.'),
                        backgroundColor: Colors.red,
                      ));
                    }
                  },
                  icon: const Icon(Icons.file_download_rounded),
                  label: const Text('Unduh Template Excel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF01579B),
                    side: const BorderSide(color: Color(0xFF01579B)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _prosesImport(context, svc);
            },
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Pilih File & Import'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF01579B),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _prosesImport(BuildContext context, ImportExportService svc) async {
    // Tampilkan loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Sedang mengimpor data...'),
          ],
        ),
      ),
    );

    final hasil = await svc.importDariExcel();

    if (!context.mounted) return;
    Navigator.pop(context); // tutup loading

    if (hasil == null) return; // user batalkan pemilihan file

    // Reload data di provider
    await context.read<MasterProvider>().loadData();

    if (!context.mounted) return;

    // Tampilkan hasil
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          hasil.berhasil > 0 ? Icons.check_circle_rounded : Icons.info_rounded,
          color: hasil.berhasil > 0 ? Colors.green : Colors.orange,
          size: 40,
        ),
        title: Text(hasil.berhasil > 0 ? 'Import Selesai' : 'Tidak Ada Data Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hasil.ringkasan, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14)),
            if (hasil.pesanError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: hasil.pesanError
                      .map((e) => Text('• $e',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700)))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Dialog Export ────────────────────────────
  Future<void> _showExportDialog(BuildContext context) async {
    final provider = context.read<MasterProvider>();
    final svc = ImportExportService();

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: Color(0xFF2E7D32)),
            SizedBox(width: 10),
            Text('Export Data ke Excel'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Text(
                'Seluruh ${provider.totalBarang} data master barang akan diekspor ke file '
                'Excel yang tersimpan otomatis di folder Dokumen.',
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.table_chart_rounded,
                'Format: 1 sheet per kategori (AHM, BRG SLRG, NON AHM)'),
            _buildInfoRow(Icons.folder_rounded,
                'Lokasi: Folder Dokumen Windows Anda'),
            _buildInfoRow(Icons.lock_clock_rounded,
                'Nama file: export_master_YYYY-MM-DD HH-mm.xlsx'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Export Sekarang'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    // Lakukan export
    final path = await svc.exportKeExcel(provider.tampilBarang);

    if (!context.mounted) return;

    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export berhasil!',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(path, style: const TextStyle(fontSize: 11)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal mengekspor data.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ─── Helper widget ───────────────────────────
  Widget _buildLangkah(String nomor, IconData icon, String judul, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26, height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFF01579B),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(nomor,
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 20, color: const Color(0xFF01579B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
                Text(sub, style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String teks) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          Expanded(child: Text(teks, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
