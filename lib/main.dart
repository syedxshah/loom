import 'package:flutter/material.dart';
import 'package:loom/backend/status.dart';
import 'package:loom/screens/home.dart';
import 'package:loom/screens/key.dart';
import 'package:loom/screens/password.dart';
import 'package:loom/screens/setting.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isAuth = false;
  try {
    final data = await StatusStorage.getStatus();
    if (data != null && data['is_active'] == true) {
      DateTime expiryDate = DateTime.parse(data['expiry_date']);
      if (DateTime.now().isBefore(expiryDate)) {
        isAuth = true;
      }
    }
  } catch (e) {
    isAuth = false;
  }

  runApp(MainApp(isActivated: isAuth));
}

class MainApp extends StatelessWidget {
  final bool isActivated;
  const MainApp({super.key, required this.isActivated});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Loom',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFFF6F8FB),
      ),
      // Yahan ab direct check ho raha hai
      home: isActivated ? Password() : const KeyGen(),
      routes: {
        '/password': (context) => Password(),
        '/home': (context) => const Home(),
        '/setting': (context) => const SettingPage(),
        '/key': (context) => const KeyGen(),
      },
    );
  }
}
