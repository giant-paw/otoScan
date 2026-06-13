// File: lib/features/transaksi_keluar/presentation/widgets/dialog_detail_nota.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../pelanggan/presentation/controller/pelanggan_provider.dart';
import '../../data/transaksi_keluar_header_model.dart';
import '../../data/transaksi_keluar_detail_model.dart';
import '../../data/transaksi_keluar_repository.dart';
import '../../data/pembayaran_hutang_model.dart';
import '../controller/piutang_provider.dart';

// ─────────────────────────────────────────────────────────────────
// DIALOG DETAIL NOTA + CATAT PEMBAYARAN
//
// Cara pakai:
//   await DialogDetailNota.show(context, noNota);
//
// Dialog menampilkan:
//   - Info nota (no, tanggal, pelanggan)
//   - Isi keranjang (qty, harga, subtotal per item)
//   - Total tagihan, dibayar, sisa hutang
//   - History pembayaran (semua cicilan)
//   - Tombol "Catat Pembayaran" → buka sub-dialog
// ─────────────────────────────────────────────────────────────────

class DialogDetailNota {
  static Future<void> show(BuildContext context, String noNota) async {
    return showDialog(
      context: context,
      builder: (ctx) => _DialogDetailContent(noNota: noNota),
    );
  }
}

class _DialogDetailContent extends StatefulWidget {
  final String noNota;
  const _DialogDetailContent({required this.noNota});

  @override
  State<_DialogDetailContent> createState() => _DialogDetailContentState();
}

class _DialogDetailContentState extends State<_DialogDetailContent> {
  final _repo = TransaksiKeluarRepository();
  TransaksiKeluarHeader?  _header;
  List<TransaksiKeluarDetail> _details = [];
  List<PembayaranHutang>      _pembayarans = [];
  bool _isLoading = true;
  String _error = '';

  static const Color _ungu     = Color(0xFF6A1B9A);
  static const Color _hijauTua = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _muatDetail();
  }

  Future<void> _muatDetail() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = ''; });
    try {
      final data = await _repo.detailNota(widget.noNota);
      if (!mounted) return;
      if (data == null) {
        setState(() { _error = 'Nota tidak ditemukan'; _isLoading = false; });
        return;
      }
      setState(() {
        _header = data['header'] as TransaksiKeluarHeader;
        _details = data['details'] as List<TransaksiKeluarDetail>;
        _pembayarans = data['pembayarans'] as List<PembayaranHutang>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Gagal memuat: $e'; _isLoading = false; });
    }
  }

  String _rp(int n) {
    if (n == 0) return 'Rp 0';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  // ─────────────────────────────────────────────────────────────
  // Catat pembayaran cicilan
  // ─────────────────────────────────────────────────────────────
  Future<void> _bukaDialogCatat() async {
    if (_header == null) return;
    final hasil = await showDialog<int>(
      context: context,
      builder: (ctx) => _DialogCatatPembayaran(header: _header!),
    );

    if (hasil == null || !mounted) return;

    // Proses pembayaran via PiutangProvider
    final piutang = context.read<PiutangProvider>();
    final pelanggan = context.read<PelangganProvider>();

    final err = await piutang.catatPembayaran(
      noNota: _header!.noNota,
      jumlah: hasil,
      pelangganProvider: pelanggan,
    );

    if (!mounted) return;
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('✓ Pembayaran berhasil dicatat'),
        backgroundColor: _hijauTua,
        behavior: SnackBarBehavior.floating,
      ));
      // Reload detail untuk update sisa hutang
      await _muatDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: SizedBox(
        width: 540,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()))
            : _error.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(30),
                    child: Center(child: Text(_error,
                        style: TextStyle(color: Colors.red.shade700))))
                : _buildContent(),
      ),
      actions: _isLoading || _error.isNotEmpty || _header == null
          ? [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))]
          : null,
    );
  }

  Widget _buildContent() {
    final h = _header!;
    final bool isLunas = h.isLunas;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [

      // ── HEADER ──
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLunas ? _hijauTua : Colors.orange.shade700,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(isLunas ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(h.noNota,
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold,
                  fontSize: 15, fontFamily: 'monospace', letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(isLunas ? 'LUNAS' : 'HUTANG',
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold,
                    fontSize: 10, letterSpacing: 0.8,
                  )),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${h.tanggal} • ${h.jam}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
          if (h.namaPelangganSnapshot != null && h.namaPelangganSnapshot!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.person_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Expanded(child: Text(
                h.namaPelangganSnapshot!,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              )),
              if (h.noHpSnapshot != null && h.noHpSnapshot!.isNotEmpty)
                Text(h.noHpSnapshot!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10, fontFamily: 'monospace',
                    )),
            ]),
          ],
        ]),
      ),

      // ── BODY (scrollable) ──
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Section: Item
            const Text('Item Transaksi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(children: _details.asMap().entries.map((e) {
                final i = e.key;
                final d = e.value;
                final isLast = i == _details.length - 1;
                return Container(
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(
                      bottom: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(children: [
                      Container(
                        width: 22, height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('${i+1}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.namaBarang,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        Text(d.kodeScan,
                            style: const TextStyle(
                              fontSize: 9.5, color: Colors.grey, fontFamily: 'monospace',
                            )),
                      ])),
                      const SizedBox(width: 6),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${d.qty} × ${_rp(d.hargaJualSaatItu)}',
                            style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                        Text(_rp(d.subtotalJual),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ]),
                    ]),
                  ),
                );
              }).toList()),
            ),

            // Section: Total
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(children: [
                _rowTotal('Total Tagihan', _rp(h.totalTagihan), bold: true),
                const SizedBox(height: 4),
                _rowTotal('Sudah Dibayar', _rp(h.totalDibayar), warna: _hijauTua),
                if (h.kembalian > 0) ...[
                  const SizedBox(height: 4),
                  _rowTotal('Kembalian', _rp(h.kembalian), warna: Colors.blue.shade700),
                ],
                if (!isLunas) ...[
                  const Divider(height: 14),
                  _rowTotal('SISA HUTANG', _rp(h.sisaHutang),
                      bold: true, warna: Colors.red.shade700, fontSize: 14),
                ],
                if (isLunas && h.tanggalLunas != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.check_circle_rounded, color: _hijauTua, size: 14),
                    const SizedBox(width: 4),
                    Text('Lunas pada: ${h.tanggalLunas}',
                        style: TextStyle(fontSize: 11, color: _hijauTua, fontWeight: FontWeight.w600)),
                  ]),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _ungu.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    const Text('Laba transaksi: ',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(_rp(h.totalLaba),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: _ungu)),
                  ]),
                ),
              ]),
            ),

            // Section: History Pembayaran
            const SizedBox(height: 14),
            Row(children: [
              const Text('Riwayat Pembayaran',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 6),
              Text('(${_pembayarans.length})',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
            const SizedBox(height: 6),
            if (_pembayarans.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Belum ada pembayaran',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(children: _pembayarans.asMap().entries.map((e) {
                  final i = e.key;
                  final b = e.value;
                  final isLast = i == _pembayarans.length - 1;
                  return Container(
                    decoration: BoxDecoration(
                      border: isLast ? null : Border(
                        bottom: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: Row(children: [
                        Icon(Icons.payments_outlined, size: 14, color: _hijauTua),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${b.tanggal} • ${b.jam}',
                              style: const TextStyle(fontSize: 10.5)),
                          Text('${b.metode}${b.catatan != null && b.catatan!.isNotEmpty ? " — ${b.catatan}" : ""}',
                              style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                              overflow: TextOverflow.ellipsis),
                        ])),
                        Text(_rp(b.jumlah),
                            style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12, color: _hijauTua,
                            )),
                      ]),
                    ),
                  );
                }).toList()),
              ),

            // Catatan kalau ada
            if (h.catatan != null && h.catatan!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.sticky_note_2_outlined, size: 14, color: Colors.amber.shade800),
                  const SizedBox(width: 6),
                  Expanded(child: Text(h.catatan!,
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900))),
                ]),
              ),
            ],
          ]),
        ),
      ),

      // ── ACTIONS ──
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
        ),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Text('Tutup', style: TextStyle(fontSize: 12)),
            ),
          ),
          if (!isLunas) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _bukaDialogCatat,
                icon: const Icon(Icons.add_card_rounded, size: 16),
                label: const Text('Catat Pembayaran', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: _hijauTua,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }

  Widget _rowTotal(String label, String value, {
    bool bold = false,
    Color? warna,
    double fontSize = 12,
  }) {
    return Row(children: [
      Text(label, style: TextStyle(fontSize: fontSize, color: Colors.grey.shade700)),
      const Spacer(),
      Text(value, style: TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.w600,
        fontSize: fontSize + (bold ? 1 : 0),
        color: warna ?? Colors.black87,
      )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────
// SUB-DIALOG: CATAT PEMBAYARAN CICILAN
// Return: jumlah dibayar (int) atau null jika batal
// ─────────────────────────────────────────────────────────────────

class _DialogCatatPembayaran extends StatefulWidget {
  final TransaksiKeluarHeader header;
  const _DialogCatatPembayaran({required this.header});

  @override
  State<_DialogCatatPembayaran> createState() => _DialogCatatPembayaranState();
}

class _DialogCatatPembayaranState extends State<_DialogCatatPembayaran> {
  final _jumlahCtrl = TextEditingController();
  final _jumlahFocus = FocusNode();
  int _jumlah = 0;
  String _error = '';

  static const Color _hijauTua = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumlahFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _jumlahCtrl.dispose();
    _jumlahFocus.dispose();
    super.dispose();
  }

  String _rp(int n) {
    if (n == 0) return 'Rp 0';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  void _setJumlah(int n) {
    setState(() {
      _jumlah = n;
      _jumlahCtrl.text = n == 0 ? '' : '$n';
      _jumlahCtrl.selection = TextSelection.collapsed(offset: _jumlahCtrl.text.length);
      _error = '';
    });
  }

  void _onSimpan() {
    if (_jumlah <= 0) {
      setState(() => _error = 'Jumlah harus lebih dari 0');
      return;
    }
    if (_jumlah > widget.header.sisaHutang) {
      setState(() => _error = 'Jumlah melebihi sisa hutang');
      return;
    }
    Navigator.of(context).pop(_jumlah);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.header;
    final int sisaSetelahBayar = (h.sisaHutang - _jumlah).clamp(0, 999999999);
    final bool akanLunas = sisaSetelahBayar == 0 && _jumlah > 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        Icon(Icons.payments_rounded, color: _hijauTua, size: 20),
        const SizedBox(width: 8),
        const Text('Catat Pembayaran', style: TextStyle(fontSize: 15)),
      ]),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info nota
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.namaPelangganSnapshot ?? 'Pelanggan',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              Text(h.noNota,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
              const SizedBox(height: 6),
              Row(children: [
                const Text('Sisa hutang: ',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(_rp(h.sisaHutang),
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700,
                    )),
              ]),
            ]),
          ),
          const SizedBox(height: 14),

          // Input jumlah
          const Text('Jumlah Dibayar',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _jumlahCtrl,
            focusNode: _jumlahFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: TextStyle(fontSize: 17, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _hijauTua, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (v) {
              setState(() {
                _jumlah = int.tryParse(v) ?? 0;
                _error = '';
              });
            },
            onSubmitted: (_) => _onSimpan(),
          ),
          const SizedBox(height: 8),

          // Quick buttons
          Wrap(spacing: 6, runSpacing: 6, children: [
            _quickBtn('LUNAS PENUH', _hijauTua, () => _setJumlah(h.sisaHutang)),
            _quickBtn('½ SISA', Colors.blue.shade700, () => _setJumlah((h.sisaHutang / 2).round())),
            _quickBtn('10K', null, () => _setJumlah(10000)),
            _quickBtn('25K', null, () => _setJumlah(25000)),
            _quickBtn('50K', null, () => _setJumlah(50000)),
            _quickBtn('100K', null, () => _setJumlah(100000)),
          ]),
          const SizedBox(height: 12),

          // Preview status setelah bayar
          if (_jumlah > 0)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: akanLunas ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: akanLunas ? Colors.green.shade200 : Colors.blue.shade200,
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(
                    akanLunas ? Icons.celebration_rounded : Icons.info_outline_rounded,
                    color: akanLunas ? _hijauTua : Colors.blue.shade700, size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    akanLunas ? 'AKAN LUNAS 🎉' : 'Setelah pembayaran:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12,
                      color: akanLunas ? _hijauTua : Colors.blue.shade800,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  akanLunas
                      ? 'Sisa hutang: Rp 0 — transaksi tutup buku'
                      : 'Sisa hutang: ${_rp(sisaSetelahBayar)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ]),
            ),

          // Error
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
                const SizedBox(width: 6),
                Expanded(child: Text(_error,
                    style: TextStyle(fontSize: 11, color: Colors.red.shade800))),
              ]),
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _jumlah > 0 ? _onSimpan : null,
          style: FilledButton.styleFrom(backgroundColor: _hijauTua),
          child: const Text('Simpan Pembayaran'),
        ),
      ],
    );
  }

  Widget _quickBtn(String label, Color? warna, VoidCallback onTap) {
    final c = warna ?? Colors.grey.shade700;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: c,
        )),
      ),
    );
  }
}
