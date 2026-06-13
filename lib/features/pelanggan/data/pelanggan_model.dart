// File: lib/features/pelanggan/data/pelanggan_model.dart

class Pelanggan {
  final int? id;
  final String nama;
  final String? noHp;
  final String? alamat;
  final String? catatan;
  final int totalTransaksi;
  final int totalHutangAktif;
  final String createdAt;
  final String updatedAt;

  Pelanggan({
    this.id,
    required this.nama,
    this.noHp,
    this.alamat,
    this.catatan,
    this.totalTransaksi = 0,
    this.totalHutangAktif = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pelanggan.fromMap(Map<String, dynamic> map) => Pelanggan(
    id:               map['id'] as int?,
    nama:             map['nama'] as String,
    noHp:             map['no_hp'] as String?,
    alamat:           map['alamat'] as String?,
    catatan:          map['catatan'] as String?,
    totalTransaksi:   (map['total_transaksi'] ?? 0) as int,
    totalHutangAktif: (map['total_hutang_aktif'] ?? 0) as int,
    createdAt:        map['created_at'] as String,
    updatedAt:        map['updated_at'] as String,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'nama':                nama,
    'no_hp':               noHp,
    'alamat':              alamat,
    'catatan':             catatan,
    'total_transaksi':     totalTransaksi,
    'total_hutang_aktif':  totalHutangAktif,
    'created_at':          createdAt,
    'updated_at':          updatedAt,
  };

  Pelanggan copyWith({
    int? id,
    String? nama,
    String? noHp,
    String? alamat,
    String? catatan,
    int? totalTransaksi,
    int? totalHutangAktif,
    String? createdAt,
    String? updatedAt,
  }) => Pelanggan(
    id:               id ?? this.id,
    nama:             nama ?? this.nama,
    noHp:             noHp ?? this.noHp,
    alamat:           alamat ?? this.alamat,
    catatan:          catatan ?? this.catatan,
    totalTransaksi:   totalTransaksi ?? this.totalTransaksi,
    totalHutangAktif: totalHutangAktif ?? this.totalHutangAktif,
    createdAt:        createdAt ?? this.createdAt,
    updatedAt:        updatedAt ?? this.updatedAt,
  );

  // Display helper untuk autocomplete: "Budi - 0812..."
  String get displayLabel {
    if (noHp != null && noHp!.isNotEmpty) {
      return '$nama — $noHp';
    }
    return nama;
  }

  bool get punyaHutang => totalHutangAktif > 0;
}
