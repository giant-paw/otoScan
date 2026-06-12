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

  factory TransaksiMasuk.fromMap(Map<String, dynamic> map) {
    return TransaksiMasuk(
      // Parsing kebal: Paksa ubah apapun jadi string dulu, baru convert ke int
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      kodeScan: map['kode_scan']?.toString() ?? '',
      qty: map['qty'] != null ? int.tryParse(map['qty'].toString()) ?? 1 : 1,
      hargaAstraSatuan: map['harga_astra_satuan'] != null 
          ? int.tryParse(map['harga_astra_satuan'].toString()) ?? 0 
          : 0,
      tanggal: map['tanggal']?.toString() ?? '',
      jam: map['jam']?.toString() ?? '',
      namaBarang: map['nama_barang']?.toString() ?? '',
      kategori: map['kategori']?.toString() ?? '',
    );
  }

  int get totalModal => qty * hargaAstraSatuan;
}
