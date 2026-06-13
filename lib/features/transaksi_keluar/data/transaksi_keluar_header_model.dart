// File: lib/features/transaksi_keluar/data/transaksi_keluar_header_model.dart

enum StatusNota { lunas, hutang }

class TransaksiKeluarHeader {
  final String noNota;
  final String tanggal;
  final String jam;

  final int totalTagihan;
  final int totalModal;
  final int totalLaba;

  final int totalDibayar;
  final int sisaHutang;
  final int kembalian;

  final StatusNota status;

  final int? pelangganId;
  final String? namaPelangganSnapshot;
  final String? noHpSnapshot;

  final String? catatan;
  final String? tanggalLunas;

  TransaksiKeluarHeader({
    required this.noNota,
    required this.tanggal,
    required this.jam,
    required this.totalTagihan,
    required this.totalModal,
    required this.totalLaba,
    required this.totalDibayar,
    required this.sisaHutang,
    this.kembalian = 0,
    required this.status,
    this.pelangganId,
    this.namaPelangganSnapshot,
    this.noHpSnapshot,
    this.catatan,
    this.tanggalLunas,
  });

  factory TransaksiKeluarHeader.fromMap(Map<String, dynamic> map) => TransaksiKeluarHeader(
    noNota:                 map['no_nota'] as String,
    tanggal:                map['tanggal'] as String,
    jam:                    map['jam'] as String,
    totalTagihan:           (map['total_tagihan'] ?? 0) as int,
    totalModal:             (map['total_modal'] ?? 0) as int,
    totalLaba:              (map['total_laba'] ?? 0) as int,
    totalDibayar:           (map['total_dibayar'] ?? 0) as int,
    sisaHutang:             (map['sisa_hutang'] ?? 0) as int,
    kembalian:              (map['kembalian'] ?? 0) as int,
    status:                 (map['status'] as String) == 'LUNAS'
                              ? StatusNota.lunas : StatusNota.hutang,
    pelangganId:            map['pelanggan_id'] as int?,
    namaPelangganSnapshot:  map['nama_pelanggan_snapshot'] as String?,
    noHpSnapshot:           map['no_hp_snapshot'] as String?,
    catatan:                map['catatan'] as String?,
    tanggalLunas:           map['tanggal_lunas'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'no_nota':                  noNota,
    'tanggal':                  tanggal,
    'jam':                      jam,
    'total_tagihan':            totalTagihan,
    'total_modal':              totalModal,
    'total_laba':               totalLaba,
    'total_dibayar':            totalDibayar,
    'sisa_hutang':              sisaHutang,
    'kembalian':                kembalian,
    'status':                   status == StatusNota.lunas ? 'LUNAS' : 'HUTANG',
    'pelanggan_id':             pelangganId,
    'nama_pelanggan_snapshot':  namaPelangganSnapshot,
    'no_hp_snapshot':           noHpSnapshot,
    'catatan':                  catatan,
    'tanggal_lunas':            tanggalLunas,
  };

  bool get isLunas => status == StatusNota.lunas;
  bool get isHutang => status == StatusNota.hutang;
}
