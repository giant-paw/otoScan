// File: lib/features/stok_pesanan/data/pesanan_export_service.dart

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'stok_pesanan_repository.dart';

// ─────────────────────────────────────────────────────────────────
// PESANAN EXPORT SERVICE — daftar barang perlu dipesan → Excel
// (pakai package `excel`, bukan syncfusion)
//
// Permintaan Obi: "daftar barang yg perlu dipesen, export ke excel"
//
// Kolom: No | Kode | Nama | Kategori | Stok Skrg | Terjual 30hr |
//        Saran Pesan | Harga Astra | Estimasi Biaya | Prioritas
// ─────────────────────────────────────────────────────────────────

class PesananExportService {
  final _repo = StokPesananRepository();

  static const String _fmtRp = r'"Rp" #,##0;-"Rp" #,##0;"Rp" -';

  ExcelColor get _biru  => ExcelColor.fromHexString('#1F3864');
  ExcelColor get _putih => ExcelColor.fromHexString('#FFFFFF');
  ExcelColor get _abu   => ExcelColor.fromHexString('#F2F2F2');
  ExcelColor get _kuning=> ExcelColor.fromHexString('#FFF2CC');

  Border _bd() => Border(borderStyle: BorderStyle.Thin);

  void _teks(Sheet sh, int c, int r, String v, CellStyle st) {
    final cell = sh.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = TextCellValue(v);
    cell.cellStyle = st;
  }

  void _angka(Sheet sh, int c, int r, int v, CellStyle st) {
    final cell = sh.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = IntCellValue(v);
    cell.cellStyle = st;
  }

  Future<String> exportPesanan() async {
    final saran = await _repo.saranPesanan();
    final ringkasan = await _repo.ringkasanPesanan();

    final excel = Excel.createExcel();
    final String? defaultSheet = excel.getDefaultSheet();
    final sheet = excel['Daftar Pesanan'];

    // Judul
    _teks(sheet, 0, 0, 'DAFTAR BARANG PERLU DIPESAN',
        CellStyle(bold: true, fontSize: 14, fontColorHex: _biru));

    final now = DateTime.now();
    _teks(sheet, 0, 1,
        'Dibuat: ${now.day}/${now.month}/${now.year} — berdasarkan penjualan 30 hari terakhir',
        CellStyle(italic: true, fontSize: 10));

    // Header (baris index 3)
    const headerRow = 3;
    final headerStyle = CellStyle(
      backgroundColorHex: _biru,
      fontColorHex: _putih,
      bold: true,
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd(),
    );
    final headers = [
      'No', 'Kode', 'Nama Barang', 'Kategori', 'Stok\nSekarang',
      'Terjual\n30 Hari', 'Saran\nPesan', 'Harga Astra', 'Estimasi Biaya', 'Prioritas',
    ];
    for (int i = 0; i < headers.length; i++) {
      _teks(sheet, i, headerRow, headers[i], headerStyle);
    }

    // Data
    int r = headerRow + 1;
    int no = 1;
    for (final item in saran) {
      final prioritas = item['prioritas'] as String;
      final warnaPrioritas = prioritas == 'TINGGI'
          ? ExcelColor.fromHexString('#F4B6C2')
          : prioritas == 'SEDANG'
              ? _kuning
              : _putih;

      final sTeks = CellStyle(fontSize: 10,
          leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());
      final sNum = CellStyle(fontSize: 10, horizontalAlign: HorizontalAlign.Center,
          leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());
      final sSaran = CellStyle(fontSize: 10, bold: true, horizontalAlign: HorizontalAlign.Center,
          backgroundColorHex: _kuning,
          leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());
      final sRp = CellStyle(fontSize: 10, numberFormat: NumFormat.custom(formatCode: _fmtRp),
          leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());
      final sPrioritas = CellStyle(fontSize: 10, bold: true,
          horizontalAlign: HorizontalAlign.Center,
          backgroundColorHex: warnaPrioritas,
          leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());

      _angka(sheet, 0, r, no, sNum);
      _teks(sheet, 1, r, item['kodeScan'] as String, sTeks);
      _teks(sheet, 2, r, item['namaBarang'] as String, sTeks);
      _teks(sheet, 3, r, item['kategori'] as String, sTeks);
      _angka(sheet, 4, r, item['stokSisa'] as int, sNum);
      _angka(sheet, 5, r, item['terjual30'] as int, sNum);
      _angka(sheet, 6, r, item['saranQty'] as int, sSaran);
      _angka(sheet, 7, r, item['hargaAstra'] as int, sRp);
      _angka(sheet, 8, r, item['estimasiBiaya'] as int, sRp);
      _teks(sheet, 9, r, prioritas, sPrioritas);
      r++;
      no++;
    }

    // Baris TOTAL
    final totTeks = CellStyle(backgroundColorHex: _abu, bold: true, fontSize: 10,
        leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());
    final totRp = CellStyle(backgroundColorHex: _abu, bold: true, fontSize: 10,
        numberFormat: NumFormat.custom(formatCode: _fmtRp),
        leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());
    final totNum = CellStyle(backgroundColorHex: _abu, bold: true, fontSize: 10,
        horizontalAlign: HorizontalAlign.Center,
        leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());

    _teks(sheet, 0, r, 'TOTAL', totTeks);
    _teks(sheet, 1, r, '', totTeks);
    _teks(sheet, 2, r, '', totTeks);
    _teks(sheet, 3, r, '', totTeks);
    _teks(sheet, 4, r, '', totTeks);
    _teks(sheet, 5, r, '', totTeks);
    _angka(sheet, 6, r, ringkasan['totalQty'] ?? 0, totNum);
    _teks(sheet, 7, r, '', totTeks);
    _angka(sheet, 8, r, ringkasan['totalBiaya'] ?? 0, totRp);
    _teks(sheet, 9, r, '', totTeks);

    // Lebar kolom
    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 16);
    sheet.setColumnWidth(2, 28);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 10);
    sheet.setColumnWidth(5, 10);
    sheet.setColumnWidth(6, 9);
    sheet.setColumnWidth(7, 14);
    sheet.setColumnWidth(8, 16);
    sheet.setColumnWidth(9, 11);

    // Hapus sheet default
    if (defaultSheet != null &&
        defaultSheet != 'Daftar Pesanan' &&
        excel.sheets.length > 1) {
      excel.delete(defaultSheet);
    }

    // Simpan
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'OtoScan_Laporan'));
    if (!await folder.exists()) await folder.create(recursive: true);

    final stamp = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}'
        '_${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}';
    final filePath = p.join(folder.path, 'Pesanan_OtoScan_$stamp.xlsx');

    final bytes = excel.save();
    if (bytes == null) throw Exception('Gagal generate Excel');
    await File(filePath).writeAsBytes(bytes, flush: true);

    return filePath;
  }
}