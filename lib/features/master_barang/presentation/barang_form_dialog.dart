import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'controller/master_provider.dart';
import '../data/barang_model.dart';

class BarangFormDialog {
  // Tambahkan parameter initialKode di sini
  static Future<void> show(BuildContext context, {String? initialKode}) async {
    final provider = context.read<MasterProvider>();

    // Masukkan initialKode ke controller agar auto-fill
    final kodeCtrl = TextEditingController(text: initialKode ?? '');
    final namaCtrl = TextEditingController();
    final hargaAstraCtrl = TextEditingController();
    final hargaJualCtrl = TextEditingController();
    
    String kategoriDipilih = 'PART';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_box_rounded, color: Color(0xFF01579B)),
                  SizedBox(width: 10),
                  Text('Daftarkan Barang Baru'),
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
                          items: const [
                            DropdownMenuItem(value: 'PART', child: Text('PART')),
                            DropdownMenuItem(value: 'BUSI', child: Text('BUSI')),
                            DropdownMenuItem(value: 'OLI', child: Text('OLI')),
                            DropdownMenuItem(value: 'BRG SLRG', child: Text('BRG SLRG')),
                            DropdownMenuItem(value: 'NON AHM', child: Text('NON AHM')),
                          ],
                          onChanged: (v) => setDialogState(() => kategoriDipilih = v!),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: TextFormField(controller: hargaAstraCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Harga Modal (Rp)', hintText: '0'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(controller: hargaJualCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Harga Jual (Rp)', hintText: '0'))),
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
                      kodeScan: kodeCtrl.text.trim(),
                      namaBarang: namaCtrl.text.trim(),
                      kategori: kategoriDipilih,
                      hargaAstra: int.tryParse(hargaAstraCtrl.text) ?? 0,
                      hargaJual: int.tryParse(hargaJualCtrl.text) ?? 0,
                      stokSisa: 0,
                    );

                    final error = await provider.tambahBarang(barang);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error ?? 'Barang berhasil ditambahkan ke Master'),
                        backgroundColor: error != null ? Colors.red.shade600 : Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                      )
                    );
                  },
                  child: const Text('Simpan Barang'),
                ),
              ],
            );
          },
        );
      }
    );
  }
}