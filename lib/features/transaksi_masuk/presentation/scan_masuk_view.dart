import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scan_go/features/master_barang/presentation/barang_form_dialog.dart';
import 'package:scan_go/features/transaksi_masuk/presentation/controller/scan_masuk_provider.dart';
import '../../master_barang/presentation/controller/master_provider.dart';
import '../../master_barang/data/barang_model.dart';
import '../data/transaksi_masuk_model.dart';

class ScanMasukView extends StatefulWidget {
  const ScanMasukView({super.key});

  @override
  State<ScanMasukView> createState() => _ScanMasukViewState();
}

class _ScanMasukViewState extends State<ScanMasukView> {
  // ── Controllers & Focus ──────────────────────────────────────
  final _scanCtrl   = TextEditingController();
  final _scanFocus  = FocusNode();
  final _qtyCtrl    = TextEditingController(text: '1');
  final _qtyFocus   = FocusNode();
  final _namaCtrl   = TextEditingController();
  final _namaFocus  = FocusNode();

  // ── State lokal ──────────────────────────────────────────────
  String _mode = 'scan'; // Hanya 2 mode sekarang: 'scan' | 'nama'
  String _lastScanCode = '';
  DateTime _lastScanTime = DateTime(2000);

  static const Color _hijauTua  = Color(0xFF1B5E20);
  static const Color _hijauMuda = Color(0xFFE8F5E9);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ScanMasukProvider>()
        .init(context.read<MasterProvider>())
        .then((_) { if (mounted) _fokusKeInput(); });
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose(); _scanFocus.dispose();
    _qtyCtrl.dispose();  _qtyFocus.dispose();
    _namaCtrl.dispose(); _namaFocus.dispose();
    super.dispose();
  }

  // Fokus ke field input sesuai mode aktif (Fokus Abadi Scanner)
  void _fokusKeInput() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_mode == 'scan') {
        _scanCtrl.clear();
        _scanFocus.requestFocus();
      } else if (_mode == 'nama') {
        _namaFocus.requestFocus();
      }
    });
  }

  void _syncQtyField(int qty) {
    final teks = qty <= 0 ? '' : '$qty';
    if (_qtyCtrl.text != teks) {
      _qtyCtrl.text = teks;
      _qtyCtrl.selection = TextSelection.collapsed(offset: teks.length);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HANDLER SCAN — entry point dari scanner fisik
  // ─────────────────────────────────────────────────────────────
  void _onScanSubmit(String value) {
    final kode = value.trim().toUpperCase();
    if (kode.isEmpty) { _fokusKeInput(); return; }

    // Debounce dipercepat jadi 400ms agar scan ganda super cepat tetap terbaca
    final now = DateTime.now();
    if (kode == _lastScanCode &&
        now.difference(_lastScanTime).inMilliseconds < 400) {
      _scanCtrl.clear();
      _fokusKeInput();
      return;
    }
    _lastScanCode = kode;
    _lastScanTime = now;

    final provider = context.read<ScanMasukProvider>();
    final result = provider.prosesScan(kode);
    _scanCtrl.clear();

    _handleScanResult(result, provider, kode);
  }

  // Handler untuk hasil scan/pilih — terpusat
  void _handleScanResult(ScanResult result, ScanMasukProvider provider, String kode) {
    switch (result) {
      case ScanResult.newFound:
        _syncQtyField(1);
        _fokusKeInput(); // Kunci fokus tetap di Scanner
      case ScanResult.accumulated:
        _syncQtyField(provider.qty);
        _showSnack('${provider.barangAktif?.namaBarang ?? "Barang"} — qty: ${provider.qty}', durasi: 1);
        _fokusKeInput(); // Kunci fokus tetap di Scanner
      case ScanResult.switchNeeded:
        _showDialogSwitch(provider);
      case ScanResult.notFoundWhileActive:
        _showSnack('Kode "$kode" tidak terdaftar. Input aktif tetap.', isError: true);
        _fokusKeInput();
      case ScanResult.notFound:
        _fokusKeInput();
      case ScanResult.ignored:
        _fokusKeInput();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DIALOG SWITCH BARANG
  // ─────────────────────────────────────────────────────────────
  Future<void> _showDialogSwitch(ScanMasukProvider provider) async {
    final Barang? aktif   = provider.barangAktif;
    final Barang? pending = provider.barangPending;

    if (aktif == null || pending == null) {
      provider.batalSwitch();
      _fokusKeInput();
      return;
    }

    final int? qtyField = int.tryParse(_qtyCtrl.text.trim());
    if (qtyField != null && qtyField != provider.qty) {
      provider.setQty(qtyField);
    }

    final bool? pilihan = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Ganti Barang?', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _switchCard('Sedang diinput (qty ${provider.qty})',
              aktif.namaBarang, aktif.kodeScan, Colors.blue.shade50, Colors.blue.shade700),
            const SizedBox(height: 8),
            const Icon(Icons.arrow_downward_rounded, color: Colors.grey, size: 18),
            const SizedBox(height: 8),
            _switchCard('Baru discan',
              pending.namaBarang, pending.kodeScan, Colors.orange.shade50, Colors.orange.shade700),
            const SizedBox(height: 12),
            const Text(
              'Pilih "Simpan & Ganti" → barang aktif tersimpan, lanjut ke yang baru.\n'
              'Pilih "Abaikan" → kembali ke barang aktif, scan baru diabaikan.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abaikan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _hijauTua),
            child: const Text('Simpan & Ganti'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (pilihan == true) {
      final err = await provider.konfirmasiSwitch();
      if (!mounted) return;
      if (err != null) {
        _showSnack(err, isError: true);
      } else {
        final namaBaru = provider.barangAktif?.namaBarang;
        if (namaBaru != null) {
          _syncQtyField(provider.qty);
          _showSnack('Tersimpan. Sekarang: $namaBaru');
        } else {
          provider.reset();
        }
      }
    } else {
      provider.batalSwitch();
    }
    
    _fokusKeInput(); // Pastikan fokus kembali ke scanner
  }

  // ─────────────────────────────────────────────────────────────
  // SIMPAN
  // ─────────────────────────────────────────────────────────────
  Future<void> _simpan() async {
    final provider = context.read<ScanMasukProvider>();

    final int? qtyField = int.tryParse(_qtyCtrl.text.trim());
    if (qtyField != null) provider.setQty(qtyField);

    if (provider.qty <= 0) {
      _showSnack('Jumlah harus lebih dari 0.', isError: true);
      return;
    }

    final String? err = await provider.simpanTransaksi();
    if (!mounted) return;
    if (err == null) {
      _syncQtyField(0);
      _showSnack('Tersimpan ✓');
    } else {
      _showSnack(err, isError: true);
    }
    _fokusKeInput();
  }

  void _showSnack(String pesan, {bool isError = false, int durasi = 2}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(pesan),
        backgroundColor: isError ? Colors.red.shade600 : _hijauTua,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: durasi),
      ));
  }

  String _rp(int n) {
    if (n == 0) return '-';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { _fokusKeInput(); },
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildModeToggle(),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isSempit = constraints.maxWidth < 800;
                if (isSempit) {
                  return Column(children: [
                    _buildInputArea(),
                    const SizedBox(height: 12),
                    Expanded(child: _buildPreviewBarang()),
                  ]);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 440,
                    child: Column(children: [
                      _buildInputArea(),
                      const SizedBox(height: 12),
                      Expanded(child: _buildPreviewBarang()),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildRiwayatSesi()),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Wrap(
      spacing: 14, runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _hijauMuda, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.point_of_sale_rounded, color: _hijauTua, size: 22),
        ),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Barang Masuk', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          Text('Scan barcode, ketik kode, atau cari nama',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        Consumer<ScanMasukProvider>(
          builder: (_, ScanMasukProvider p, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _hijauMuda, borderRadius: BorderRadius.circular(20)),
            child: Text(
              '${p.totalItemSesi} item • ${_rp(p.totalModalSesi)}',
              style: const TextStyle(color: _hijauTua, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ── MODE TOGGLE (Merger Scan & Kode + Auto Clear) ────────────
  Widget _buildModeToggle() {
    return Wrap(spacing: 6, runSpacing: 6, children: [
      _modeBtn('scan', Icons.qr_code_scanner_rounded, 'Scan / Input Kode'),
      _modeBtn('nama', Icons.search_rounded, 'Cari Nama'),
    ]);
  }

  Widget _modeBtn(String mode, IconData icon, String label) {
    final bool aktif = _mode == mode;
    return GestureDetector(
      onTap: () {
        // Otomatis kosongkan field saat pindah mode
        _scanCtrl.clear();
        _namaCtrl.clear();
        setState(() => _mode = mode);
        _fokusKeInput();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: aktif ? _hijauTua : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: aktif ? _hijauTua : Colors.grey.shade300,
            width: aktif ? 0 : 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: aktif ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            fontSize: 12,
            fontWeight: aktif ? FontWeight.w600 : FontWeight.normal,
            color: aktif ? Colors.white : Colors.grey.shade700,
          )),
        ]),
      ),
    );
  }

  // ── INPUT AREA ───────────────────────────────────────────────
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hijauTua.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Text(
              _mode == 'scan' ? 'Scan Barcode / Input Kode Manual' : 'Cari Nama Barang',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Consumer<ScanMasukProvider>(
            builder: (_, ScanMasukProvider p, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.isLoading ? Colors.orange : p.cacheLoaded ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 4),
              Text(p.isLoading ? 'Memuat...' : p.cacheLoaded ? 'Siap' : 'Error',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),

        if (_mode == 'scan') _AutocompleteWidget(
          ctrl: _scanCtrl, focus: _scanFocus,
          hintText: 'Tembakkan scanner atau ketik kode...',
          prefixIcon: Icons.qr_code_scanner_rounded,
          isKode: true,
          allowedFormatter: FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-\s]')),
          onSubmit: (v) {
            _onScanSubmit(v);
          },
          onPilih: (Barang b) {
            _scanCtrl.clear();
            final p = context.read<ScanMasukProvider>();
            final r = p.pilihBarang(b);
            _handleScanResult(r, p, b.kodeScan);
          },
        ),

        if (_mode == 'nama') _AutocompleteWidget(
          ctrl: _namaCtrl, focus: _namaFocus,
          hintText: 'Ketik nama barang (min 2 huruf)...',
          prefixIcon: Icons.search_rounded,
          isKode: false,
          allowedFormatter: null,
          onSubmit: (v) {
            final p = context.read<ScanMasukProvider>();
            final hasil = p.cariByNama(v);
            if (hasil.length == 1) {
              _namaCtrl.clear();
              final r = p.pilihBarang(hasil.first);
              _handleScanResult(r, p, hasil.first.kodeScan);
            } else if (hasil.isEmpty) {
              _showSnack('Tidak ditemukan "$v"', isError: true);
            }
          },
          onPilih: (Barang b) {
            _namaCtrl.clear();
            final p = context.read<ScanMasukProvider>();
            final r = p.pilihBarang(b);
            _handleScanResult(r, p, b.kodeScan);
          },
        ),

        const SizedBox(height: 6),
        Text(
          _mode == 'scan' ? 'Pilih saran atau tekan Enter setelah ketik. Scan ganda qty otomatis +1.'
            : 'Pilih dari saran nama barang.',
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
        ),
      ]),
    );
  }

  // ── PREVIEW BARANG AKTIF ─────────────────────────────────────
  Widget _buildPreviewBarang() {
    return Consumer<ScanMasukProvider>(
      builder: (_, ScanMasukProvider p, _) {
        if (p.status == ScanStatus.notFound) return _buildKartuNotFound(p);
        if (p.status == ScanStatus.error) return _buildKartuError(p);
        if (p.status == ScanStatus.idle) return _buildKartuIdle();
        
        final Barang? b = p.barangAktif;
        if (b == null) return _buildKartuIdle();
        
        return _buildKartuBarang(p, b);
      },
    );
  }

  Widget _buildKartuIdle() => Container(
    padding: const EdgeInsets.all(20),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _hijauMuda.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _hijauTua.withValues(alpha: 0.1)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.qr_code_2_rounded,
          color: _hijauTua.withValues(alpha: 0.3), size: 38),
      const SizedBox(height: 8),
      Text('Siap menerima input',
          style: TextStyle(color: _hijauTua.withValues(alpha: 0.5), fontSize: 13)),
    ]),
  );

  Widget _buildKartuError(ScanMasukProvider p) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.red.shade200, width: 1.5),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
        const SizedBox(width: 6),
        Text('Terjadi Kesalahan',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800, fontSize: 13)),
      ]),
      const SizedBox(height: 6),
      Text(p.errorPesan, style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () { p.reset(); _fokusKeInput(); },
        child: const Text('Tutup & Coba Lagi', style: TextStyle(fontSize: 12)),
      ),
    ]),
  );

  Widget _buildKartuNotFound(ScanMasukProvider p) {
    final Match? m = RegExp(r'"([^"]+)"').firstMatch(p.errorPesan);
    final String kode = m?.group(1) ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.help_outline_rounded, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text('Barang Belum Terdaftar',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 13))),
        ]),
        const SizedBox(height: 4),
        Text(p.errorPesan, style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          FilledButton(
            onPressed: () async {
              p.reset();
              await BarangFormDialog.show(context, initialKode: kode);
              if (!mounted) return;
              await p.refreshCache(context.read<MasterProvider>());
              _fokusKeInput();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
            child: const Text('Daftarkan', style: TextStyle(fontSize: 12)),
          ),
          OutlinedButton(
            onPressed: () { p.reset(); _fokusKeInput(); },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            ),
            child: const Text('Lewati', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ]),
    );
  }

  // ── KARTU BARANG ─────────────────────────────
  Widget _buildKartuBarang(ScanMasukProvider p, Barang b) {
    final bool isSaving  = p.status == ScanStatus.saving;
    final bool isPending = p.status == ScanStatus.pendingSwitch;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncQtyField(p.qty);
    });

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPending ? Colors.orange.withValues(alpha: 0.6) : _hijauTua.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.namaBarang,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis, maxLines: 2),
                const SizedBox(height: 2),
                Text(b.kodeScan,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey)),
              ]),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20)),
              child: Text(b.kategori, style: const TextStyle(fontSize: 10, color: Color(0xFF01579B))),
            ),
          ]),

          if (isPending && p.barangPending != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    'Scan baru: ${p.barangPending!.namaBarang}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () { p.batalSwitch(); _fokusKeInput(); },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6), side: BorderSide(color: Colors.grey.shade300)),
                      child: Text('Abaikan', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _showDialogSwitch(p),
                      style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700, padding: const EdgeInsets.symmetric(vertical: 6)),
                      child: const Text('Simpan & Ganti', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ]),
              ]),
            ),
          ],

          const SizedBox(height: 10),

          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip('Modal', _rp(b.hargaAstra)),
            _chip('Stok', '${b.stokSisa}',
              warna: b.stokSisa == 0 ? Colors.red.shade700 : b.stokSisa < 5 ? Colors.orange.shade700 : null),
            _chip('Total', _rp(p.qty * b.hargaAstra), warna: _hijauTua),
          ]),

          const Divider(height: 18),

          const Text('Jumlah Masuk:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _qtyBtn('−', () { if (p.qty > 1) { p.setQty(p.qty - 1); _syncQtyField(p.qty); } _fokusKeInput(); }),
              const SizedBox(width: 5),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _qtyCtrl,
                  focusNode: _qtyFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _hijauTua, width: 2)),
                  ),
                  onChanged: (v) { final int? n = int.tryParse(v); if (n != null) p.setQty(n); },
                  onSubmitted: (_) => _simpan(), // Bisa simpan pakai Enter jika di-klik manual
                ),
              ),
              const SizedBox(width: 5),
              _qtyBtn('+', () { p.setQty(p.qty + 1); _syncQtyField(p.qty); _fokusKeInput(); }),
              const SizedBox(width: 10),
              _kontrolBtn(icon: Icons.refresh_rounded, label: 'Reset', color: Colors.blue.shade600, onTap: () { p.setQty(1); _syncQtyField(1); _fokusKeInput(); }),
              const SizedBox(width: 6),
              _kontrolBtn(icon: Icons.backspace_outlined, label: 'Kosongkan', color: Colors.grey.shade600, onTap: () { p.kosongkanQty(); _syncQtyField(0); _qtyFocus.requestFocus(); }),
            ]),
          ),

          const SizedBox(height: 10),

          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: (isSaving || isPending) ? null : _simpan,
                style: FilledButton.styleFrom(backgroundColor: _hijauTua, padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: isSaving ? null : () { p.reset(); _syncQtyField(0); _fokusKeInput(); },
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Batal', style: TextStyle(fontSize: 13)),
            ),
          ]),

          if (b.stokSisa == 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orange.shade200)),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 14),
                const SizedBox(width: 5),
                Expanded(child: Text('Stok awal 0 — akan terisi setelah disimpan.', style: TextStyle(fontSize: 10.5, color: Colors.orange.shade800))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  // ── RIWAYAT SESI ─────────────────────────────────────────────
  Widget _buildRiwayatSesi() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        Consumer<ScanMasukProvider>(
          builder: (_, ScanMasukProvider p, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              const Text('Riwayat Hari Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Spacer(),
              Text('${p.totalItemSesi} item', style: const TextStyle(fontSize: 11, color: _hijauTua)),
            ]),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Consumer<ScanMasukProvider>(
            builder: (_, ScanMasukProvider p, _) {
              if (p.riwayatSesi.isEmpty) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.history_rounded, color: Colors.grey.shade300, size: 36),
                    const SizedBox(height: 6),
                    Text('Belum ada transaksi hari ini', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  ]),
                ));
              }
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 6),
                itemCount: p.riwayatSesi.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, int i) => _riwayatRow(p.riwayatSesi[i], p),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _riwayatRow(TransaksiMasuk t, ScanMasukProvider p) {
    final String nama = t.namaBarang.isEmpty ? t.kodeScan : t.namaBarang;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nama, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
          Text('${t.kodeScan} • ${t.jam}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: _hijauMuda, borderRadius: BorderRadius.circular(20)),
          child: Text('+${t.qty}', style: const TextStyle(fontWeight: FontWeight.bold, color: _hijauTua, fontSize: 11)),
        ),
        SizedBox(
          width: 28, height: 28,
          child: IconButton(
            tooltip: 'Batalkan & kembalikan stok',
            padding: EdgeInsets.zero,
            icon: Icon(Icons.undo_rounded, size: 14, color: Colors.red.shade400),
            onPressed: () => _konfirmasiHapus(t, p),
          ),
        ),
      ]),
    );
  }

  Future<void> _konfirmasiHapus(TransaksiMasuk t, ScanMasukProvider p) async {
    final String nama = t.namaBarang.isEmpty ? t.kodeScan : t.namaBarang;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Batalkan item ini?'),
        content: Text('${t.qty}x $nama akan dihapus, stok dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600), onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Batalkan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final String? err = await p.hapusRiwayat(t);
    if (!mounted) return;
    _showSnack(err ?? 'Dibatalkan, stok dikembalikan.', isError: err != null);
    _fokusKeInput();
  }

  // ── HELPERS UI ───────────────────────────────────────────────
  Widget _chip(String label, String value, {Color? warna}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xFFF6F9FC), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
      const SizedBox(height: 1),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: warna ?? Colors.black87)),
    ]),
  );

  Widget _qtyBtn(String label, VoidCallback onTap) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(6),
    child: Container(
      width: 30, height: 30, alignment: Alignment.center,
      decoration: BoxDecoration(border: Border.all(color: _hijauTua.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(6), color: _hijauMuda.withValues(alpha: 0.3)),
      child: Text(label, style: const TextStyle(fontSize: 18, color: _hijauTua, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _kontrolBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color), const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ]),
    ),
  );

  Widget _switchCard(String label, String nama, String kode, Color bg, Color fg) => Container(
    width: double.infinity, padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.7))),
      Text(nama, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: fg), overflow: TextOverflow.ellipsis),
      Text(kode, style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.6), fontFamily: 'monospace')),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
// WIDGET AUTOCOMPLETE (Digabung dengan Mode Scan)
// ─────────────────────────────────────────────────────────────────
class _AutocompleteWidget extends StatefulWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final String hintText;
  final IconData prefixIcon;
  final bool isKode; 
  final TextInputFormatter? allowedFormatter;
  final Function(String) onSubmit;
  final Function(Barang) onPilih;

  const _AutocompleteWidget({
    required this.ctrl,
    required this.focus,
    required this.hintText,
    required this.prefixIcon,
    required this.isKode,
    required this.allowedFormatter,
    required this.onSubmit,
    required this.onPilih,
  });

  @override
  State<_AutocompleteWidget> createState() => _AutocompleteWidgetState();
}

class _AutocompleteWidgetState extends State<_AutocompleteWidget> {
  List<Barang> _hasil = [];

  void _cari(String kw) {
    if (kw.length < 2) {
      if (_hasil.isNotEmpty) setState(() => _hasil = []);
      return;
    }
    final provider = context.read<ScanMasukProvider>();
    final List<Barang> result = widget.isKode ? provider.cariByKode(kw) : provider.cariByNama(kw);
    setState(() => _hasil = result);
  }

  void _clear() {
    widget.ctrl.clear();
    setState(() => _hasil = []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: widget.ctrl,
        focusNode: widget.focus,
        onChanged: _cari,
        onSubmitted: (v) {
          widget.onSubmit(v.trim());
          setState(() => _hasil = []);
        },
        inputFormatters: widget.allowedFormatter != null ? [widget.allowedFormatter!] : null,
        textCapitalization: widget.isKode ? TextCapitalization.characters : TextCapitalization.words,
        style: TextStyle(fontSize: 14, fontFamily: widget.isKode ? 'monospace' : null, letterSpacing: widget.isKode ? 1 : 0),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(fontSize: 12, letterSpacing: 0, color: Colors.grey),
          prefixIcon: Icon(widget.prefixIcon, color: const Color(0xFF01579B), size: 19),
          suffix: widget.ctrl.text.isNotEmpty
              ? SizedBox(width: 28, height: 28, child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.clear_rounded, size: 16), onPressed: _clear))
              : null,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.blue.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF01579B), width: 2)),
          filled: true, fillColor: const Color(0xFFE3F2FD).withValues(alpha: 0.4),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
      if (_hasil.isNotEmpty) ...[
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 3))],
          ),
          child: SingleChildScrollView(
            child: Column(
              children: _hasil.map((Barang b) => InkWell(
                onTap: () { widget.onPilih(b); setState(() => _hasil = []); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.isKode ? b.kodeScan : b.namaBarang, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, fontFamily: widget.isKode ? 'monospace' : null), overflow: TextOverflow.ellipsis),
                      Text(widget.isKode ? b.namaBarang : b.kodeScan, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: widget.isKode ? null : 'monospace'), overflow: TextOverflow.ellipsis),
                    ])),
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)), child: Text(b.kategori, style: const TextStyle(fontSize: 9, color: Color(0xFF01579B)))),
                    const SizedBox(width: 6),
                    Text('${b.stokSisa}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: b.stokSisa == 0 ? Colors.red.shade600 : b.stokSisa < 5 ? Colors.orange.shade700 : Colors.grey.shade700)),
                  ]),
                ),
              )).toList(),
            ),
          ),
        ),
      ],
    ]);
  }
}