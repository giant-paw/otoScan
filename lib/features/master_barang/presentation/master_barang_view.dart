import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scan_go/features/master_barang/presentation/controller/master_provider.dart';

class MasterBarangView extends StatelessWidget {
  const MasterBarangView({super.key});

  @override
  Widget build(BuildContext context) {
    // Memanggil provider
    final provider = Provider.of<MasterProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= HEADER & SEARCH BAR =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Data Master Suku Cadang",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF03A9F4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                icon: const Icon(Icons.add),
                label: const Text("Daftarkan Barang"),
                onPressed: () {
                  // TODO: Nanti kita buatkan Dialog Form Tambah Barang
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Form Tambah Barang Segera Dibuat!')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // KOLOM PENCARIAN (HURUF PER HURUF)
          TextField(
            // Fungsi onCHanged inilah yang bikin cari data instan tanpa tombol enter
            onChanged: (value) => provider.loadData(value),
            decoration: InputDecoration(
              hintText: 'Cari nama atau kode barang...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF03A9F4)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ================= TABEL DATA (Dioptimasi dengan ListView) =================
          // Header Tabel Semu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF01579B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("KODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text("NAMA SUKU CADANG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text("KATEGORI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text("STOK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                SizedBox(width: 50), // Ruang kosong untuk ikon tong sampah
              ],
            ),
          ),

          // Isi Data Tabel
          Expanded(
            child: Container(
              color: Colors.white,
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.listBarang.isEmpty
                  ? const Center(child: Text("Data tidak ditemukan atau masih kosong."))
                  : ListView.separated(
                itemCount: provider.listBarang.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final barang = provider.listBarang[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(barang.kodeScan, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 3, child: Text(barang.namaBarang)),
                        Expanded(flex: 1, child: _buildKategoriBadge(barang.kategori)),
                        Expanded(flex: 1, child: Text("${barang.stokSisa} Pcs", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            // Hapus data secara real-time
                            provider.hapusBarang(barang.kodeScan);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Desain visual kecil untuk kolom Kategori
  Widget _buildKategoriBadge(String kategori) {
    Color bgColor = Colors.grey;
    if (kategori == 'AHM') bgColor = Colors.red.shade100;
    if (kategori == 'Non-AHM') bgColor = Colors.blue.shade100;
    if (kategori == 'Baut') bgColor = Colors.orange.shade100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(5)),
      child: Text(kategori, style: const TextStyle(fontSize: 12, color: Colors.black87)),
    );
  }
}