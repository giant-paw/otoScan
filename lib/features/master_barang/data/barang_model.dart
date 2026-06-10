class Barang {
  final String kodeScan;
  final String namaBarang;
  final String kategori;
  final int hargaAstra;
  final int hargaJual;
  final int stokSisa;

  Barang({
    required this.kodeScan,
    required this.namaBarang,
    this.kategori = 'AHM',
    this.hargaAstra = 0,
    this.hargaJual = 0,
    this.stokSisa = 0,
  });

  // Dari baris SQLite ke objek Dart
  factory Barang.fromMap(Map<String, dynamic> map) {
    return Barang(
      kodeScan: map['kode_scan'] as String,
      namaBarang: map['nama_barang'] as String,
      kategori: map['kategori'] as String? ?? 'AHM',
      hargaAstra: map['harga_astra'] as int? ?? 0,
      hargaJual: map['harga_jual'] as int? ?? 0,
      stokSisa: map['stok_sisa'] as int? ?? 0,
    );
  }

  // Dari objek Dart ke Map untuk SQLite
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

  // Buat salinan objek dengan nilai yang diubah sebagian
  Barang copyWith({
    String? kodeScan,
    String? namaBarang,
    String? kategori,
    int? hargaAstra,
    int? hargaJual,
    int? stokSisa,
  }) {
    return Barang(
      kodeScan: kodeScan ?? this.kodeScan,
      namaBarang: namaBarang ?? this.namaBarang,
      kategori: kategori ?? this.kategori,
      hargaAstra: hargaAstra ?? this.hargaAstra,
      hargaJual: hargaJual ?? this.hargaJual,
      stokSisa: stokSisa ?? this.stokSisa,
    );
  }
}
