import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'controller/master_provider.dart';
import '../data/barang_model.dart';

class BarangFormDialog {
  // Tambahkan parameter barangEdit untuk mode Edit
  static Future<void> show(BuildContext context, {String? initialKode, Barang? barangEdit}) async {
    final provider = context.read<MasterProvider>();
    final isEdit = barangEdit != null;

    // Helper untuk mengubah angka integer dari DB menjadi format titik di awal load
    String formatRibuanAwal(int n) {
      if (n == 0) return '';
      return n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    }

    final kodeCtrl = TextEditingController(text: barangEdit?.kodeScan ?? initialKode ?? '');
    final namaCtrl = TextEditingController(text: barangEdit?.namaBarang ?? '');
    final hargaAstraCtrl = TextEditingController(text: isEdit ? formatRibuanAwal(barangEdit.hargaAstra) : '');
    final hargaJualCtrl = TextEditingController(text: isEdit ? formatRibuanAwal(barangEdit.hargaJual) : '');
    
    final kategoriValid = ['PART', 'BUSI', 'OLI', 'BRG SLRG', 'NON AHM'];
    String kategoriDipilih = barangEdit?.kategori ?? 'PART';
    if (!kategoriValid.contains(kategoriDipilih)) kategoriDipilih = 'PART';

    final formKey = GlobalKey<FormState>();

    // Fungsi Pintar: Pembuat Titik Otomatis saat mengetik
    void formatRibuan(TextEditingController ctrl, String v) {
      final bersih = v.replaceAll(RegExp(r'[^0-9]'), '');
      if (bersih.isEmpty) {
        ctrl.text = '';
        return;
      }
      final n = int.parse(bersih);
      final formatted = n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
      ctrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(isEdit ? Icons.edit_rounded : Icons.add_box_rounded, color: const Color(0xFF01579B)),
                  const SizedBox(width: 10),
                  Text(isEdit ? 'Edit Barang' : 'Daftarkan Barang Baru'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: kodeCtrl,
                          decoration: const InputDecoration(labelText: 'Kode Scan *', hintText: 'Contoh: 06141-GN5-506'),
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
                            Expanded(
                              child: TextFormField(
                                controller: hargaAstraCtrl, 
                                keyboardType: TextInputType.number, 
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))], 
                                onChanged: (v) => formatRibuan(hargaAstraCtrl, v),
                                decoration: const InputDecoration(labelText: 'Harga Modal (Rp)', hintText: '0', prefixText: 'Rp '),
                              )
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: hargaJualCtrl, 
                                keyboardType: TextInputType.number, 
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))], 
                                onChanged: (v) => formatRibuan(hargaJualCtrl, v),
                                decoration: const InputDecoration(labelText: 'Harga Jual (Rp)', hintText: '0', prefixText: 'Rp '),
                              )
                            ),
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
                    
                    final hargaAstraBersih = hargaAstraCtrl.text.replaceAll('.', '');
                    final hargaJualBersih = hargaJualCtrl.text.replaceAll('.', '');

                    final barangForm = Barang(
                      kodeScan: kodeCtrl.text.trim(),
                      namaBarang: namaCtrl.text.trim(),
                      kategori: kategoriDipilih,
                      hargaAstra: int.tryParse(hargaAstraBersih) ?? 0,
                      hargaJual: int.tryParse(hargaJualBersih) ?? 0,
                      stokSisa: barangEdit?.stokSisa ?? 0, // Pertahankan stok lama jika mode edit
                    );

                    // Panggil fungsi Provider sesuai mode (Edit / Tambah)
                    String? error = isEdit 
                        ? await provider.editBarang(barangForm, barangEdit.kodeScan) 
                        : await provider.tambahBarang(barangForm);

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error ?? (isEdit ? 'Perubahan barang disimpan' : 'Barang ditambahkan ke Master')),
                        backgroundColor: error != null ? Colors.red.shade600 : Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                      )
                    );
                  },
                  child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan Barang'),
                ),
              ],
            );
          },
        );
      }
    );
  }
}