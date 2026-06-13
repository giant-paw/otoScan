// File: lib/features/laporan/data/laporan_export_service.dart

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'laporan_repository.dart';

// ─────────────────────────────────────────────────────────────────
// LAPORAN EXPORT SERVICE — generate Excel sesuai format kantor
//
// Output: 1 file Excel dengan sheet:
//   - RINGKASAN (KPI + top barang + per kategori)
//   - 1 sheet per kategori (BUSI, OLI, PART, dll) dengan kolom:
//       Kode | Nama | Qty Masuk | Harga Astra | Harga Total |
//       Qty Keluar | Harga Jual | Laba | Modal | Sisa
//
// Format mengikuti template_laporan_otoscan.xlsx dari kantor.
//
// CATATAN: pakai package 'excel' (bukan openpyxl). Formula tidak
//   bisa dipakai langsung, jadi nilai dihitung di Dart lalu ditulis
//   sebagai angka. Ini lebih aman & cepat untuk dibuka di HP/PC.
// ─────────────────────────────────────────────────────────────────

class LaporanExportService {
  final _repo = LaporanRepository();

  // Warna header per kategori (mengikuti template kantor)
  static const Map<String, String> _warnaKategori = {
    'BUSI':     'FF1B5E20', // hijau tua
    'BRG SRLG': 'FF4E342E', // coklat
    'OLI':      'FF0277BD', // biru
    'PART':     'FF880E4F', // ungu
    'NON AHM':  'FFE65100', // oranye
  };

  // ─────────────────────────────────────────────────────────────
  // EXPORT — generate file Excel, return path file
  // ─────────────────────────────────────────────────────────────
  Future<String> exportLaporan({
    required String dari,
    required String sampai,
    required String labelPeriode,
  }) async {
    final excel = Excel.createExcel();

    // Hapus sheet default
    final defaultSheet = excel.getDefaultSheet();

    // ── SHEET 1: RINGKASAN ──
    await _buatSheetRingkasan(excel, dari, sampai, labelPeriode);

    // ── SHEET per kategori ──
    final kategoris = await _repo.daftarKategori();
    for (final kat in kategoris) {
      await _buatSheetKategori(excel, kat, dari, sampai);
    }

    // Hapus sheet default kalau masih ada & bukan satu-satunya
    if (defaultSheet != null && excel.sheets.length > 1) {
      excel.delete(defaultSheet);
    }

    // ── SIMPAN FILE ──
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'OtoScan_Laporan'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}'
                  '_${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}';
    final fileName = 'Laporan_OtoScan_$stamp.xlsx';
    final filePath = p.join(folder.path, fileName);

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Gagal generate file Excel');
    }
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    return filePath;
  }

  // ─────────────────────────────────────────────────────────────
  // SHEET RINGKASAN
  // ─────────────────────────────────────────────────────────────
  Future<void> _buatSheetRingkasan(
    Excel excel, String dari, String sampai, String labelPeriode,
  ) async {
    final sheet = excel['RINGKASAN'];

    final ringkasan = await _repo.ringkasanPeriode(dari: dari, sampai: sampai);
    final topBarang = await _repo.topBarangTerlaris(dari: dari, sampai: sampai, limit: 10);
    final perKategori = await _repo.ringkasanPerKategori(dari: dari, sampai: sampai);
    final modalTidak = await _repo.modalTidakBerputar(dari: dari, sampai: sampai);
    final piutang = await _repo.totalPiutangAktif();

    int row = 0;

    // Judul
    final judulCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    judulCell.value = TextCellValue('LAPORAN PENJUALAN — OTOSCAN LOGISTIK');
    judulCell.cellStyle = CellStyle(
      bold: true, fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('FF1B5E20'),
    );
    row++;

    final periodeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    periodeCell.value = TextCellValue('Periode: $labelPeriode');
    periodeCell.cellStyle = CellStyle(italic: true, fontSize: 11);
    row += 2;

    // ── Section: KPI Keuangan ──
    _tulisHeader(sheet, row, 'RINGKASAN KEUANGAN', 'FF1B5E20');
    row++;

    final kpiData = [
      ['Omzet (Total Penjualan)', ringkasan['omzet'] ?? 0],
      ['Laba Kotor', ringkasan['totalLaba'] ?? 0],
      ['Modal Terjual (HPP)', ringkasan['totalModal'] ?? 0],
      ['Uang Masuk (Tunai)', ringkasan['totalDibayar'] ?? 0],
      ['Hutang Baru (Periode Ini)', ringkasan['totalHutangBaru'] ?? 0],
      ['Total Piutang Aktif (Semua)', piutang],
      ['Modal Tidak Berputar', modalTidak['modalTidakLaku'] ?? 0],
    ];

    for (final item in kpiData) {
      final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      labelCell.value = TextCellValue(item[0] as String);
      final valCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      valCell.value = IntCellValue(item[1] as int);
      valCell.cellStyle = CellStyle(numberFormat: NumFormat.custom(formatCode: '#,##0'));
      row++;
    }
    row++;

    // ── Section: KPI Transaksi ──
    _tulisHeader(sheet, row, 'STATISTIK TRANSAKSI', 'FF0277BD');
    row++;

    final statData = [
      ['Jumlah Nota', ringkasan['jumlahNota'] ?? 0],
      ['Jumlah Item Terjual', ringkasan['jumlahItem'] ?? 0],
      ['Rata-rata per Nota', ringkasan['rataRataPerNota'] ?? 0],
    ];
    for (final item in statData) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(item[0] as String);
      final valCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      valCell.value = IntCellValue(item[1] as int);
      valCell.cellStyle = CellStyle(numberFormat: NumFormat.custom(formatCode: '#,##0'));
      row++;
    }
    row++;

    // ── Section: Top 10 Barang Terlaris ──
    _tulisHeader(sheet, row, 'TOP 10 BARANG TERLARIS', 'FF880E4F');
    row++;

    // Header tabel
    final headerTop = ['No', 'Nama Barang', 'Kategori', 'Qty Terjual', 'Omzet', 'Laba'];
    for (int c = 0; c < headerTop.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      cell.value = TextCellValue(headerTop[c]);
      cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('FFF3E5F5'));
    }
    row++;

    int rank = 1;
    for (final b in topBarang) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = IntCellValue(rank);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(b['namaBarang'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(b['kategori'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = IntCellValue(b['totalQty'] as int);
      final omzetCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
      omzetCell.value = IntCellValue(b['totalOmzet'] as int);
      omzetCell.cellStyle = CellStyle(numberFormat: NumFormat.custom(formatCode: '#,##0'));
      final labaCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
      labaCell.value = IntCellValue(b['totalLaba'] as int);
      labaCell.cellStyle = CellStyle(numberFormat: NumFormat.custom(formatCode: '#,##0'));
      row++;
      rank++;
    }
    row++;

    // ── Section: Breakdown per Kategori ──
    _tulisHeader(sheet, row, 'PENJUALAN PER KATEGORI', 'FFE65100');
    row++;

    final headerKat = ['Kategori', 'Qty Terjual', 'Omzet', 'Laba'];
    for (int c = 0; c < headerKat.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      cell.value = TextCellValue(headerKat[c]);
      cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('FFFFE0B2'));
    }
    row++;

    for (final k in perKategori) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(k['kategori'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = IntCellValue(k['totalQty'] as int);
      final oCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      oCell.value = IntCellValue(k['totalOmzet'] as int);
      oCell.cellStyle = CellStyle(numberFormat: NumFormat.custom(formatCode: '#,##0'));
      final lCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
      lCell.value = IntCellValue(k['totalLaba'] as int);
      lCell.cellStyle = CellStyle(numberFormat: NumFormat.custom(formatCode: '#,##0'));
      row++;
    }

    // Lebar kolom
    sheet.setColumnWidth(0, 28);
    sheet.setColumnWidth(1, 32);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 16);
    sheet.setColumnWidth(5, 16);
  }

  // ─────────────────────────────────────────────────────────────
  // SHEET PER KATEGORI
  // ─────────────────────────────────────────────────────────────
  Future<void> _buatSheetKategori(
    Excel excel, String kategori, String dari, String sampai,
  ) async {
    final data = await _repo.laporanPerKategori(
      kategori: kategori, dari: dari, sampai: sampai,
    );

    // Nama sheet maksimal 31 char & tidak boleh karakter aneh
    final sheetName = kategori.length > 28 ? kategori.substring(0, 28) : kategori;
    final sheet = excel[sheetName];

    final warna = _warnaKategori[kategori] ?? 'FF424242';

    int row = 0;

    // Judul
    final judul = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    judul.value = TextCellValue('LAPORAN STOK — $kategori');
    judul.cellStyle = CellStyle(
      bold: true, fontSize: 14,
      fontColorHex: ExcelColor.fromHexString(warna),
    );
    row += 2;

    // Header tabel
    final headers = [
      'KODE', 'NAMA SUKU CADANG',
      'QTY MASUK', 'HARGA ASTRA', 'HARGA TOTAL',
      'QTY KELUAR', 'HARGA JUAL', 'LABA (Rp)', 'MODAL (Rp)', 'SISA',
    ];
    for (int c = 0; c < headers.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString(warna),
        horizontalAlign: HorizontalAlign.Center,
      );
    }
    row++;

    final int headerRow = row - 1;
    final int dataStart = row;

    // Data rows
    int totalLaba = 0;
    int totalModal = 0;
    int totalHargaTotal = 0;

    for (final item in data) {
      final qtyMasuk  = item['qtyMasuk'] as int;
      final hargaAstra = item['hargaAstra'] as int;
      final qtyKeluar = item['qtyKeluar'] as int;
      final hargaJual = item['hargaJual'] as int;
      final stokSisa  = item['stokSisa'] as int;

      // Hitung di Dart (karena package excel formula kurang reliable)
      final hargaTotal = qtyMasuk * hargaAstra;       // modal barang masuk
      final laba = (hargaJual - hargaAstra) * qtyKeluar; // laba dari yang terjual
      final modal = qtyKeluar * hargaAstra;            // modal yang terjual

      totalHargaTotal += hargaTotal;
      totalLaba += laba;
      totalModal += modal;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(item['kodeScan'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(item['namaBarang'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = IntCellValue(qtyMasuk);
      _setRp(sheet, 3, row, hargaAstra);
      _setRp(sheet, 4, row, hargaTotal);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = IntCellValue(qtyKeluar);
      _setRp(sheet, 6, row, hargaJual);
      _setRp(sheet, 7, row, laba);
      _setRp(sheet, 8, row, modal);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = IntCellValue(stokSisa);

      // Zebra stripe
      if ((row - dataStart) % 2 == 1) {
        for (int c = 0; c < 10; c++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
          cell.cellStyle = (cell.cellStyle ?? CellStyle()).copyWith(
            backgroundColorHexVal: ExcelColor.fromHexString('FFF5F5F5'),
          );
        }
      }
      row++;
    }

    // Baris TOTAL
    row++;
    final totalLabel = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    totalLabel.value = TextCellValue('TOTAL');
    totalLabel.cellStyle = CellStyle(bold: true);

    _setRp(sheet, 4, row, totalHargaTotal, bold: true);
    _setRp(sheet, 7, row, totalLaba, bold: true);
    _setRp(sheet, 8, row, totalModal, bold: true);

    // Lebar kolom
    sheet.setColumnWidth(0, 16);
    sheet.setColumnWidth(1, 32);
    for (int c = 2; c < 10; c++) {
      sheet.setColumnWidth(c, 13);
    }

    // Freeze header
    // (package excel belum support freeze pane reliable, skip)
  }

  // ── HELPER ───────────────────────────────────────────────────
  void _tulisHeader(Sheet sheet, int row, String teks, String warna) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    cell.value = TextCellValue(teks);
    cell.cellStyle = CellStyle(
      bold: true, fontSize: 12,
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString(warna),
    );
  }

  void _setRp(Sheet sheet, int col, int row, int nilai, {bool bold = false}) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = IntCellValue(nilai);
    cell.cellStyle = CellStyle(
      bold: bold,
      numberFormat: NumFormat.custom(formatCode: '#,##0'),
    );
  }
}
