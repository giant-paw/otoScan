// File: lib/features/auth/presentation/login_view.dart

import 'package:flutter/material.dart';
import '../../dashboard/presentation/main_layout.dart';
import '../data/auth_service.dart';

// ─────────────────────────────────────────────────────────────────
// LOGIN VIEW — pakai AuthService (password ter-hash, bisa diganti)
//
// Default: admin / admin (bisa diganti di menu Pengaturan nanti)
// ─────────────────────────────────────────────────────────────────

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscure = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    // Pastikan kredensial default ada saat pertama install.
    // catchError supaya kalau DB belum siap, tidak bikin crash diam-diam.
    _authService.pastikanAdaKredensial().catchError((_) {});
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _prosesLogin() async {
    setState(() { _isLoading = true; _error = ''; });

    try {
      final err = await _authService.login(
        _usernameController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      if (err == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
      } else {
        setState(() => _error = err);
      }
    } catch (e) {
      // Jangan biarkan loading nyangkut kalau ada error tak terduga
      if (mounted) setState(() => _error = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF81D4FA), Color(0xFFE1F5FE), Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 8,
              shadowColor: Colors.blue.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.two_wheeler_rounded, size: 72, color: Color(0xFF0288D1)),
                    const SizedBox(height: 16),
                    const Text(
                      "OtoScan Logistik",
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                    ),
                    const Text(
                      "Sistem Rekap & Transaksi Bengkel",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 36),

                    // Username
                    TextField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) { if (_error.isNotEmpty) setState(() => _error = ''); },
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: const Icon(Icons.person, color: Color(0xFF03A9F4)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF03A9F4), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Password
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) { if (_error.isNotEmpty) setState(() => _error = ''); },
                      onSubmitted: (_) => _prosesLogin(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock, color: Color(0xFF03A9F4)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF03A9F4), width: 2),
                        ),
                      ),
                    ),

                    // Error message
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text(_error, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 30),

                    // Tombol login
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF03A9F4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: _isLoading ? null : _prosesLogin,
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('MASUK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Default: admin / admin — ganti di Pengaturan',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}