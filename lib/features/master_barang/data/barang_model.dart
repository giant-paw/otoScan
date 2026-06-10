class BarangModel {
  final String kodeScan;
  final String namaBarang;
  final String kategori;
  final int hargaAstra;
  final int hargaJual;
  final int stokSisa;

  BarangModel({
    required this.kodeScan,
    required this.namaBarang,
    this.kategori = 'AHM',
    this.hargaAstra = 0,
    this.hargaJual = 0,
    this.stokSisa = 0,
  });

  // Mengubah data dari SQLite (Map) menjadi Objek Flutter
  factory BarangModel.fromMap(Map<String, dynamic> map) {
    return BarangModel(
      kodeScan: map['kode_scan'],
      namaBarang: map['nama_barang'],
      kategori: map['kategori'] ?? 'AHM',
      hargaAstra: map['harga_astra'] ?? 0,
      hargaJual: map['harga_jual'] ?? 0,
      stokSisa: map['stok_sisa'] ?? 0,
    );
  }

  // Mengubah Objek Flutter menjadi format SQLite (Map) untuk di-save
  Map<String, dynamic> toMap() {
    return {
      'kode_scan': kodeScan,
      'nama_barang': namaBarang,
      'kategori': kategori,
      'harga_astra': hargaAstra,
      'harga_jual': hargaJual,
      'stok_sisa': stokSisa,
    };
  }
}