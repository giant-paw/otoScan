// File: lib/features/transaksi_keluar/presentation/buku_piutang_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/transaksi_keluar_header_model.dart';
import '../data/piutang_pelanggan_repository.dart';
import 'controller/piutang_provider.dart';
import 'widgets/dialog_detail_nota.dart';

// ─────────────────────────────────────────────────────────────────
// BUKU PIUTANG VIEW — 2 TAB
//
//   Tab 1: PER NOTA     — daftar nota belum lunas (detail transaksi)
//   Tab 2: PER PELANGGAN — dikelompokkan per orang (siapa hutang berapa)
//
// Jawaban permintaan: owner bisa lihat riwayat utang siapa saja.
// ─────────────────────────────────────────────────────────────────

class BukuPiutangView extends StatefulWidget {
  const BukuPiutangView({super.key});

  @override
  State<BukuPiutangView> createState() => _BukuPiutangViewState();
}

class _BukuPiutangViewState extends State<BukuPiutangView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  static const Color _ungu     = Color(0xFF6A1B9A);
  static const Color _unguMuda = Color(0xFFF3E5F5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PiutangProvider>().init();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _rp(int n) {
    if (n == 0) return 'Rp 0';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> _bukaDetailNota(String noNota) async {
    await DialogDetailNota.show(context, noNota);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(),
        const SizedBox(height: 12),

        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: _unguMuda.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: _ungu,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: _ungu,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: 'Per Nota'),
              Tab(text: 'Per Pelanggan'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TabPerNota(onBukaDetail: _bukaDetailNota),
              const _TabPerPelanggan(),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Wrap(
      spacing: 14, runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _unguMuda, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.book_rounded, color: _ungu, size: 22),
        ),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Buku Piutang', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          Text('Daftar hutang pelanggan yang belum lunas',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        const Spacer(),
        Consumer<PiutangProvider>(
          builder: (_, PiutangProvider p, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.totalPiutangSistem > 0 ? Colors.red.shade50 : _unguMuda,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: p.totalPiutangSistem > 0 ? Colors.red.shade200 : _ungu.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('TOTAL PIUTANG LUAR',
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              Text(_rp(p.totalPiutangSistem),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                      color: p.totalPiutangSistem > 0 ? Colors.red.shade800 : _ungu)),
            ]),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// TAB 1: PER NOTA
// ═════════════════════════════════════════════════════════════════
class _TabPerNota extends StatefulWidget {
  final Future<void> Function(String noNota) onBukaDetail;
  const _TabPerNota({required this.onBukaDetail});

  @override
  State<_TabPerNota> createState() => _TabPerNotaState();
}

class _TabPerNotaState extends State<_TabPerNota> {
  final _searchCtrl = TextEditingController();
  static const Color _ungu = Color(0xFF6A1B9A);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _rp(int n) {
    if (n == 0) return 'Rp 0';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PiutangProvider>(
      builder: (_, PiutangProvider p, _) {
        return Column(children: [
          // Search + filter
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => p.setSearchKeyword(v),
            decoration: InputDecoration(
              hintText: 'Cari nama pelanggan atau no nota...',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _ungu),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () { _searchCtrl.clear(); p.setSearchKeyword(''); })
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _filterChip('Semua', FilterUmur.semua, p),
            _filterChip('< 7 hari', FilterUmur.kurang7, p),
            _filterChip('7-30 hari', FilterUmur.kurang30, p),
            _filterChip('> 30 hari ⚠', FilterUmur.lebih30, p),
          ]),
          const SizedBox(height: 12),
          Expanded(child: _buildList(p)),
        ]);
      },
    );
  }

  Widget _filterChip(String label, FilterUmur f, PiutangProvider p) {
    final aktif = p.filter == f;
    return GestureDetector(
      onTap: () => p.setFilter(f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: aktif ? _ungu : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: aktif ? _ungu : Colors.grey.shade300, width: aktif ? 0 : 0.8),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11.5, fontWeight: aktif ? FontWeight.w600 : FontWeight.normal,
          color: aktif ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }

  Widget _buildList(PiutangProvider p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: p.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildListContent(p),
    );
  }

  Widget _buildListContent(PiutangProvider p) {
    final list = p.hutangAktifTerfilter;
    if (list.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline_rounded, size: 56, color: Colors.green.shade200),
          const SizedBox(height: 10),
          Text(p.hutangAktif.isEmpty ? 'Tidak Ada Hutang Aktif' : 'Tidak Ada Hasil',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(p.hutangAktif.isEmpty ? 'Semua transaksi sudah lunas 🎉' : 'Coba ubah filter',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ]),
      ));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: list.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (_, int i) => _baris(list[i], p),
    );
  }

  Widget _baris(TransaksiKeluarHeader h, PiutangProvider p) {
    final warna = p.warnaUmur(h);
    return InkWell(
      onTap: () => widget.onBukaDetail(h.noNota),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(width: 4, height: 44,
              decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.namaPelangganSnapshot ?? '(Tanpa Nama)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Text(h.noNota, style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
              const Text(' • ', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text(p.labelUmur(h), style: TextStyle(fontSize: 10.5, color: warna, fontWeight: FontWeight.w600)),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_rp(h.sisaHutang),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: warna)),
            Text('dari ${_rp(h.totalTagihan)}', style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
          ]),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// TAB 2: PER PELANGGAN
// ═════════════════════════════════════════════════════════════════
class _TabPerPelanggan extends StatefulWidget {
  const _TabPerPelanggan();

  @override
  State<_TabPerPelanggan> createState() => _TabPerPelangganState();
}

class _TabPerPelangganState extends State<_TabPerPelanggan> {
  final _repo = PiutangPelangganRepository();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  List<Map<String, dynamic>> _listFiltered = [];
  bool _isLoading = true;

  static const Color _ungu = Color(0xFF6A1B9A);

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _isLoading = true);
    final data = await _repo.daftarPelangganBerhutang();
    if (!mounted) return;
    setState(() {
      _list = data;
      _listFiltered = data;
      _isLoading = false;
    });
  }

  void _cari(String kw) {
    if (kw.trim().isEmpty) {
      setState(() => _listFiltered = _list);
      return;
    }
    final k = kw.toLowerCase();
    setState(() {
      _listFiltered = _list.where((e) {
        final nama = (e['nama'] as String).toLowerCase();
        final hp = (e['noHp'] as String? ?? '').toLowerCase();
        return nama.contains(k) || hp.contains(k);
      }).toList();
    });
  }

  String _rp(int n) {
    if (n == 0) return 'Rp 0';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  int _umurHari(String? tgl) {
    if (tgl == null) return 0;
    try {
      final parts = tgl.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      return DateTime.now().difference(d).inDays;
    } catch (_) { return 0; }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(
        controller: _searchCtrl,
        onChanged: _cari,
        decoration: InputDecoration(
          hintText: 'Cari nama atau no HP pelanggan...',
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _ungu),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () { _searchCtrl.clear(); _cari(''); })
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          isDense: true,
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _listFiltered.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.people_outline_rounded, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text(_list.isEmpty ? 'Tidak ada pelanggan berhutang' : 'Tidak ada hasil',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _listFiltered.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (_, i) => _barisPelanggan(_listFiltered[i]),
                    ),
        ),
      ),
    ]);
  }

  Widget _barisPelanggan(Map<String, dynamic> e) {
    final nama = e['nama'] as String;
    final hp = e['noHp'] as String?;
    final total = e['totalHutang'] as int;
    final jumlahNota = e['jumlahNota'] as int;
    final umurTertua = _umurHari(e['notaTertua'] as String?);

    final Color warna = umurTertua >= 30 ? Colors.red.shade700
        : umurTertua >= 14 ? Colors.orange.shade700
        : Colors.green.shade700;

    return InkWell(
      onTap: () => _bukaDetailPelanggan(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          // Avatar inisial
          Container(
            width: 42, height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _ungu.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              nama.isNotEmpty ? nama[0].toUpperCase() : '?',
              style: const TextStyle(color: _ungu, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              if (hp != null && hp.isNotEmpty) ...[
                Icon(Icons.phone_rounded, size: 11, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Text(hp, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontFamily: 'monospace')),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _ungu.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$jumlahNota nota',
                    style: const TextStyle(fontSize: 9.5, color: _ungu, fontWeight: FontWeight.w600)),
              ),
              if (umurTertua >= 30) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$umurTertua hari',
                      style: TextStyle(fontSize: 9.5, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_rp(total),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: warna)),
            Text('total hutang', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
          ]),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
        ]),
      ),
    );
  }

  Future<void> _bukaDetailPelanggan(Map<String, dynamic> e) async {
    final notaList = await _repo.notaHutangPelanggan(
      pelangganId: e['pelangganId'] as int?,
      namaSnapshot: e['nama'] as String?,
    );
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => _DialogHutangPelanggan(
        nama: e['nama'] as String,
        noHp: e['noHp'] as String?,
        totalHutang: e['totalHutang'] as int,
        notaList: notaList,
      ),
    );
    // Refresh setelah tutup (mungkin ada pembayaran)
    _muat();
    if (mounted) context.read<PiutangProvider>().refresh();
  }
}

// ── Dialog daftar nota hutang 1 pelanggan ────────────────────────
class _DialogHutangPelanggan extends StatelessWidget {
  final String nama;
  final String? noHp;
  final int totalHutang;
  final List<Map<String, dynamic>> notaList;

  const _DialogHutangPelanggan({
    required this.nama,
    required this.noHp,
    required this.totalHutang,
    required this.notaList,
  });

  static const Color _ungu = Color(0xFF6A1B9A);

  String _rp(int n) {
    if (n == 0) return 'Rp 0';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _ungu,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Text(nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nama, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
                if (noHp != null && noHp!.isNotEmpty)
                  Text(noHp!, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontFamily: 'monospace')),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Total Hutang', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
                Text(_rp(totalHutang),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
            ]),
          ),
          // List nota
          Flexible(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${notaList.length} Nota Belum Lunas',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Flexible(child: ListView.separated(
                shrinkWrap: true,
                itemCount: notaList.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final n = notaList[i];
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      await DialogDetailNota.show(context, n['noNota'] as String);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n['noNota'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, fontFamily: 'monospace')),
                          Text('${n['tanggal']} • ${n['jam']}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(_rp(n['sisaHutang'] as int),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red.shade700)),
                          Text('dari ${_rp(n['totalTagihan'] as int)}',
                              style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        ]),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 16),
                      ]),
                    ),
                  );
                },
              )),
              const SizedBox(height: 8),
              Text('Klik nota untuk catat pembayaran',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}