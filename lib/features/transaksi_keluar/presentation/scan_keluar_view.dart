// File: lib/features/transaksi_keluar/presentation/scan_keluar_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../master_barang/data/barang_model.dart';
import '../../master_barang/presentation/controller/master_provider.dart';
import '../../pelanggan/presentation/controller/pelanggan_provider.dart';
import '../data/transaksi_keluar_detail_model.dart';
import 'controller/cart_provider.dart';
import 'controller/kasir_provider.dart';
import 'widgets/input_area_keluar.dart';
import 'widgets/dialog_kasir.dart';

// ─────────────────────────────────────────────────────────────────
// LAYAR UTAMA BARANG KELUAR (POS Kasir)
//
// Layout:
//   [Header]
//   [Input Area (kiri)]  [Keranjang (kanan)]
//
// Layout responsif: kalau width < 900px → stack vertikal
// ─────────────────────────────────────────────────────────────────

class ScanKeluarView extends StatefulWidget {
  const ScanKeluarView({super.key});

  @override
  State<ScanKeluarView> createState() => _ScanKeluarViewState();
}

class _ScanKeluarViewState extends State<ScanKeluarView> {
  final _scanFocus = FocusNode();
  Barang? _itemTerakhir; // untuk banner status

  static const Color _merahTua  = Color(0xFFB71C1C);
  static const Color _merahMuda = Color(0xFFFFEBEE);
  static const Color _hijauTua  = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cart = context.read<CartProvider>();
      final pelanggan = context.read<PelangganProvider>();
      cart.init();
      pelanggan.init();
    });
  }

  @override
  void dispose() {
    _scanFocus.dispose();
    super.dispose();
  }


  void _fokusKeScan() {
    if (!mounted) return;
    // Beri jeda sangat singkat agar UI selesai menggambar
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        // Jangan clear textfield di sini agar tidak menghapus input yang sedang diketik
        FocusScope.of(context).requestFocus(_scanFocus);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // HANDLER HASIL SCAN/PILIH
  // ─────────────────────────────────────────────────────────────
  void _onScanResult(AddResult result, Barang? barang) {
    final cart = context.read<CartProvider>();
    switch (result) {
      case AddResult.added:
        setState(() => _itemTerakhir = barang);
        _showSnack(
          '✓ ${barang?.namaBarang ?? "Barang"} masuk keranjang',
          warna: _hijauTua,
        );

      case AddResult.accumulated:
        setState(() => _itemTerakhir = barang);
        // Cari qty terbaru di cart
        final qty = cart.items
            .firstWhere(
              (i) => i.barang.kodeScan == barang?.kodeScan,
              orElse: () => CartItem(barang: barang!, qty: 1),
            ).qty;
        _showSnack(
          '✓ ${barang?.namaBarang ?? "Barang"} — qty: $qty',
          warna: _hijauTua, durasi: 1,
        );

      case AddResult.stokHabis:
        _showSnack(
          '✗ ${barang?.namaBarang ?? "Barang"} STOK HABIS — tidak bisa dijual',
          warna: Colors.red.shade700, durasi: 3,
        );

      case AddResult.stokTidakCukup:
        _showSnack(cart.errorPesan, warna: Colors.orange.shade700, durasi: 3);

      case AddResult.hargaJualKosong:
        _showSnack(
          '✗ ${barang?.namaBarang ?? "Barang"} belum punya harga jual — set dulu di Master',
          warna: Colors.orange.shade700, durasi: 3,
        );

      case AddResult.notFound:
        _showSnack(cart.errorPesan.isEmpty
            ? 'Kode tidak terdaftar'
            : cart.errorPesan,
            warna: Colors.red.shade700);
    }
    _fokusKeScan();
  }

  void _showSnack(String pesan, {required Color warna, int durasi = 2}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(pesan),
        backgroundColor: warna,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: durasi),
      ));
  }

  String _rp(int n) {
    if (n == 0) return '-';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> _bukaCheckout() async {
  final cart = context.read<CartProvider>();
  if (cart.isEmpty) {
    _showSnack('Keranjang kosong', warna: Colors.orange.shade700);
    return;
  }

  // Buka dialog kasir
  final noNota = await DialogKasir.show(context);

  if (!mounted) return;
  if (noNota != null) {
    // Sukses simpan nota
    setState(() => _itemTerakhir = null);
    _showSnack(
      '✓ Nota $noNota tersimpan',
      warna: _hijauTua, durasi: 3,
    );
  }
  _fokusKeScan();
}

  // ─────────────────────────────────────────────────────────────
  // KONFIRMASI KOSONGKAN CART
  // ─────────────────────────────────────────────────────────────
  Future<void> _konfirmasiKosongkan() async {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kosongkan Keranjang?'),
        content: Text('${cart.jumlahItem} item akan dihapus dari keranjang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Kosongkan'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      cart.kosongkan();
      setState(() => _itemTerakhir = null);
      _fokusKeScan();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Listener(
      // Listener akan mendeteksi setiap kali jari/mouse diangkat (klik selesai)
      onPointerUp: (_) {
        // Setelah klik apapun di layar (misal klik + qty), kembalikan fokus ke scanner
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          // Hanya kembalikan fokus JIKA pengguna tidak sedang mengetik di field Qty manual
          // Asumsinya, jika tidak ada field yang aktif, pasti kembali ke scanner.
          final currentFocus = FocusScope.of(context).focusedChild;
          if (currentFocus == null || currentFocus == _scanFocus) {
             _fokusKeScan();
          }
        });
      },
      child: GestureDetector(
        onTap: _fokusKeScan, // Fallback untuk klik di area benar-benar kosong
        behavior: HitTestBehavior.translucent,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isSempit = constraints.maxWidth < 900;
                  if (isSempit) {
                    return Column(children: [
                      SizedBox(
                        height: 280,
                        child: Column(children: [
                          InputAreaKeluar(
                            onResult: _onScanResult,
                            externalFocus: _scanFocus, // Pastikan ini terhubung ke TextField di dalam InputAreaKeluar
                          ),
                          const SizedBox(height: 12),
                          if (_itemTerakhir != null) Expanded(child: _buildBannerItemTerakhir()),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: _buildKeranjang()),
                    ]);
                  }
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 420,
                      child: Column(children: [
                        InputAreaKeluar(
                          onResult: _onScanResult,
                          externalFocus: _scanFocus, // Pastikan ini terhubung ke TextField di dalam InputAreaKeluar
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _buildBannerItemTerakhir()),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _buildKeranjang()),
                  ]);
                },
              ),
            ),
          ]),
        ),
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
          decoration: BoxDecoration(color: _merahMuda, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.point_of_sale_rounded, color: _merahTua, size: 22),
        ),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Barang Keluar', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          Text('Scan barang yang dibeli pelanggan',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        Consumer<CartProvider>(
          builder: (_, CartProvider c, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _merahMuda, borderRadius: BorderRadius.circular(20)),
            child: Text(
              '${c.jumlahItem} item • ${_rp(c.totalTagihan)}',
              style: const TextStyle(color: _merahTua, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ── BANNER ITEM TERAKHIR (kiri bawah) ────────────────────────
  Widget _buildBannerItemTerakhir() {
    if (_itemTerakhir == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _merahMuda.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _merahTua.withValues(alpha: 0.1)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.qr_code_2_rounded, color: _merahTua.withValues(alpha: 0.3), size: 38),
          const SizedBox(height: 8),
          Text('Siap menerima scan',
              style: TextStyle(color: _merahTua.withValues(alpha: 0.5), fontSize: 13)),
        ]),
      );
    }

    final b = _itemTerakhir!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hijauTua.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check_circle_rounded, color: _hijauTua, size: 18),
          const SizedBox(width: 6),
          const Text('Item Terakhir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        Text(b.namaBarang,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            overflow: TextOverflow.ellipsis, maxLines: 2),
        Text(b.kodeScan,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chip('Harga', _rp(b.hargaJual), warna: _hijauTua),
          _chip('Stok Sisa', '${b.stokSisa}',
            warna: b.stokSisa == 0 ? Colors.red.shade700
                : b.stokSisa < 5 ? Colors.orange.shade700 : null),
          _chip('Kategori', b.kategori),
        ]),
      ]),
    );
  }

  // ── KERANJANG (kanan, dominan) ───────────────────────────────
  Widget _buildKeranjang() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        // Header keranjang
        Consumer<CartProvider>(
          builder: (_, CartProvider c, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              Icon(Icons.shopping_cart_rounded, color: _merahTua, size: 18),
              const SizedBox(width: 8),
              Text('Keranjang (${c.jumlahItem} item)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              if (c.isNotEmpty)
                Text('Laba: ${_rp(c.totalLaba)}',
                    style: TextStyle(fontSize: 11, color: _hijauTua, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const Divider(height: 1),

        // List item
        Expanded(
          child: Consumer<CartProvider>(
            builder: (_, CartProvider c, _) {
              if (c.isEmpty) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text('Keranjang Kosong',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('Scan barang untuk mulai transaksi',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                  ]),
                ));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: c.items.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, int i) => _cartItemRow(c.items[i], i, c),
              );
            },
          ),
        ),

        // Footer: total + tombol BAYAR
        Consumer<CartProvider>(
          builder: (_, CartProvider c, _) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _merahMuda.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Text('Subtotal:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                Text(_rp(c.totalTagihan),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const Text('Total Item:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                Text('${c.totalQty} pcs', style: const TextStyle(fontSize: 13)),
              ]),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: c.isEmpty ? null : _bukaCheckout,
                style: FilledButton.styleFrom(
                  backgroundColor: _merahTua,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.payments_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'BAYAR  ${c.isEmpty ? "" : "(${_rp(c.totalTagihan)})"}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: c.isEmpty ? null : _konfirmasiKosongkan,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Kosongkan Keranjang', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── CART ITEM ROW ────────────────────────────────────────────
  Widget _cartItemRow(CartItem item, int index, CartProvider cart) {
    final qtyCtrl = TextEditingController(text: '${item.qty}');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(children: [
        // Nomor urut
        Container(
          width: 24, height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _merahMuda,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${index + 1}',
              style: TextStyle(color: _merahTua, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        const SizedBox(width: 8),

        // Nama + kode + harga × qty
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.barang.namaBarang,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5),
              overflow: TextOverflow.ellipsis, maxLines: 1),
          const SizedBox(height: 1),
          Row(children: [
            Text(_rp(item.barang.hargaJual),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const Text(' × ', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('${item.qty}',
                style: TextStyle(fontSize: 11, color: _merahTua, fontWeight: FontWeight.w600)),
            const Text(' = ', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text(_rp(item.subtotalJual),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ]),
          if (item.barang.stokSisa - item.qty < 5)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Sisa stok setelah ini: ${item.barang.stokSisa - item.qty}',
                style: TextStyle(
                  fontSize: 9.5,
                  color: item.barang.stokSisa - item.qty == 0
                      ? Colors.red.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ),
        ])),

        // Qty controls
        Row(mainAxisSize: MainAxisSize.min, children: [
          _qtyBtn('−', () {
            final err = cart.kurangQty(index);
            if (err != null && mounted) _showSnack(err, warna: Colors.red.shade700);
          }),
          const SizedBox(width: 4),
          SizedBox(
            width: 36,
            child: TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onSubmitted: (v) {
                final n = int.tryParse(v);
                if (n != null) {
                  final err = cart.setQty(index, n);
                  if (err != null && mounted) {
                    _showSnack(err, warna: Colors.red.shade700);
                    qtyCtrl.text = '${cart.items[index].qty}';
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          _qtyBtn('+', () {
            final err = cart.tambahQty(index);
            if (err != null && mounted) _showSnack(err, warna: Colors.orange.shade700);
          }),
        ]),

        // Tombol hapus
        SizedBox(
          width: 28, height: 28,
          child: IconButton(
            tooltip: 'Hapus dari keranjang',
            padding: EdgeInsets.zero,
            icon: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade400),
            onPressed: () => cart.hapusItem(index),
          ),
        ),
      ]),
    );
  }

  // ── HELPERS UI ───────────────────────────────────────────────
  Widget _chip(String label, String value, {Color? warna}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F9FC),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
      const SizedBox(height: 1),
      Text(value, style: TextStyle(
        fontWeight: FontWeight.bold, fontSize: 11,
        color: warna ?? Colors.black87,
      )),
    ]),
  );

  Widget _qtyBtn(String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(5),
    child: Container(
      width: 22, height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: _merahTua.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(5),
        color: _merahMuda.withValues(alpha: 0.3),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, color: _merahTua, fontWeight: FontWeight.bold)),
    ),
  );
}
