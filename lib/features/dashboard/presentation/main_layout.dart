import 'package:flutter/material.dart';
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
  int _selectedIndex = 0; // Menyimpan indeks menu yang sedang aktif

  // Daftar tampilan (sementara kita isi teks kosong untuk diuji)
  final List<Widget> _pages = [
    const Center(child: Text('Dashboard Visual', style: TextStyle(fontSize: 24))),
    const MasterBarangView(),
    const ScanMasukView(),
    const ScanKeluarView(),
    const BukuPiutangView(),  
    const LaporanView()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ================= AREA SIDEBAR KIRI =================
          Material( // <--- 1. GANTI 'Container' MENJADI 'Material'
            color: const Color(0xFF01579B),
            child: SizedBox( // <--- 2. BUNGKUS 'Column' DENGAN 'SizedBox' UNTUK LEBARNYA
              width: 250,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2, color: Colors.white, size: 50),
                        SizedBox(height: 10),
                        Text("OtoScan Logistik", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                  _buildMenuItem(0, Icons.dashboard_rounded, "Dashboard"),
                  _buildMenuItem(1, Icons.dns_rounded, "Master Barang"),
                  _buildMenuItem(2, Icons.archive_rounded, "Barang Masuk"),
                  _buildMenuItem(3, Icons.unarchive_rounded, "Barang Keluar"),
                  _buildMenuItem(4, Icons.book_rounded, "Buku Piutang"),
                  _buildMenuItem(5, Icons.insert_chart_rounded, "Laporan & Rekap"),
                  const Spacer(),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.white70),
                    title: const Text("Keluar Aplikasi", style: TextStyle(color: Colors.white70)),
                    onTap: () {
                      // Logika kembali ke halaman login
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ================= AREA KONTEN KANAN =================
          Expanded(
            child: Container(
              color: const Color(0xFFF3F8FF), // Latar belakang area konten biru super pudar (bersih)
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

    // Fungsi pembantu untuk menggambar tombol menu agar rapi
    Widget _buildMenuItem(int index, IconData icon, String title) {
      final isSelected = _selectedIndex == index;
      
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          // Menggunakan bawaan ListTile agar animasi 'klik' tetap terlihat
          selected: isSelected,
          selectedTileColor: const Color(0xFF03A9F4).withOpacity(0.3),
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
            ),
          ),
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
      );
    }
}