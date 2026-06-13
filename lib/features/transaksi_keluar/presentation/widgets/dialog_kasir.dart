// File: lib/features/transaksi_keluar/presentation/widgets/dialog_kasir.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../master_barang/presentation/controller/master_provider.dart';
import '../../../pelanggan/data/pelanggan_model.dart';
import '../../../pelanggan/presentation/controller/pelanggan_provider.dart';
import '../controller/cart_provider.dart';
import '../controller/kasir_provider.dart';

// ─────────────────────────────────────────────────────────────────
// DIALOG KASIR — popup pembayaran
//
// Cara pakai dari ScanKeluarView:
//
//   final noNota = await DialogKasir.show(context);
//   if (noNota != null) { ... transaksi sukses ... }
//
// Return: no_nota jika sukses, null jika batal/error
// ─────────────────────────────────────────────────────────────────

class DialogKasir {
  static Future<String?> show(BuildContext context) async {
    // Pastikan KasirProvider sudah dimulai dengan total tagihan
    final kasir = context.read<KasirProvider>();
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return null;

    kasir.mulai(cart.totalTagihan);

    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DialogKasirContent(),
    );
  }
}

class _DialogKasirContent extends StatefulWidget {
  const _DialogKasirContent();

  @override
  State<_DialogKasirContent> createState() => _DialogKasirContentState();
}

class _DialogKasirContentState extends State<_DialogKasirContent> {
  final _uangCtrl  = TextEditingController();
  final _uangFocus = FocusNode();
  final _namaCtrl  = TextEditingController();
  final _namaFocus = FocusNode();
  final _hpCtrl    = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  List<Pelanggan> _hasilAutocomplete = [];

  static const Color _merahTua = Color(0xFFB71C1C);
  static const Color _hijauTua = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final kasir = context.read<KasirProvider>();
      
      // Ubah baris ini agar saat pertama kali buka langsung pakai format ribuan
      _uangCtrl.text = _formatRibuan(kasir.uangDiterima); 
      
      // Auto-select agar gampang diganti
      _uangFocus.requestFocus();
      _uangCtrl.selection = TextSelection(
        baseOffset: 0, extentOffset: _uangCtrl.text.length,
      );
    });
  }

  @override
  void dispose() {
    _uangCtrl.dispose();   _uangFocus.dispose();
    _namaCtrl.dispose();   _namaFocus.dispose();
    _hpCtrl.dispose();
    _alamatCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  String _rp(int n) {
    if (n == 0) return 'Rp 0';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _formatRibuan(int n) {
    if (n == 0) return '0';
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.'
    );
  }

  // ── Handlers ─────────────────────────────────────────────────
  void _setUang(int nilai) {
    final kasir = context.read<KasirProvider>();
    kasir.setUangDiterima(nilai);
    _uangCtrl.text = _formatRibuan(nilai); // Gunakan format titik
    _uangCtrl.selection = TextSelection.collapsed(offset: _uangCtrl.text.length);
  }

  void _onUangChanged(String v) {
    // 1. Bersihkan semua titik/karakter selain angka
    final bersih = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (bersih.isEmpty) {
      context.read<KasirProvider>().setUangDiterima(0);
      _uangCtrl.text = '';
      return;
    }

    // 2. Ubah jadi integer
    final n = int.tryParse(bersih);
    if (n != null) {
      context.read<KasirProvider>().setUangDiterima(n);
      
      // 3. Format kembali menjadi ada titiknya
      final formatted = _formatRibuan(n);
      
      // 4. Update TextField dan tahan kursor agar selalu di ujung kanan
      _uangCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _onNamaChanged(String v) {
    context.read<KasirProvider>().setNamaPelanggan(v);
    final pelanggan = context.read<PelangganProvider>();
    setState(() => _hasilAutocomplete = pelanggan.cari(v));
  }

  void _pilihPelanggan(Pelanggan p) {
    final kasir = context.read<KasirProvider>();
    kasir.pilihPelangganDariAutocomplete(
      id: p.id!,
      nama: p.nama,
      noHp: p.noHp,
      alamat: p.alamat,
    );
    _namaCtrl.text = p.nama;
    _hpCtrl.text = p.noHp ?? '';
    _alamatCtrl.text = p.alamat ?? '';
    setState(() => _hasilAutocomplete = []);
  }

  Future<void> _simpan() async {
    final kasir = context.read<KasirProvider>();
    final err = await kasir.simpanNota(
      cartProvider: context.read<CartProvider>(),
      pelangganProvider: context.read<PelangganProvider>(),
      masterProvider: context.read<MasterProvider>(),
    );

    if (!mounted) return;
    if (err == null) {
      // Sukses — return no_nota ke parent
      Navigator.of(context).pop(kasir.lastNoNota);
    }
    // Kalau error, biar dialog tetap terbuka, error ditampilkan di banner
  }

  void _batal() {
    context.read<KasirProvider>().reset();
    Navigator.of(context).pop(null);
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<KasirProvider>(
      builder: (_, KasirProvider kasir, _) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ── HEADER ──
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: kasir.isLunas ? _hijauTua : Colors.orange.shade700,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text('Pembayaran',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Text(
                        kasir.isLunas ? 'LUNAS' : 'HUTANG',
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold,
                          fontSize: 13, letterSpacing: 1,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text('TOTAL TAGIHAN',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
                    Text(
                      _rp(kasir.totalTagihan),
                      style: const TextStyle(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]),
                ),

                // ── BODY ──
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // Field Uang Diterima
                    const Text('Uang Diterima',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _uangCtrl,
                      focusNode: _uangFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: kasir.isLunas ? _hijauTua : Colors.orange.shade700,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: _onUangChanged,
                    ),
                    const SizedBox(height: 8),

                    // Quick buttons
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _quickBtn('PAS', _hijauTua, () => _setUang(kasir.totalTagihan)),
                        const SizedBox(width: 6),
                        _quickBtn('50K', null, () => _setUang(50000)),
                        const SizedBox(width: 6),
                        _quickBtn('100K', null, () => _setUang(100000)),
                        const SizedBox(width: 6),
                        _quickBtn('200K', null, () => _setUang(200000)),
                        const SizedBox(width: 6),
                        _quickBtn('500K', null, () => _setUang(500000)),
                        const SizedBox(width: 6),
                        _quickBtn('+50K', Colors.blue.shade700, () {
                          final baru = kasir.uangDiterima + 50000;
                          _setUang(baru);
                        }),
                        const SizedBox(width: 6),
                        _quickBtn('Bayar 0', Colors.orange.shade700, () => _setUang(0)),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Status banner (kembalian atau hutang)
                    _buildStatusBanner(kasir),

                    // Form pelanggan (muncul saat hutang)
                    if (kasir.isHutang) ...[
                      const SizedBox(height: 14),
                      _buildFormPelanggan(kasir),
                    ],

                    // Catatan (selalu muncul, opsional)
                    const SizedBox(height: 10),
                    TextField(
                      controller: _catatanCtrl,
                      onChanged: (v) => kasir.setCatatan(v),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Catatan (opsional)',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: 'Misal: untuk montir, garansi, dll',
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),

                    // Error banner
                    if (kasir.errorPesan.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(kasir.errorPesan,
                              style: TextStyle(fontSize: 12, color: Colors.red.shade800))),
                        ]),
                      ),
                    ],
                  ]),
                ),

                // ── ACTIONS ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: kasir.isSaving ? null : _batal,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Batal', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: (kasir.isSaving || !kasir.isValid) ? null : _simpan,
                        style: FilledButton.styleFrom(
                          backgroundColor: kasir.isLunas ? _hijauTua : Colors.orange.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: kasir.isSaving
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                kasir.isLunas ? 'SIMPAN NOTA' : 'SIMPAN (HUTANG)',
                                style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ── STATUS BANNER ────────────────────────────────────────────
  Widget _buildStatusBanner(KasirProvider kasir) {
    final bool lunas = kasir.isLunas;
    final Color warna = lunas ? _hijauTua : Colors.orange.shade700;
    final Color bg = lunas ? const Color(0xFFE8F5E9) : Colors.orange.shade50;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: warna.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(lunas ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: warna, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            lunas ? 'PEMBAYARAN LUNAS' : 'PEMBAYARAN KURANG',
            style: TextStyle(color: warna, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          if (lunas) ...[
            Row(children: [
              const Text('Kembalian: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(_rp(kasir.kembalian),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: warna)),
            ]),
          ] else ...[
            Row(children: [
              const Text('Sisa Hutang: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(_rp(kasir.sisaHutang),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: warna)),
            ]),
            const SizedBox(height: 2),
            Text('Pelanggan wajib diisi di bawah',
                style: TextStyle(fontSize: 10.5, color: Colors.orange.shade900)),
          ],
        ])),
      ]),
    );
  }

  // ── FORM PELANGGAN (muncul saat hutang) ──────────────────────
  Widget _buildFormPelanggan(KasirProvider kasir) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.person_outline_rounded, color: Colors.orange.shade800, size: 16),
          const SizedBox(width: 6),
          Text('Data Pelanggan Hutang',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.orange.shade900)),
        ]),
        const SizedBox(height: 10),

        // Nama dengan autocomplete
        TextField(
          controller: _namaCtrl,
          focusNode: _namaFocus,
          onChanged: _onNamaChanged,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nama Pelanggan *',
            labelStyle: const TextStyle(fontSize: 12),
            hintText: 'Ketik 2+ huruf, lihat suggestion',
            hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
            prefixIcon: const Icon(Icons.person_rounded, size: 18),
            suffixIcon: _namaCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () {
                      _namaCtrl.clear();
                      _hpCtrl.clear();
                      _alamatCtrl.clear();
                      kasir.setNamaPelanggan('');
                      kasir.setNoHpPelanggan('');
                      kasir.setAlamatPelanggan('');
                      setState(() => _hasilAutocomplete = []);
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),

        // Autocomplete dropdown
        if (_hasilAutocomplete.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6, offset: const Offset(0, 2),
              )],
            ),
            child: SingleChildScrollView(
              child: Column(children: _hasilAutocomplete.map((p) => InkWell(
                onTap: () => _pilihPelanggan(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.nama,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                      if (p.noHp != null && p.noHp!.isNotEmpty)
                        Text(p.noHp!,
                            style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
                    ])),
                    if (p.punyaHutang)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'Hutang ${_rp(p.totalHutangAktif)}',
                          style: TextStyle(fontSize: 9, color: Colors.red.shade800),
                        ),
                      ),
                  ]),
                ),
              )).toList()),
            ),
          ),
        ],

        const SizedBox(height: 8),

        // No HP
        TextField(
          controller: _hpCtrl,
          onChanged: (v) => kasir.setNoHpPelanggan(v),
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\-\+ ]'))],
          decoration: InputDecoration(
            labelText: 'No. HP',
            labelStyle: const TextStyle(fontSize: 12),
            hintText: '0812-xxxx-xxxx',
            hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
            prefixIcon: const Icon(Icons.phone_rounded, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),

        // Alamat
        TextField(
          controller: _alamatCtrl,
          onChanged: (v) => kasir.setAlamatPelanggan(v),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Alamat (opsional)',
            labelStyle: const TextStyle(fontSize: 12),
            prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ]),
    );
  }

  Widget _quickBtn(String label, Color? warna, VoidCallback onTap) {
    final c = warna ?? Colors.grey.shade700;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w600, color: c,
        )),
      ),
    );
  }
}
