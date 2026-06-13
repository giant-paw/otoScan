// File: lib/features/transaksi_keluar/data/pembayaran_hutang_model.dart

class PembayaranHutang {
  final int? id;
  final String noNota;
  final String tanggal;
  final String jam;
  final int jumlah;
  final String metode;
  final String? catatan;

  PembayaranHutang({
    this.id,
    required this.noNota,
    required this.tanggal,
    required this.jam,
    required this.jumlah,
    this.metode = 'TUNAI',
    this.catatan,
  });

  factory PembayaranHutang.fromMap(Map<String, dynamic> map) => PembayaranHutang(
    id:       map['id'] as int?,
    noNota:   map['no_nota'] as String,
    tanggal:  map['tanggal'] as String,
    jam:      map['jam'] as String,
    jumlah:   (map['jumlah'] ?? 0) as int,
    metode:   (map['metode'] ?? 'TUNAI') as String,
    catatan:  map['catatan'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'no_nota':  noNota,
    'tanggal':  tanggal,
    'jam':      jam,
    'jumlah':   jumlah,
    'metode':   metode,
    'catatan':  catatan,
  };
}
