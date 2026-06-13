// File: lib/features/transaksi_keluar/presentation/widgets/input_area_keluar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../master_barang/data/barang_model.dart';
import '../controller/cart_provider.dart';

// ─────────────────────────────────────────────────────────────────
// INPUT AREA UNTUK BARANG KELUAR
//
// Beda dengan Barang Masuk:
//   - Scan langsung masuk cart (tidak ada preview)
//   - Stok 0 → tolak dengan snack merah
//   - Akumulasi qty kalau scan barang sama
//   - 2 mode: Scan/Input Kode (gabung) + Cari Nama
//
// Callback yang dipassing dari parent:
//   - onResult: dipanggil setelah scan/pilih, untuk show snack
//   - focusNode: agar parent bisa kontrol fokus
// ─────────────────────────────────────────────────────────────────

class InputAreaKeluar extends StatefulWidget {
  final void Function(AddResult result, Barang? barang) onResult;
  final FocusNode? externalFocus;

  const InputAreaKeluar({
    super.key,
    required this.onResult,
    this.externalFocus,
  });

  @override
  State<InputAreaKeluar> createState() => _InputAreaKeluarState();
}

class _InputAreaKeluarState extends State<InputAreaKeluar> {
  final _inputCtrl = TextEditingController();
  late final FocusNode _inputFocus;
  final _namaCtrl  = TextEditingController();
  final _namaFocus = FocusNode();

  String _mode = 'input'; // 'input' | 'nama'
  String _lastScanCode = '';
  DateTime _lastScanTime = DateTime(2000);

  static const Color _merahTua  = Color(0xFFB71C1C);
  static const Color _merahMuda = Color(0xFFFFEBEE);

  @override
  void initState() {
    super.initState();
    _inputFocus = widget.externalFocus ?? FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    if (widget.externalFocus == null) _inputFocus.dispose();
    _namaCtrl.dispose();
    _namaFocus.dispose();
    super.dispose();
  }

  void _fokusKeInput() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_mode == 'input') {
        _inputFocus.requestFocus();
      } else {
        _namaFocus.requestFocus();
      }
    });
  }

  void _onInputSubmit(String value) {
    final kode = value.trim().toUpperCase();
    if (kode.isEmpty) { _fokusKeInput(); return; }

    // Debounce 800ms
    final now = DateTime.now();
    if (kode == _lastScanCode &&
        now.difference(_lastScanTime).inMilliseconds < 800) {
      _inputCtrl.clear();
      _fokusKeInput();
      return;
    }
    _lastScanCode = kode;
    _lastScanTime = now;

    final cart = context.read<CartProvider>();
    final result = cart.tambahByKode(kode);
    _inputCtrl.clear();

    // Cari barang object untuk callback (untuk show info di snack)
    Barang? barang;
    if (result != AddResult.notFound) {
      try {
        barang = cart.cariByKode(kode).firstWhere(
          (b) => b.kodeScan.toUpperCase() == kode,
        );
      } catch (_) {
        barang = null;
      }
    }

    widget.onResult(result, barang);
    _fokusKeInput();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _merahTua.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // Header + status cache
        Row(children: [
          Flexible(child: Text(
            _mode == 'input' ? 'Scan / Input Kode' : 'Cari Nama Barang',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          )),
          const SizedBox(width: 8),
          Consumer<CartProvider>(
            builder: (_, CartProvider c, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.isLoading ? Colors.orange
                      : c.cacheLoaded ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 4),
              Text(c.isLoading ? 'Memuat...' : c.cacheLoaded ? 'Siap' : 'Error',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),

        // Mode toggle
        Wrap(spacing: 6, children: [
          _modeBtn('input', Icons.qr_code_scanner_rounded, 'Scan/Kode'),
          _modeBtn('nama',  Icons.search_rounded,          'Cari Nama'),
        ]),
        const SizedBox(height: 10),

        // Field dinamis
        if (_mode == 'input')
          _AutocompleteFieldKeluar(
            ctrl: _inputCtrl, focus: _inputFocus,
            hintText: 'Tembak scanner atau ketik kode...',
            prefixIcon: Icons.qr_code_2_rounded,
            isKode: true,
            allowedFormatter: FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
            onSubmit: _onInputSubmit,
            onPilih: (Barang b) {
              _inputCtrl.clear();
              final cart = context.read<CartProvider>();
              final result = cart.tambahBarang(b);
              widget.onResult(result, b);
              _fokusKeInput();
            },
          )
        else
          _AutocompleteFieldKeluar(
            ctrl: _namaCtrl, focus: _namaFocus,
            hintText: 'Ketik nama barang (min 2 huruf)...',
            prefixIcon: Icons.search_rounded,
            isKode: false,
            allowedFormatter: null,
            onSubmit: (v) {
              final cart = context.read<CartProvider>();
              final hasil = cart.cariByNama(v);
              if (hasil.length == 1) {
                _namaCtrl.clear();
                final result = cart.tambahBarang(hasil.first);
                widget.onResult(result, hasil.first);
              }
            },
            onPilih: (Barang b) {
              _namaCtrl.clear();
              final cart = context.read<CartProvider>();
              final result = cart.tambahBarang(b);
              widget.onResult(result, b);
            },
          ),

        const SizedBox(height: 6),
        Text(
          _mode == 'input'
            ? 'Scan langsung masuk keranjang. Stok 0 = ditolak.'
            : 'Ketik 2+ huruf nama, klik dari saran.',
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
        ),
      ]),
    );
  }

  Widget _modeBtn(String mode, IconData icon, String label) {
    final bool aktif = _mode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _mode = mode);
        _fokusKeInput();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: aktif ? _merahTua : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: aktif ? _merahTua : Colors.grey.shade300,
            width: aktif ? 0 : 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: aktif ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
            fontSize: 11.5,
            fontWeight: aktif ? FontWeight.w600 : FontWeight.normal,
            color: aktif ? Colors.white : Colors.grey.shade700,
          )),
        ]),
      ),
    );
  }
}

// ── Autocomplete reusable widget khusus barang keluar ────────────
class _AutocompleteFieldKeluar extends StatefulWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final String hintText;
  final IconData prefixIcon;
  final bool isKode;
  final TextInputFormatter? allowedFormatter;
  final Function(String) onSubmit;
  final Function(Barang) onPilih;

  const _AutocompleteFieldKeluar({
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
  State<_AutocompleteFieldKeluar> createState() => _AutocompleteFieldKeluarState();
}

class _AutocompleteFieldKeluarState extends State<_AutocompleteFieldKeluar> {
  List<Barang> _hasil = [];

  @override
  void initState() {
    super.initState();
    if (widget.ctrl.text.length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cari(widget.ctrl.text);
      });
    }
  }

  void _cari(String kw) {
    if (kw.length < 2) {
      if (_hasil.isNotEmpty) setState(() => _hasil = []);
      return;
    }
    final cart = context.read<CartProvider>();
    final List<Barang> result = widget.isKode ? cart.cariByKode(kw) : cart.cariByNama(kw);
    setState(() => _hasil = result);
  }

  void _clear() {
    widget.ctrl.clear();
    setState(() => _hasil = []);
  }

  @override
  Widget build(BuildContext context) {
    const Color biruTua = Color(0xFF01579B);
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
        style: TextStyle(
          fontSize: 14,
          fontFamily: widget.isKode ? 'monospace' : null,
          letterSpacing: widget.isKode ? 1 : 0,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(fontSize: 12, letterSpacing: 0, color: Colors.grey),
          prefixIcon: Icon(widget.prefixIcon, color: biruTua, size: 19),
          suffix: widget.ctrl.text.isNotEmpty
              ? SizedBox(
                  width: 28, height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: _clear,
                  ),
                )
              : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.blue.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: biruTua, width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFFE3F2FD).withValues(alpha: 0.4),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
      if (_hasil.isNotEmpty) ...[
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 3),
            )],
          ),
          child: SingleChildScrollView(
            child: Column(children: _hasil.map((Barang b) => InkWell(
              onTap: () { widget.onPilih(b); setState(() => _hasil = []); },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      widget.isKode ? b.kodeScan : b.namaBarang,
                      style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12,
                        fontFamily: widget.isKode ? 'monospace' : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.isKode ? b.namaBarang : b.kodeScan,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontFamily: widget.isKode ? null : 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ])),
                  const SizedBox(width: 6),
                  // Harga jual
                  Text(_rp(b.hargaJual),
                      style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: Color(0xFF1B5E20),
                      )),
                  const SizedBox(width: 8),
                  // Stok dengan warna
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: b.stokSisa == 0
                          ? Colors.red.shade100
                          : b.stokSisa < 5
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'stok ${b.stokSisa}',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: b.stokSisa == 0
                            ? Colors.red.shade800
                            : b.stokSisa < 5
                                ? Colors.orange.shade800
                                : Colors.green.shade800,
                      ),
                    ),
                  ),
                ]),
              ),
            )).toList()),
          ),
        ),
      ],
    ]);
  }

  String _rp(int n) {
    if (n == 0) return '-';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }
}
