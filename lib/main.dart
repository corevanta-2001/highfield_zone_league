import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Firebase - with your web config
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDdaCSGopIo17lsu1JwK5jFTDO3If-YouA",
      authDomain: "highfields-78e12.firebaseapp.com",
      projectId: "highfields-78e12",
      storageBucket: "highfields-78e12.firebasestorage.app",
      messagingSenderId: "906294378990",
      appId: "1:906294378990:web:2c02f4ee29bbf0b3400eff",
    ),
  );

  // 2. Supabase - with your keys
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
      home: HomeScreen(), // removed const because it uses Firebase
      routes: {'/login': (context) => const LoginScreen()},
      debugShowCheckedModeBanner: false,
    );
  }
}