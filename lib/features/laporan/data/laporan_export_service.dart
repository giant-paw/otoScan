// File: lib/features/laporan/data/laporan_export_service.dart

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'laporan_repository.dart';

// ─────────────────────────────────────────────────────────────────
// LAPORAN EXPORT SERVICE — pakai package `excel` (bukan syncfusion)
//
// Konsekuensi package excel: header tidak bisa merge bertingkat,
// jadi header dibuat 1 baris yang jelas. Semua kolom, warna, dan
// total tetap ada. Angka dihitung di Dart lalu ditulis sebagai
// angka asli (bisa di-SUM sendiri oleh owner di Excel).
//
// Sheet:
//   1. REKAP TOTAL  → Jumlah Modal | Laba | Uang | Total
//                     (header hitam, teks putih, border merah — gambar 2)
//   2. per kategori → KODE | NAMA | QTY MASUK | HARGA ASTRA | HARGA TOTAL |
//                     QTY KELUAR | HARGA JUAL | LABA | JUMLAH MODAL | SISA |
//                     MODAL TIDAK BERPUTAR  (header biru, data hijau,
//                     qty keluar 0 → pink, baris TOTAL di bawah)
//
// Definisi REKAP:
//   Jumlah Modal = nilai modal SELURUH stok gudang (stok × harga astra)
//   Jumlah Laba  = total laba penjualan periode
//   Jumlah Uang  = total kas masuk periode (yang dibayar)
//   Jumlah Total = total omzet penjualan periode
// ─────────────────────────────────────────────────────────────────

class LaporanExportService {
  final _repo = LaporanRepository();

  // Format angka Rupiah: positif ; negatif ; nol("Rp -")
  static const String _fmtRp = r'"Rp" #,##0;-"Rp" #,##0;"Rp" -';

  ExcelColor get _biru  => ExcelColor.fromHexString('#1F3864');
  ExcelColor get _hijau => ExcelColor.fromHexString('#00B050');
  ExcelColor get _pink  => ExcelColor.fromHexString('#F4B6C2');
  ExcelColor get _abu   => ExcelColor.fromHexString('#F2F2F2');
  ExcelColor get _putih => ExcelColor.fromHexString('#FFFFFF');
  ExcelColor get _hitam => ExcelColor.fromHexString('#000000');
  ExcelColor get _merah => ExcelColor.fromHexString('#FF0000');

  // ─────────────────────────────────────────────────────────────
  Future<String> exportLaporan({
    required String dari,
    required String sampai,
    required String labelPeriode,
  }) async {
    final excel = Excel.createExcel();
    final String? defaultSheet = excel.getDefaultSheet();

    // Sheet 1: REKAP TOTAL
    await _isiRekap(excel, dari, sampai, labelPeriode);

    // Sheet per kategori
    final kategoris = await _repo.daftarKategori();
    for (final kat in kategoris) {
      await _isiKategori(excel, kat, dari, sampai, labelPeriode);
    }

    // Hapus sheet default kosong
    if (defaultSheet != null &&
        defaultSheet != 'REKAP TOTAL' &&
        excel.sheets.length > 1) {
      excel.delete(defaultSheet);
    }

    // Simpan
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'OtoScan_Laporan'));
    if (!await folder.exists()) await folder.create(recursive: true);

    final now = DateTime.now();
    final stamp = '${now.year}${_p2(now.month)}${_p2(now.day)}_${_p2(now.hour)}${_p2(now.minute)}';
    final filePath = p.join(folder.path, 'Laporan_OtoScan_$stamp.xlsx');

    final bytes = excel.save();
    if (bytes == null) throw Exception('Gagal generate Excel');
    await File(filePath).writeAsBytes(bytes, flush: true);

    return filePath;
  }

  String _p2(int n) => n.toString().padLeft(2, '0');

  String _namaSheet(String kat) {
    var s = kat.replaceAll(RegExp(r'[:\\/?*\[\]]'), '');
    if (s.length > 31) s = s.substring(0, 31);
    return s;
  }

  // ── Helper set cell ──────────────────────────────────────────
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

  Border _bd([ExcelColor? warna]) =>
      Border(borderStyle: BorderStyle.Thin, borderColorHex: warna);

  // ═════════════════════════════════════════════════════════════
  // SHEET REKAP TOTAL (gaya gambar 2)
  // ═════════════════════════════════════════════════════════════
  Future<void> _isiRekap(
    Excel excel, String dari, String sampai, String labelPeriode,
  ) async {
    final sheet = excel['REKAP TOTAL'];

    final ringkasan = await _repo.ringkasanPeriode(dari: dari, sampai: sampai);
    final modalStok = await _repo.modalTidakBerputar(dari: dari, sampai: sampai);

    final jumlahModal = modalStok['totalModalStok'] ?? 0; // nilai seluruh stok
    final jumlahLaba  = ringkasan['totalLaba'] ?? 0;
    final jumlahUang  = ringkasan['totalDibayar'] ?? 0;
    final jumlahTotal = ringkasan['omzet'] ?? 0;

    // Judul
    _teks(sheet, 0, 0, 'REKAP LAPORAN — OTOSCAN LOGISTIK',
        CellStyle(bold: true, fontSize: 15, fontColorHex: _biru));
    _teks(sheet, 0, 1, 'Periode: $labelPeriode',
        CellStyle(italic: true, fontSize: 10));

    // Header hitam (baris index 3)
    final headerStyle = CellStyle(
      backgroundColorHex: _hitam,
      fontColorHex: _putih,
      bold: true,
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _bd(_merah), rightBorder: _bd(_merah),
      topBorder: _bd(_merah), bottomBorder: _bd(_merah),
    );
    final headers = ['Jumlah Modal', 'Jumlah Laba', 'Jumlah Uang', 'Jumlah Total'];
    for (int i = 0; i < headers.length; i++) {
      _teks(sheet, i, 3, headers[i], headerStyle);
    }

    // Value hitam (baris index 4)
    final valStyle = CellStyle(
      backgroundColorHex: _hitam,
      fontColorHex: _putih,
      bold: true,
      fontSize: 12,
      numberFormat: NumFormat.custom(formatCode: _fmtRp),
      horizontalAlign: HorizontalAlign.Center,
      leftBorder: _bd(_merah), rightBorder: _bd(_merah),
      topBorder: _bd(_merah), bottomBorder: _bd(_merah),
    );
    _angka(sheet, 0, 4, jumlahModal, valStyle);
    _angka(sheet, 1, 4, jumlahLaba, valStyle);
    _angka(sheet, 2, 4, jumlahUang, valStyle);
    _angka(sheet, 3, 4, jumlahTotal, valStyle);

    // Keterangan
    final ketStyle = CellStyle(italic: true, fontSize: 9, fontColorHex: ExcelColor.fromHexString('#666666'));
    _teks(sheet, 0, 6, 'Keterangan:', CellStyle(bold: true, fontSize: 9));
    _teks(sheet, 0, 7, 'Jumlah Modal = nilai modal seluruh stok tersimpan di gudang (stok x harga astra)', ketStyle);
    _teks(sheet, 0, 8, 'Jumlah Laba  = total keuntungan penjualan pada periode ini', ketStyle);
    _teks(sheet, 0, 9, 'Jumlah Uang  = total uang tunai yang sudah diterima (kas masuk)', ketStyle);
    _teks(sheet, 0, 10, 'Jumlah Total = total nilai penjualan / omzet pada periode ini', ketStyle);

    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 20);
  }

  // ═════════════════════════════════════════════════════════════
  // SHEET PER KATEGORI (gaya gambar 1, header 1 baris tanpa merge)
  // ═════════════════════════════════════════════════════════════
  Future<void> _isiKategori(
    Excel excel, String kategori, String dari, String sampai, String labelPeriode,
  ) async {
    final data = await _repo.laporanPerKategori(
        kategori: kategori, dari: dari, sampai: sampai);

    final sheet = excel[_namaSheet(kategori)];

    // Judul
    _teks(sheet, 0, 0, 'LAPORAN $kategori — $labelPeriode',
        CellStyle(bold: true, fontSize: 13, fontColorHex: _biru));

    // Header (baris index 2)
    const headerRow = 2;
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
      'KODE', 'NAMA SUKU CADANG',
      'QTY\nMASUK', 'HARGA ASTRA', 'HARGA TOTAL',
      'QTY\nKELUAR', 'HARGA JUAL', 'LABA (Rp)', 'JUMLAH MODAL (Rp)',
      'SISA', 'MODAL TIDAK\nBERPUTAR (Rp)',
    ];
    for (int i = 0; i < headers.length; i++) {
      _teks(sheet, i, headerRow, headers[i], headerStyle);
    }

    // Data mulai baris index 3
    int r = headerRow + 1;
    int totHargaTotal = 0, totLaba = 0, totModal = 0, totTdkBerputar = 0;

    for (final item in data) {
      final qtyMasuk   = item['qtyMasuk'] as int;
      final hargaAstra = item['hargaAstra'] as int;
      final qtyKeluar  = item['qtyKeluar'] as int;
      final hargaJual  = item['hargaJual'] as int;

      // Hitung di Dart (sama seperti formula office)
      final hargaTotal   = qtyMasuk * hargaAstra;         // C*D
      final laba         = (hargaJual - hargaAstra) * qtyKeluar; // (G-D)*F
      final jumlahModal  = qtyKeluar * hargaAstra;        // F*D
      final sisa         = qtyMasuk - qtyKeluar;          // C-F
      final tdkBerputar  = sisa * hargaAstra;             // (C-F)*D

      totHargaTotal += hargaTotal;
      totLaba += laba;
      totModal += jumlahModal;
      totTdkBerputar += tdkBerputar;

      // Warna dasar: hijau, tapi qty keluar 0 → pink
      final bg = qtyKeluar == 0 ? _pink : _hijau;

      final sTeks  = CellStyle(backgroundColorHex: bg, fontSize: 10,
          leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());
      final sNum   = CellStyle(backgroundColorHex: bg, fontSize: 10,
          horizontalAlign: HorizontalAlign.Center,
          leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());
      final sRp    = CellStyle(backgroundColorHex: bg, fontSize: 10,
          numberFormat: NumFormat.custom(formatCode: _fmtRp),
          leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());

      _teks(sheet, 0, r, item['kodeScan'] as String, sTeks);
      _teks(sheet, 1, r, item['namaBarang'] as String, sTeks);
      _angka(sheet, 2, r, qtyMasuk, sNum);
      _angka(sheet, 3, r, hargaAstra, sRp);
      _angka(sheet, 4, r, hargaTotal, sRp);
      _angka(sheet, 5, r, qtyKeluar, sNum);
      _angka(sheet, 6, r, hargaJual, sRp);
      _angka(sheet, 7, r, laba, sRp);
      _angka(sheet, 8, r, jumlahModal, sRp);
      _angka(sheet, 9, r, sisa, sNum);
      _angka(sheet, 10, r, tdkBerputar, sRp);
      r++;
    }

    // Baris TOTAL
    final totTeks = CellStyle(backgroundColorHex: _abu, bold: true, fontSize: 10,
        leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());
    final totRp = CellStyle(backgroundColorHex: _abu, bold: true, fontSize: 10,
        numberFormat: NumFormat.custom(formatCode: _fmtRp),
        leftBorder: _bd(), rightBorder: _bd(), topBorder: _bd(), bottomBorder: _bd());
    _teks(sheet, 0, r, 'TOTAL', totTeks);
    _teks(sheet, 1, r, '', totTeks);
    _teks(sheet, 2, r, '', totTeks);
    _teks(sheet, 3, r, '', totTeks);
    _angka(sheet, 4, r, totHargaTotal, totRp);
    _teks(sheet, 5, r, '', totTeks);
    _teks(sheet, 6, r, '', totTeks);
    _angka(sheet, 7, r, totLaba, totRp);
    _angka(sheet, 8, r, totModal, totRp);
    _teks(sheet, 9, r, '', totTeks);
    _angka(sheet, 10, r, totTdkBerputar, totRp);

    // Lebar kolom
    sheet.setColumnWidth(0, 18);
    sheet.setColumnWidth(1, 28);
    sheet.setColumnWidth(2, 9);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 15);
    sheet.setColumnWidth(5, 9);
    sheet.setColumnWidth(6, 14);
    sheet.setColumnWidth(7, 15);
    sheet.setColumnWidth(8, 16);
    sheet.setColumnWidth(9, 8);
    sheet.setColumnWidth(10, 18);
  }
}