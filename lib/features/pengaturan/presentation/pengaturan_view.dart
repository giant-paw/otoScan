// File: lib/features/pengaturan/presentation/pengaturan_view.dart

import 'package:flutter/material.dart';
import '../../auth/data/auth_service.dart';

// ─────────────────────────────────────────────────────────────────
// PENGATURAN VIEW — ganti password, ganti username, info aplikasi
//
// Semua lewat AuthService (password ter-hash).
// ─────────────────────────────────────────────────────────────────

class PengaturanView extends StatefulWidget {
  const PengaturanView({super.key});

  @override
  State<PengaturanView> createState() => _PengaturanViewState();
}

class _PengaturanViewState extends State<PengaturanView> {
  final _authService = AuthService();

  static const Color _biru     = Color(0xFF01579B);
  static const Color _hijauTua = Color(0xFF1B5E20);

  String _username = '';

  @override
  void initState() {
    super.initState();
    _muatUsername();
  }

  Future<void> _muatUsername() async {
    final u = await _authService.getUsername();
    if (mounted) setState(() => _username = u);
  }

  void _snack(String pesan, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(pesan),
      backgroundColor: error ? Colors.red.shade600 : _hijauTua,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(children: [
                  _kartuGantiPassword(),
                  const SizedBox(height: 16),
                  _kartuGantiUsername(),
                  const SizedBox(height: 16),
                  _kartuInfoAplikasi(),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _biru.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.settings_rounded, color: _biru, size: 22),
      ),
      const SizedBox(width: 14),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('Pengaturan', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        Text('Kelola akun dan aplikasi',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    ]);
  }

  // ── KARTU: GANTI PASSWORD ────────────────────────────────────
  Widget _kartuGantiPassword() {
    return _KartuGantiPassword(
      authService: _authService,
      onBerhasil: () => _snack('Password berhasil diganti ✓'),
      onGagal: (e) => _snack(e, error: true),
    );
  }

  // ── KARTU: GANTI USERNAME ────────────────────────────────────
  Widget _kartuGantiUsername() {
    return _KartuGantiUsername(
      authService: _authService,
      usernameSekarang: _username,
      onBerhasil: (baru) {
        setState(() => _username = baru);
        _snack('Username berhasil diganti ✓');
      },
      onGagal: (e) => _snack(e, error: true),
    );
  }

  // ── KARTU: INFO APLIKASI ─────────────────────────────────────
  Widget _kartuInfoAplikasi() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline_rounded, color: _biru, size: 18),
          const SizedBox(width: 8),
          const Text('Info Aplikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 12),
        _infoRow('Nama Aplikasi', 'OtoScan Logistik'),
        _infoRow('Versi', '1.0.0'),
        _infoRow('Login sebagai', _username),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(children: [
            Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Lupa password? Hubungi teknisi untuk reset ke default (admin).',
              style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// KARTU GANTI PASSWORD (stateful sendiri biar controller rapi)
// ═════════════════════════════════════════════════════════════════
class _KartuGantiPassword extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onBerhasil;
  final void Function(String) onGagal;

  const _KartuGantiPassword({
    required this.authService,
    required this.onBerhasil,
    required this.onGagal,
  });

  @override
  State<_KartuGantiPassword> createState() => _KartuGantiPasswordState();
}

class _KartuGantiPasswordState extends State<_KartuGantiPassword> {
  final _lamaCtrl = TextEditingController();
  final _baruCtrl = TextEditingController();
  final _konfirmasiCtrl = TextEditingController();
  bool _obscureLama = true, _obscureBaru = true, _obscureKonf = true;
  bool _loading = false;

  static const Color _hijauTua = Color(0xFF1B5E20);

  @override
  void dispose() {
    _lamaCtrl.dispose();
    _baruCtrl.dispose();
    _konfirmasiCtrl.dispose();
    super.dispose();
  }

  Future<void> _proses() async {
    if (_baruCtrl.text != _konfirmasiCtrl.text) {
      widget.onGagal('Konfirmasi password tidak cocok');
      return;
    }
    setState(() => _loading = true);
    final err = await widget.authService.gantiPassword(
      passwordLama: _lamaCtrl.text,
      passwordBaru: _baruCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      _lamaCtrl.clear();
      _baruCtrl.clear();
      _konfirmasiCtrl.clear();
      widget.onBerhasil();
    } else {
      widget.onGagal(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lock_outline_rounded, color: _hijauTua, size: 18),
          const SizedBox(width: 8),
          const Text('Ubah Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 14),
        _field(_lamaCtrl, 'Password Lama', _obscureLama,
            () => setState(() => _obscureLama = !_obscureLama)),
        const SizedBox(height: 12),
        _field(_baruCtrl, 'Password Baru (min 4 karakter)', _obscureBaru,
            () => setState(() => _obscureBaru = !_obscureBaru)),
        const SizedBox(height: 12),
        _field(_konfirmasiCtrl, 'Konfirmasi Password Baru', _obscureKonf,
            () => setState(() => _obscureKonf = !_obscureKonf)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _proses,
            style: FilledButton.styleFrom(
              backgroundColor: _hijauTua,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Simpan Password Baru', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, bool obscure, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.key_rounded, size: 18),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// KARTU GANTI USERNAME
// ═════════════════════════════════════════════════════════════════
class _KartuGantiUsername extends StatefulWidget {
  final AuthService authService;
  final String usernameSekarang;
  final void Function(String) onBerhasil;
  final void Function(String) onGagal;

  const _KartuGantiUsername({
    required this.authService,
    required this.usernameSekarang,
    required this.onBerhasil,
    required this.onGagal,
  });

  @override
  State<_KartuGantiUsername> createState() => _KartuGantiUsernameState();
}

class _KartuGantiUsernameState extends State<_KartuGantiUsername> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  static const Color _biru = Color(0xFF01579B);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _proses() async {
    setState(() => _loading = true);
    final err = await widget.authService.gantiUsername(_ctrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      final baru = _ctrl.text.trim();
      _ctrl.clear();
      widget.onBerhasil(baru);
    } else {
      widget.onGagal(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.person_outline_rounded, color: _biru, size: 18),
          const SizedBox(width: 8),
          const Text('Ubah Username', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 6),
        Text('Username sekarang: ${widget.usernameSekarang}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            labelText: 'Username Baru (min 3 karakter)',
            labelStyle: const TextStyle(fontSize: 13),
            prefixIcon: const Icon(Icons.badge_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _proses,
            style: FilledButton.styleFrom(
              backgroundColor: _biru,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Simpan Username Baru', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}