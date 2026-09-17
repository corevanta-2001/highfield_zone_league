import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // This now works for BOTH Android and Web
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://znpvpcmkqzpconsahnex.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpucHZwY21rcXpwY29uc2FobmV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ5MTA1NDEsImV4cCI6MjEwMDQ4NjU0MX0.8YTmeg5zRaTIYKLk-Rt71ncvet8opci9pUPnpGufhy8',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Highfields Zone League',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true, fontFamily: 'Roboto'),
      home: HomeScreen(),
      routes: {'/login': (context) => const LoginScreen()},
      debugShowCheckedModeBanner: false,
    );
  }
}