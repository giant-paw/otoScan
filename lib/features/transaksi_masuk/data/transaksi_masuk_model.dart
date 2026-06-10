class TransaksiMasuk {
  final int? id;
  final String kodeScan;
  final int qty;
  final int hargaAstraSatuan; // snapshot — tidak ikut berubah meski harga master diupdate
  final String tanggal;       // format: yyyy-MM-dd
  final String jam;           // format: HH:mm:ss

  // Tambahan untuk tampilan UI (JOIN dari master_barang, tidak disimpan ke DB)
  final String namaBarang;
  final String kategori;

  TransaksiMasuk({
    this.id,
    required this.kodeScan,
    required this.qty,
    required this.hargaAstraSatuan,
    required this.tanggal,
    required this.jam,
    this.namaBarang = '',
    this.kategori = '',
  });

  Map<String, dynamic> toMap() => {
        'kode_scan': kodeScan,
        'qty': qty,
        'harga_astra_satuan': hargaAstraSatuan,
        'tanggal': tanggal,
        'jam': jam,
      };

  factory TransaksiMasuk.fromMap(Map<String, dynamic> map) => TransaksiMasuk(
        id: map['id'] as int?,
        kodeScan: map['kode_scan'] as String,
        qty: map['qty'] as int? ?? 1,
        hargaAstraSatuan: map['harga_astra_satuan'] as int? ?? 0,
        tanggal: map['tanggal'] as String,
        jam: map['jam'] as String,
        namaBarang: map['nama_barang'] as String? ?? '',
        kategori: map['kategori'] as String? ?? '',
      );

  int get totalModal => qty * hargaAstraSatuan;
}
