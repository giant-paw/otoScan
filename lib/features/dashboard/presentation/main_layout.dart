import 'package:flutter/material.dart';
import 'package:scan_go/features/dashboard/dashboard_view.dart';
import 'package:scan_go/features/transaksi_masuk/presentation/scan_masuk_view.dart';
import '../../master_barang/presentation/master_barang_view.dart';
import 'package:scan_go/features/transaksi_keluar/presentation/scan_keluar_view.dart';
import 'package:scan_go/features/transaksi_keluar/presentation/buku_piutang_view.dart';
import 'package:scan_go/features/laporan/presentation/laporan_view.dart';

// ─────────────────────────────────────────────────────────────────
// MAIN LAYOUT — sidebar + content area
//
// Struktur:
//   [Sidebar 220px] [Content (Expanded)]
//
// PENTING: _currentPage pakai GETTER (bukan final list) supaya
//   DashboardView selalu dapat callback _pindahMenu yang fresh.
//   Ini yang bikin tombol aksi cepat di dashboard bisa pindah tab.
// ─────────────────────────────────────────────────────────────────
 
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
 
  @override
  State<MainLayout> createState() => _MainLayoutState();
}
 
class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
 
  static const Color _hijauTua  = Color(0xFF1B5E20);
  static const Color _hijauMuda = Color(0xFFE8F5E9);
 
  // Fungsi pindah menu — dipakai sidebar & dashboard
  void _pindahMenu(int index) {
    setState(() => _selectedIndex = index);
  }
 
  // Getter halaman aktif (bukan final list — supaya callback fresh)
  Widget get _currentPage {
    switch (_selectedIndex) {
      case 0: return DashboardView(onNavigate: _pindahMenu);
      case 1: return const MasterBarangView();
      case 2: return const ScanMasukView();
      case 3: return const ScanKeluarView();
      case 4: return const BukuPiutangView();
      case 5: return const LaporanView();
      default: return DashboardView(onNavigate: _pindahMenu);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Row(children: [
        _buildSidebar(),
        Expanded(child: _currentPage),
      ]),
    );
  }
 
  // ── SIDEBAR ──────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 230,
      color: Colors.white,
      child: Column(children: [
        // Logo / header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _hijauMuda, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.two_wheeler_rounded, color: _hijauTua, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('OtoScan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Logistik',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
          ]),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
 
        // Menu items
        _buildMenuItem(0, Icons.dashboard_rounded, 'Dashboard'),
        _buildMenuItem(1, Icons.dns_rounded, 'Master Barang'),
        _buildMenuItem(2, Icons.archive_rounded, 'Barang Masuk'),
        _buildMenuItem(3, Icons.point_of_sale_rounded, 'Barang Keluar'),
        _buildMenuItem(4, Icons.book_rounded, 'Buku Piutang'),
        _buildMenuItem(5, Icons.insert_chart_rounded, 'Laporan'),
 
        const Spacer(),
 
        // Footer
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('v1.0 • 2026',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ),
      ]),
    );
  }
 
  Widget _buildMenuItem(int index, IconData icon, String label) {
    final bool aktif = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => _pindahMenu(index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: aktif ? _hijauTua : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(icon, size: 20, color: aktif ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              fontSize: 13.5,
              fontWeight: aktif ? FontWeight.w600 : FontWeight.normal,
              color: aktif ? Colors.white : Colors.grey.shade700,
            )),
          ]),
        ),
      ),
    );
  }
}