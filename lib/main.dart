import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/database/database_helper.dart';
import 'features/auth/presentation/login_view.dart';
import 'package:provider/provider.dart';
import 'features/master_barang/presentation/controller/master_provider.dart';
import 'features/transaksi_masuk/presentation/controller/scan_masuk_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await DatabaseHelper.instance.database;
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MasterProvider()..loadData()), 
        ChangeNotifierProvider(create: (_) => ScanMasukProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OtoScan Logistik',
      theme: ThemeData(
        // Menanamkan tema warna utama (Biru Muda) ke seluruh aplikasi
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF03A9F4)),
        useMaterial3: true,
        fontFamily: 'Segoe UI',
      ),
      home: const LoginView(),
    );
  }
}
