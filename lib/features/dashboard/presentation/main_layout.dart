import 'package:flutter/material.dart';
import 'package:scan_go/features/dashboard/dashboard_view.dart';
import 'package:scan_go/features/pengaturan/presentation/pengaturan_view.dart';
import 'package:scan_go/features/stok_pesanan/presentation/stok_pesanan_view.dart';
import 'package:scan_go/features/transaksi_masuk/presentation/scan_masuk_view.dart';
import '../../master_barang/presentation/master_barang_view.dart';
import 'package:scan_go/features/transaksi_keluar/presentation/scan_keluar_view.dart';
import 'package:scan_go/features/transaksi_keluar/presentation/buku_piutang_view.dart';
import 'package:scan_go/features/laporan/presentation/laporan_view.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  // Fungsi pindah menu — dipakai sidebar & dashboard (aksi cepat)
  void _pindahMenu(int index) {
    setState(() => _selectedIndex = index);
  }

  // GETTER (bukan final list) supaya DashboardView selalu dapat
  // callback _pindahMenu yang fresh untuk tombol aksi cepat.
  Widget get _currentPage {
    switch (_selectedIndex) {
      case 0: return DashboardView(onNavigate: _pindahMenu);
      case 1: return const MasterBarangView();
      case 2: return const ScanMasukView();
      case 3: return const ScanKeluarView();
      case 4: return const BukuPiutangView();
      case 5: return const StokPesananView();
      case 6: return const LaporanView();
      case 7: return const PengaturanView();
      default: return DashboardView(onNavigate: _pindahMenu);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ================= SIDEBAR KIRI =================
          Material(
            color: const Color(0xFF01579B),
            child: SizedBox(
              width: 250,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 46),
                        SizedBox(height: 10),
                        Text("OtoScan Logistik",
                            style: TextStyle(color: Colors.white, fontSize: 20,
                                fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                  _buildMenuItem(0, Icons.dashboard_rounded, "Dashboard"),
                  _buildMenuItem(1, Icons.dns_rounded, "Master Barang"),
                  _buildMenuItem(2, Icons.archive_rounded, "Barang Masuk"),
                  _buildMenuItem(3, Icons.unarchive_rounded, "Barang Keluar"),
                  _buildMenuItem(4, Icons.book_rounded, "Buku Piutang"),
                  _buildMenuItem(5, Icons.inventory_2_rounded, "Stok & Pesanan"),
                  _buildMenuItem(6, Icons.insert_chart_rounded, "Laporan & Rekap"),
                  _buildMenuItem(7, Icons.settings_rounded, "Pengaturan"),
                  const Spacer(),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.white70),
                    title: const Text("Keluar Aplikasi", style: TextStyle(color: Colors.white70)),
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ================= KONTEN KANAN =================
          Expanded(
            child: Container(
              color: const Color(0xFFF3F8FF),
              child: _currentPage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: const Color(0xFF03A9F4).withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isSelected ? const BorderSide(color: Color(0xFF03A9F4), width: 1) : BorderSide.none,
        ),
        leading: Icon(icon, color: isSelected ? Colors.white : Colors.white70),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () => _pindahMenu(index),
      ),
    );
  }
}