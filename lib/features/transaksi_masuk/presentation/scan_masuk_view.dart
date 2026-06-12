import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'controller/scan_masuk_provider.dart';
import '../../master_barang/presentation/controller/master_provider.dart';
import '../../master_barang/presentation/barang_form_dialog.dart';
import '../data/transaksi_masuk_model.dart';

class ScanMasukView extends StatefulWidget {
  const ScanMasukView({super.key});

  @override
  State<ScanMasukView> createState() => _ScanMasukViewState();
}

class _ScanMasukViewState extends State<ScanMasukView> {
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();

  final _qtyCtrl = TextEditingController(text: '1');
  final _qtyFocus = FocusNode();

  static const _hijauTua  = Color(0xFF1B5E20);
  static const _hijauMuda = Color(0xFFE8F5E9);

  // Variabel lokal untuk menyimpan kode yang tidak ditemukan (karena dihapus dari provider)
  String _kodeTidakTerdaftar = ''; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ScanMasukProvider>();
      final masterProvider = context.read<MasterProvider>();
      await provider.init(masterProvider);
      _fokusKeScan();
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    _qtyCtrl.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  void _fokusKeScan() {
    if (mounted) {
      _scanCtrl.clear();
      FocusScope.of(context).requestFocus(_scanFocus);
    }
  }

  // ── LOGIKA KASIR (Menyesuaikan dengan ScanResult dari Provider) ──
  void _onScanSubmit(String value) async {
    final kode = value.trim().toUpperCase();
    if (kode.isEmpty) {
      _fokusKeScan();
      return;
    }

    final provider = context.read<ScanMasukProvider>();
    final result = provider.prosesScan(kode);

    if (result == ScanResult.accumulated) {
      // Jika scan berulang, perbarui text QTY dan tampilkan snackbar
      _qtyCtrl.text = provider.qty.toString();
      _showSnack('Qty ditambahkan: ${provider.qty} ✓');
    } else if (result == ScanResult.newFound) {
      _qtyCtrl.text = '1';
    } else if (result == ScanResult.switchNeeded) {
      // Ada barang gantung, minta konfirmasi untuk simpan
      await _tampilkanDialogSwitch(provider);
    } else if (result == ScanResult.notFound || result == ScanResult.notFoundWhileActive) {
      setState(() { _kodeTidakTerdaftar = kode; });
      if (result == ScanResult.notFoundWhileActive) {
        _showSnack('Kode "$kode" tidak terdaftar!', isError: true);
      }
    }
    
    _fokusKeScan();
  }

  Future<void> _tampilkanDialogSwitch(ScanMasukProvider provider) async {
    final barangAktif = provider.barangAktif;
    final barangPending = provider.barangPending;
    final qtySaatIni = _qtyCtrl.text;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Colors.blue),
            SizedBox(width: 10),
            Text('Simpan & Ganti Barang?'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
            children: [
              const TextSpan(text: 'Anda men-scan barang baru:\n'),
              TextSpan(text: '• ${barangPending?.namaBarang}\n\n', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const TextSpan(text: 'Simpan barang yang sedang aktif ini ke riwayat?\n'),
              TextSpan(text: '• ${barangAktif?.namaBarang} ', style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: '($qtySaatIni pcs)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batalkan Scan Baru'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Simpan & Lanjut'),
          ),
        ],
      ),
    );

    if (ok == true) {
      provider.setQty(int.tryParse(_qtyCtrl.text) ?? 1);
      final error = await provider.konfirmasiSwitch();
      if (error == null) {
        _qtyCtrl.text = '1';
        _showSnack('Disimpan & dialihkan otomatis ✓');
      } else {
        _showSnack(error, isError: true);
      }
    } else {
      provider.batalSwitch();
    }
    
    // Pastikan fokus kembali ke scanner agar admin bisa langsung tembak lagi
    _fokusKeScan();
  }

  Future<void> _simpan() async {
    final provider = context.read<ScanMasukProvider>();
    provider.setQty(int.tryParse(_qtyCtrl.text) ?? 1);

    final errorMsg = await provider.simpanTransaksi();
    if (!mounted) return;

    if (errorMsg == null) {
      _showSnack('Barang masuk disimpan ✓');
      setState(() => _qtyCtrl.text = '1');
    } else {
      _showSnack(errorMsg, isError: true);
    }
    _fokusKeScan();
  }

  void _showSnack(String pesan, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(pesan),
      backgroundColor: isError ? Colors.red.shade600 : _hijauTua,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1500),
    ));
  }

  String _formatRupiah(int angka) {
    if (angka == 0) return '-';
    return 'Rp ${angka.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _fokusKeScan,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildAreaScan(),
                          const SizedBox(height: 16),
                          _buildPreviewBarang(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(child: _buildRiwayatSesi()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _hijauMuda, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.archive_rounded, color: _hijauTua, size: 26),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barang Masuk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('Scan atau ketik kode barang yang datang', style: TextStyle(color: Colors.grey)),
          ],
        ),
        const Spacer(),
        Consumer<ScanMasukProvider>(
          builder: (_, p, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: _hijauMuda, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.add_box_rounded, color: _hijauTua, size: 18),
                const SizedBox(width: 6),
                Text('${p.totalItemSesi} item masuk hari ini', style: const TextStyle(color: _hijauTua, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaScan() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hijauTua.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_scanner_rounded, color: _hijauTua, size: 20),
              const SizedBox(width: 8),
              const Text('Scan Barcode / Input Manual', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              Consumer<ScanMasukProvider>(
                builder: (_, p, __) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: p.cacheLoaded ? Colors.green : Colors.orange, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 6),
              Consumer<ScanMasukProvider>(
                builder: (_, p, __) => Text(p.cacheLoaded ? 'Siap scan' : 'Memuat...', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _scanCtrl,
            focusNode: _scanFocus,
            onSubmitted: _onScanSubmit,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 18, fontFamily: 'monospace', letterSpacing: 2),
            decoration: InputDecoration(
              hintText: 'Arahkan scanner ke barcode...',
              hintStyle: const TextStyle(fontSize: 14, letterSpacing: 0, color: Colors.grey),
              prefixIcon: const Icon(Icons.qr_code_2_rounded, color: _hijauTua),
              suffixIcon: IconButton(
                tooltip: 'Proses kode',
                icon: const Icon(Icons.send_rounded, color: _hijauTua),
                onPressed: () => _onScanSubmit(_scanCtrl.text),
              ),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _hijauTua, width: 1)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _hijauTua, width: 2)),
              filled: true, fillColor: _hijauMuda,
            ),
          ),
          const SizedBox(height: 10),
          Text('Tekan Enter setelah scan atau ketik manual. Klik area manapun untuk kembali ke mode scan.', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildPreviewBarang() {
    return Consumer<ScanMasukProvider>(
      builder: (_, provider, __) {
        if (provider.status == ScanStatus.notFound) {
          return _buildKartuTidakTerdaftar(provider);
        }

        if (provider.status == ScanStatus.found || provider.status == ScanStatus.saving || provider.status == ScanStatus.pendingSwitch) {
          final b = provider.barangAktif!;
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _hijauTua.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _hijauMuda, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.inventory_2_rounded, color: _hijauTua, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.namaBarang, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(b.kodeScan, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20)),
                      child: Text(b.kategori, style: const TextStyle(fontSize: 11, color: Color(0xFF01579B))),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    _buildInfoChip('Harga Modal', _formatRupiah(b.hargaAstra)),
                    const SizedBox(width: 12),
                    _buildInfoChip('Stok Saat Ini', '${b.stokSisa} pcs'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Jumlah Masuk:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 16),
                    _buildQtyButton(Icons.remove_rounded, () {
                      final v = int.tryParse(_qtyCtrl.text) ?? 1;
                      if (v > 1) {
                        provider.setQty(v - 1);
                        _qtyCtrl.text = '${v - 1}';
                      }
                      _fokusKeScan(); 
                    }),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _qtyCtrl,
                        focusNode: _qtyFocus,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _hijauTua, width: 2)),
                        ),
                        onChanged: (val) {
                           // Update provider jika user mengetik manual
                           provider.setQty(int.tryParse(val) ?? 1);
                        },
                        onSubmitted: (_) => _simpan(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildQtyButton(Icons.add_rounded, () {
                      final v = int.tryParse(_qtyCtrl.text) ?? 1;
                      provider.setQty(v + 1);
                      _qtyCtrl.text = '${v + 1}';
                      _fokusKeScan();
                    }),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: provider.status == ScanStatus.saving ? null : _simpan,
                      icon: provider.status == ScanStatus.saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded),
                      label: const Text('Simpan'),
                      style: FilledButton.styleFrom(backgroundColor: _hijauTua, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: _hijauMuda.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: _hijauTua.withOpacity(0.15))),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.qr_code_2_rounded, size: 48, color: _hijauTua.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text('Scan barcode atau ketik kode di atas', style: TextStyle(color: _hijauTua.withOpacity(0.6), fontSize: 14)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKartuTidakTerdaftar(ScanMasukProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade300, width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 22),
              const SizedBox(width: 10),
              const Text('Barang Belum Terdaftar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(provider.errorPesan, style: TextStyle(color: Colors.orange.shade800, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () async {
                  // Menggunakan _kodeTidakTerdaftar yang ditangkap sesaat sebelum layar ini muncul
                  await BarangFormDialog.show(context, initialKode: _kodeTidakTerdaftar);
                  provider.reset();
                  _fokusKeScan();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Daftarkan Barang Ini'),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  provider.reset();
                  _fokusKeScan();
                },
                child: const Text('Lewati'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayatSesi() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer<ScanMasukProvider>(
            builder: (_, p, __) => Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Riwayat Hari Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _hijauMuda, borderRadius: BorderRadius.circular(20)),
                    child: Text('Total Modal: ${_formatRupiah(p.totalModalSesi)}', style: const TextStyle(fontSize: 12, color: _hijauTua)),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<ScanMasukProvider>(
              builder: (_, provider, __) {
                if (provider.riwayatSesi.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text('Belum ada scan hari ini', style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: provider.riwayatSesi.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (ctx, i) {
                    final t = provider.riwayatSesi[i];
                    return _buildRiwayatRow(t, provider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayatRow(TransaksiMasuk t, ScanMasukProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _hijauMuda, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.inventory_2_rounded, color: _hijauTua, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.namaBarang.isEmpty ? t.kodeScan : t.namaBarang, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis),
                Text('${t.kodeScan} • ${t.jam}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _hijauMuda, borderRadius: BorderRadius.circular(20)),
            child: Text('+${t.qty}', style: const TextStyle(fontWeight: FontWeight.bold, color: _hijauTua, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Batalkan & kembalikan stok',
            icon: Icon(Icons.undo_rounded, size: 18, color: Colors.red.shade400),
            onPressed: () => _konfirmasiHapusRiwayat(t, provider),
          ),
        ],
      ),
    );
  }

  Future<void> _konfirmasiHapusRiwayat(TransaksiMasuk t, ScanMasukProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan item ini?'),
        content: Text('${t.qty}x ${t.namaBarang.isEmpty ? t.kodeScan : t.namaBarang} akan dibatalkan dan stok dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600), onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Batalkan')),
        ],
      ),
    );

    if (ok == true) {
      final errorMsg = await provider.hapusRiwayat(t);
      if (!mounted) return;
      if (errorMsg == null) {
        _showSnack('Item dibatalkan, stok dikembalikan');
      } else {
        _showSnack(errorMsg, isError: true);
      }
    }
    _fokusKeScan();
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF3F8FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: _hijauTua),
      ),
    );
  }
}