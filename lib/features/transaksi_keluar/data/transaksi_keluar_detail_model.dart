// File: lib/features/transaksi_keluar/data/transaksi_keluar_detail_model.dart

import '../../master_barang/data/barang_model.dart';

class TransaksiKeluarDetail {
  final int? id;
  final String noNota;
  final String kodeScan;
  final String namaBarang;
  final String kategori;
  final int qty;
  final int hargaModalSaatItu;
  final int hargaJualSaatItu;
  final int subtotalJual;
  final int subtotalModal;
  final int subtotalLaba;

  TransaksiKeluarDetail({
    this.id,
    required this.noNota,
    required this.kodeScan,
    required this.namaBarang,
    required this.kategori,
    required this.qty,
    required this.hargaModalSaatItu,
    required this.hargaJualSaatItu,
    required this.subtotalJual,
    required this.subtotalModal,
    required this.subtotalLaba,
  });

  factory TransaksiKeluarDetail.fromMap(Map<String, dynamic> map) => TransaksiKeluarDetail(
    id:                 map['id'] as int?,
    noNota:             map['no_nota'] as String,
    kodeScan:           map['kode_scan'] as String,
    namaBarang:         map['nama_barang'] as String,
    kategori:           map['kategori'] as String,
    qty:                (map['qty'] ?? 0) as int,
    hargaModalSaatItu:  (map['harga_modal_saat_itu'] ?? 0) as int,
    hargaJualSaatItu:   (map['harga_jual_saat_itu'] ?? 0) as int,
    subtotalJual:       (map['subtotal_jual'] ?? 0) as int,
    subtotalModal:      (map['subtotal_modal'] ?? 0) as int,
    subtotalLaba:       (map['subtotal_laba'] ?? 0) as int,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'no_nota':                noNota,
    'kode_scan':              kodeScan,
    'nama_barang':            namaBarang,
    'kategori':               kategori,
    'qty':                    qty,
    'harga_modal_saat_itu':   hargaModalSaatItu,
    'harga_jual_saat_itu':    hargaJualSaatItu,
    'subtotal_jual':          subtotalJual,
    'subtotal_modal':         subtotalModal,
    'subtotal_laba':          subtotalLaba,
  };
}

// ─────────────────────────────────────────────────────────────────
// CART ITEM — item dalam keranjang (sebelum jadi detail di DB)
//
// Saat user scan/pilih barang, masuk ke cart sebagai CartItem.
// Saat checkout, CartItem dikonversi ke TransaksiKeluarDetail
// dengan snapshot harga modal & jual.
// ─────────────────────────────────────────────────────────────────
class CartItem {
  final Barang barang;
  int qty;

  CartItem({required this.barang, this.qty = 1});

  // Subtotal hitung dari harga master (mutlak, tidak bisa diubah)
  int get subtotalJual  => qty * barang.hargaJual;
  int get subtotalModal => qty * barang.hargaAstra;
  int get subtotalLaba  => subtotalJual - subtotalModal;

  // Konversi ke detail saat checkout (snapshot harga)
  TransaksiKeluarDetail toDetail(String noNota) => TransaksiKeluarDetail(
    noNota:             noNota,
    kodeScan:           barang.kodeScan,
    namaBarang:         barang.namaBarang,
    kategori:           barang.kategori,
    qty:                qty,
    hargaModalSaatItu:  barang.hargaAstra,
    hargaJualSaatItu:   barang.hargaJual,
    subtotalJual:       subtotalJual,
    subtotalModal:      subtotalModal,
    subtotalLaba:       subtotalLaba,
  );
}
