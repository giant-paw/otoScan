// File: lib/features/dashboard/presentation/dashboard_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './presentation/controller/dashboard_provider.dart';

// ─────────────────────────────────────────────────────────────────
// DASHBOARD VIEW — halaman pembuka
//
// onNavigate: callback untuk pindah menu sidebar (index).
//   Dari main_layout, lewatkan fungsi yang set _selectedIndex.
//   Contoh: DashboardView(onNavigate: (i) => setState(() => _idx = i))
//
//   Index menu:
//     1 = Master Barang
//     2 = Barang Masuk
//     3 = Barang Keluar
//     4 = Buku Piutang
//     5 = Laporan
// ─────────────────────────────────────────────────────────────────

class DashboardView extends StatefulWidget {
  final void Function(int index)? onNavigate;
  const DashboardView({super.key, this.onNavigate});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  static const Color _hijauTua = Color(0xFF1B5E20);
  static const Color _biru     = Color(0xFF0277BD);
  static const Color _ungu     = Color(0xFF6A1B9A);
  static const Color _merah    = Color(0xFFB71C1C);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardProvider>().init();
    });
  }

  String _rp(int n) {
    if (n == 0) return 'Rp 0';
    final neg = n < 0;
    final abs = n.abs();
    final s = 'Rp ${abs.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
    return neg ? '-$s' : s;
  }

  String _rpSingkat(int n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}M';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}jt';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}rb';
    return '$n';
  }

  String _salam() {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat pagi';
    if (jam < 15) return 'Selamat siang';
    if (jam < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  String _tanggalLengkap() {
    final now = DateTime.now();
    const hari = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const bulan = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
                   'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${hari[now.weekday]}, ${now.day} ${bulan[now.month]} ${now.year}';
  }

  void _nav(int index) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
    }
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Consumer<DashboardProvider>(
        builder: (_, DashboardProvider p, _) {
          if (p.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (p.errorPesan.isNotEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
              const SizedBox(height: 10),
              Text(p.errorPesan, style: TextStyle(color: Colors.red.shade700)),
              const SizedBox(height: 10),
              FilledButton(onPressed: p.refresh, child: const Text('Coba Lagi')),
            ]));
          }
          return RefreshIndicator(
            onRefresh: p.refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildSapaan(p),
                const SizedBox(height: 16),
                _buildRingkasanHariIni(p),
                const SizedBox(height: 16),
                if (p.adaPeringatan) ...[
                  _buildPeringatan(p),
                  const SizedBox(height: 16),
                ],
                _buildAksiCepat(),
                const SizedBox(height: 16),
                _buildTren7Hari(p),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, constraints) {
                  final sempit = constraints.maxWidth < 760;
                  if (sempit) {
                    return Column(children: [
                      _buildTopBarang(p),
                      const SizedBox(height: 16),
                      _buildTransaksiTerakhir(p),
                    ]);
                  }
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _buildTopBarang(p)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTransaksiTerakhir(p)),
                  ]);
                }),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── SAPAAN ───────────────────────────────────────────────────
  Widget _buildSapaan(DashboardProvider p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_hijauTua, _hijauTua.withValues(alpha: 0.8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_salam()}, Admin 👋',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(_tanggalLengkap(),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
          const SizedBox(height: 8),
          Text('${p.jumlahMaster} produk terdaftar di sistem',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.store_rounded, color: Colors.white, size: 32),
        ),
      ]),
    );
  }

  // ── RINGKASAN HARI INI ───────────────────────────────────────
  Widget _buildRingkasanHariIni(DashboardProvider p) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.today_rounded, color: _hijauTua, size: 18),
        const SizedBox(width: 6),
        const Text('Ringkasan Hari Ini',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, constraints) {
        final sempit = constraints.maxWidth < 700;
        final cards = [
          _statCard('Omzet', _rp(p.omzetHariIni), Icons.attach_money_rounded, _hijauTua),
          _statCard('Laba', _rp(p.labaHariIni), Icons.trending_up_rounded, _biru),
          _statCard('Transaksi', '${p.notaHariIni}', Icons.receipt_long_rounded, _ungu),
          _statCard('Item Terjual', '${p.itemHariIni}', Icons.inventory_2_rounded, Colors.orange.shade800),
        ];
        if (sempit) {
          return Column(children: [
            Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: cards[2]), const SizedBox(width: 10), Expanded(child: cards[3])]),
          ]);
        }
        return Row(children: [
          Expanded(child: cards[0]), const SizedBox(width: 12),
          Expanded(child: cards[1]), const SizedBox(width: 12),
          Expanded(child: cards[2]), const SizedBox(width: 12),
          Expanded(child: cards[3]),
        ]);
      }),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color warna) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: warna.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: warna, size: 18),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: warna)),
        ),
      ]),
    );
  }

  // ── PERINGATAN ───────────────────────────────────────────────
  Widget _buildPeringatan(DashboardProvider p) {
    final List<Widget> items = [];

    if (p.stokHabis > 0) {
      items.add(_peringatanItem(
        Icons.error_rounded, Colors.red.shade700,
        '${p.stokHabis} barang stok habis',
        'Perlu restok segera',
        () => _nav(1), // ke Master Barang
      ));
    }
    if (p.stokMenipis > 0) {
      items.add(_peringatanItem(
        Icons.warning_amber_rounded, Colors.orange.shade700,
        '${p.stokMenipis} barang stok menipis',
        'Stok ≤ 5, siapkan pembelian',
        () => _showDialogStokMenipis(p),
      ));
    }
    if (p.piutangTotal > 0) {
      final subtitle = p.overdueNota > 0
          ? '${p.overdueNota} nota lewat 30 hari (${_rp(p.overdueTotal)})'
          : '${p.piutangNota} nota belum lunas';
      items.add(_peringatanItem(
        Icons.account_balance_wallet_rounded,
        p.overdueNota > 0 ? Colors.red.shade700 : Colors.orange.shade700,
        'Piutang ${_rp(p.piutangTotal)}',
        subtitle,
        () => _nav(4), // ke Buku Piutang
      ));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.notifications_active_rounded, color: Colors.amber.shade800, size: 18),
          const SizedBox(width: 6),
          Text('Perlu Perhatian',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber.shade900)),
        ]),
        const SizedBox(height: 10),
        ...items,
      ]),
    );
  }

  Widget _peringatanItem(IconData icon, Color warna, String judul, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: warna.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: warna, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(judul, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: warna)),
            Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ])),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 18),
        ]),
      ),
    );
  }

  Future<void> _showDialogStokMenipis(DashboardProvider p) async {
    final list = await p.getBarangStokMenipis();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 8),
          const Text('Stok Menipis', style: TextStyle(fontSize: 16)),
        ]),
        content: SizedBox(
          width: 400,
          child: list.isEmpty
              ? const Text('Tidak ada barang stok menipis')
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (_, i) {
                      final b = list[i];
                      final stok = b['stokSisa'] as int;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(b['namaBarang'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                            Text('${b['kodeScan']} • ${b['kategori']}',
                                style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: stok == 0 ? Colors.red.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: stok == 0 ? Colors.red.shade200 : Colors.orange.shade200),
                            ),
                            child: Text(
                              stok == 0 ? 'HABIS' : '$stok pcs',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold,
                                color: stok == 0 ? Colors.red.shade700 : Colors.orange.shade700),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton.icon(
            onPressed: () { Navigator.pop(ctx); _nav(2); },
            icon: const Icon(Icons.archive_rounded, size: 16),
            label: const Text('Ke Barang Masuk'),
            style: FilledButton.styleFrom(backgroundColor: _hijauTua),
          ),
        ],
      ),
    );
  }

  // ── AKSI CEPAT ───────────────────────────────────────────────
  Widget _buildAksiCepat() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.flash_on_rounded, color: Colors.amber.shade700, size: 18),
        const SizedBox(width: 6),
        const Text('Aksi Cepat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, constraints) {
        final sempit = constraints.maxWidth < 700;
        final aksi = [
          _aksiCard('Barang Masuk', Icons.archive_rounded, _hijauTua, () => _nav(2)),
          _aksiCard('Jual Barang', Icons.point_of_sale_rounded, _merah, () => _nav(3)),
          _aksiCard('Buku Piutang', Icons.book_rounded, _ungu, () => _nav(4)),
          _aksiCard('Laporan', Icons.insert_chart_rounded, _biru, () => _nav(5)),
        ];
        if (sempit) {
          return Column(children: [
            Row(children: [Expanded(child: aksi[0]), const SizedBox(width: 10), Expanded(child: aksi[1])]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: aksi[2]), const SizedBox(width: 10), Expanded(child: aksi[3])]),
          ]);
        }
        return Row(children: [
          Expanded(child: aksi[0]), const SizedBox(width: 12),
          Expanded(child: aksi[1]), const SizedBox(width: 12),
          Expanded(child: aksi[2]), const SizedBox(width: 12),
          Expanded(child: aksi[3]),
        ]);
      }),
    ]);
  }

  Widget _aksiCard(String label, IconData icon, Color warna, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: warna.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: warna.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: warna, size: 26),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: warna),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ── TREN 7 HARI ──────────────────────────────────────────────
  Widget _buildTren7Hari(DashboardProvider p) {
    if (p.tren7Hari.isEmpty) return const SizedBox.shrink();

    final maxOmzet = p.tren7Hari
        .map((e) => e['omzet'] as int)
        .fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, color: _hijauTua, size: 18),
          const SizedBox(width: 6),
          const Text('Omzet 7 Hari Terakhir',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: p.tren7Hari.map((e) {
              final omzet = e['omzet'] as int;
              final hari = e['hari'] as int;
              final tinggi = maxOmzet > 0 ? (omzet / maxOmzet * 90).clamp(3.0, 90.0) : 3.0;
              final isHariIni = e == p.tren7Hari.last;

              return Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(omzet > 0 ? _rpSingkat(omzet) : '',
                    style: const TextStyle(fontSize: 8, color: Colors.grey)),
                const SizedBox(height: 3),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: tinggi,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: isHariIni
                          ? [_hijauTua, _hijauTua.withValues(alpha: 0.7)]
                          : [Colors.grey.shade400, Colors.grey.shade300],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 4),
                Text('$hari', style: TextStyle(
                  fontSize: 10,
                  fontWeight: isHariIni ? FontWeight.bold : FontWeight.normal,
                  color: isHariIni ? _hijauTua : Colors.grey.shade600,
                )),
              ]));
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ── TOP BARANG ───────────────────────────────────────────────
  Widget _buildTopBarang(DashboardProvider p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.emoji_events_rounded, color: Colors.amber.shade700, size: 18),
          const SizedBox(width: 6),
          const Text('Terlaris Bulan Ini',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 12),
        if (p.topBarang.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('Belum ada penjualan bulan ini',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
          )
        else
          ...p.topBarang.asMap().entries.map((entry) {
            final i = entry.key;
            final b = entry.value;
            final medals = ['🥇', '🥈', '🥉'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    i < 3 ? medals[i] : '${i + 1}',
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b['namaBarang'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  Text('${b['kategori']} • Laba ${_rp(b['totalLaba'] as int)}',
                      style: TextStyle(fontSize: 9.5, color: Colors.grey.shade400)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                  child: Text('${b['totalQty']} pcs',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _hijauTua, fontSize: 11)),
                ),
              ]),
            );
          }),
      ]),
    );
  }

  // ── TRANSAKSI TERAKHIR ───────────────────────────────────────
  Widget _buildTransaksiTerakhir(DashboardProvider p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.history_rounded, color: _biru, size: 18),
          const SizedBox(width: 6),
          const Text('Transaksi Terakhir',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          InkWell(
            onTap: () => _nav(4),
            child: Text('Lihat semua',
                style: TextStyle(fontSize: 11, color: _biru, fontWeight: FontWeight.w500)),
          ),
        ]),
        const SizedBox(height: 12),
        if (p.transaksiTerakhir.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('Belum ada transaksi',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
          )
        else
          ...p.transaksiTerakhir.map((t) {
            final lunas = (t['status'] as String) == 'LUNAS';
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: lunas ? const Color(0xFFE8F5E9) : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    lunas ? Icons.check_rounded : Icons.schedule_rounded,
                    color: lunas ? _hijauTua : Colors.orange.shade700, size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t['namaPelanggan'] as String? ?? 'Umum',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  Text('${t['noNota']} • ${t['jam']}',
                      style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontFamily: 'monospace')),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_rp(t['totalTagihan'] as int),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(lunas ? 'Lunas' : 'Sisa ${_rpSingkat(t['sisaHutang'] as int)}',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: lunas ? _hijauTua : Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      )),
                ]),
              ]),
            );
          }),
      ]),
    );
  }
}
