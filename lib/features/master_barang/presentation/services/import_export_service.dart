import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../../data/barang_model.dart';
import '../../data/master_repository.dart';

// ──────────────────────────────────────────────────────────────
// CARA PAKAI:
//
//   final svc = ImportExportService();
//
//   // Download template kosong:
//   await svc.downloadTemplate();
//
//   // Import dari file Excel yang dipilih user:
//   final hasil = await svc.importDariExcel();
//
//   // Export semua data ke Excel:
//   await svc.exportKeExcel(semuaBarang);
//
// ──────────────────────────────────────────────────────────────

class HasilImport {
  final int berhasil;
  final List<String> listDuplikat;
  final int error;
  final List<String> pesanError;

  HasilImport({
    required this.berhasil,
    required this.listDuplikat,
    required this.error,
    required this.pesanError,
  });

  String get ringkasan =>
      '$berhasil barang berhasil diimpor'
      '${listDuplikat.isNotEmpty ? ', ${listDuplikat.length} duplikat' : ''}'
      '${error > 0 ? ', $error baris error' : ''}.';
}

class ImportExportService {
  final _repo = MasterRepository();

  // Nama sheet yang dikenali
  static const _sheetValid = ['PART', 'BUSI', 'OLI', 'BRG SLRG', 'NON AHM'];

  // ── DOWNLOAD TEMPLATE ──────────────────────────
  Future<String?> downloadTemplate() async {
    try {
      // Template disimpan di assets/template_import_master_barang.xlsx
      final bytes = await rootBundle.load(
        'assets/template_import_master_barang.xlsx',
      );

      // Simpan ke folder Documents user
      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}\\template_import_master_barang.xlsx';

      final file = File(filePath);
      await file.writeAsBytes(bytes.buffer.asUint8List());

      return filePath; // kembalikan path untuk ditampilkan ke user
    } catch (e) {
      return null;
    }
  }

  // ── IMPORT DARI EXCEL ──────────────────────────
  Future<HasilImport?> importDariExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      dialogTitle: 'Pilih file template master barang',
    );
    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path!;
    final bytes = await File(path).readAsBytes();
    
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      return HasilImport(
        berhasil: 0, listDuplikat: [], error: 1, // listDuplikat kosong jika format hancur
        pesanError: ['Gagal membaca Excel! Pastikan format kolom adalah "General" (Gunakan trik Paste as Values 123)'],
      );
    }

    int berhasil = 0;
    final listDuplikat = <String>[]; // <-- BUAT DAFTAR KOSONG UNTUK MENAMPUNG KODE DUPLIKAT
    int errorCount = 0;
    final pesanError = <String>[];

    for (final namaSheet in _sheetValid) {
      final sheet = excel.tables[namaSheet];
      if (sheet == null) continue;

      final rows = sheet.rows;
      if (rows.length < 4) continue; 

      for (int i = 3; i < rows.length; i++) {
        final row = rows[i];
        final kodeScan  = _ambilTeks(row, 0);
        final namaBarang = _ambilTeks(row, 1);
        final kategori  = _ambilTeks(row, 2).isNotEmpty ? _ambilTeks(row, 2) : namaSheet;

        if (kodeScan.isEmpty || namaBarang.isEmpty) continue;
        if (namaBarang.toLowerCase().contains('contoh')) continue;

        final hargaAstra = _ambilInt(row, 3);
        final hargaJual  = _ambilInt(row, 4);
        final stokAwal   = _ambilInt(row, 5);

        // CEK DUPLIKAT
        final sudahAda = await _repo.isKodeExist(kodeScan);
        if (sudahAda) {
          listDuplikat.add(kodeScan); // <-- MASUKKAN KODENYA KE DAFTAR
          continue;
        }

        try {
          final barang = Barang(
            kodeScan: kodeScan.toUpperCase(), namaBarang: namaBarang, kategori: kategori,
            hargaAstra: hargaAstra, hargaJual: hargaJual, stokSisa: stokAwal,
          );
          final ok = await _repo.insertBarang(barang);
          if (ok) berhasil++;
          else { errorCount++; pesanError.add('Baris ${i + 1} ($namaSheet): gagal disimpan'); }
        } catch (e) {
          errorCount++; pesanError.add('Baris ${i + 1} ($namaSheet): $e');
        }
      }
    }

    return HasilImport(
      berhasil: berhasil,
      listDuplikat: listDuplikat, // <-- KEMBALIKAN DAFTARNYA
      error: errorCount,
      pesanError: pesanError,
    );
  }

  // ── EXPORT KE EXCEL ────────────────────────────
  Future<String?> exportKeExcel(List<Barang> semuaBarang) async {
    final excel = Excel.createExcel();

    // Buat satu sheet per kategori
    final grupKategori = <String, List<Barang>>{};
    for (final b in semuaBarang) {
      grupKategori.putIfAbsent(b.kategori, () => []).add(b);
    }

    // Hapus sheet default kosong
    excel.delete('Sheet1');

    for (final entry in grupKategori.entries) {
      final namaSheet = entry.key;
      final sheet = excel[namaSheet];

      // Header
      final headers = [
        'Kode Scan', 'Nama Barang', 'Kategori',
        'Harga Modal (Rp)', 'Harga Jual (Rp)', 'Stok Sisa',
      ];
      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = CellStyle(bold: true);
      }

      // Data
      for (int r = 0; r < entry.value.length; r++) {
        final b = entry.value[r];
        final baris = [
          b.kodeScan, b.namaBarang, b.kategori,
          b.hargaAstra, b.hargaJual, b.stokSisa,
        ];
        for (int c = 0; c < baris.length; c++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1),
          );
          final v = baris[c];
          cell.value = v is int
              ? IntCellValue(v)
              : TextCellValue(v.toString());
        }
      }
    }

    // Simpan file
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toString()
          .replaceAll(':', '-')
          .substring(0, 16);
      final filePath = '${dir.path}\\export_master_$timestamp.xlsx';

      final bytes = excel.save();
      if (bytes == null) return null;

      await File(filePath).writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      return null;
    }
  }

  // ── Helper ─────────────────────────────────────
  String _ambilTeks(List<Data?> row, int col) {
    if (col >= row.length) return '';
    final v = row[col]?.value;
    if (v == null) return '';
    return v.toString().trim();
  }

  int _ambilInt(List<Data?> row, int col) {
    if (col >= row.length) return 0;
    final v = row[col]?.value;
    if (v == null) return 0;
    return int.tryParse(v.toString().replaceAll('.', '').trim()) ?? 0;
  }
}
