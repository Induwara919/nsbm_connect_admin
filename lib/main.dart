import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/admin_shell.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const NSBMConnectAdmin());
}

class NSBMConnectAdmin extends StatelessWidget {
  const NSBMConnectAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NSBM Connect Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const AdminShell(selectedIndex: 0),
        '/students': (context) => const AdminShell(selectedIndex: 1),
        '/announcements': (context) => const AdminShell(selectedIndex: 2),
        '/calendar': (context) => const AdminShell(selectedIndex: 3),
        '/timetable': (context) => const AdminShell(selectedIndex: 4),
        '/community': (context) => const AdminShell(selectedIndex: 5),
        '/news': (context) => const AdminShell(selectedIndex: 6),
        '/management': (context) => const AdminShell(selectedIndex: 7),
      },
    );
  }
}