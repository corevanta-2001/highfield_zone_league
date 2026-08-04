import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'league_admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  bool _loading = false;
  bool _obscure = true;
  bool _isDark = false;

  Future<void> _login() async {
    if(!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      var adminSnap = await _db.collection('admins').where('email', isEqualTo: _email.text.trim()).get();
      if(adminSnap.docs.isEmpty) {
        var allAdmins = await _db.collection('admins').get();
        if(allAdmins.size >= 5) throw Exception('Max 5 admins reached');
        var cred = await _auth.createUserWithEmailAndPassword(email: _email.text.trim(), password: _pass.text);
        await _db.collection('admins').doc(cred.user!.uid).set({'email': _email.text.trim(), 'uid': cred.user!.uid});
      } else {
        await _auth.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text);
      }
      if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LeagueAdminScreen()));
    } on FirebaseAuthException catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message?? 'Auth error'), backgroundColor: Colors.redAccent));
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
    }
    setState(() => _loading = false);
  }

  Future<void> _forgot() async {
    if(_email.text.isEmpty) return;
    await _auth.sendPasswordResetEmail(email: _email.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset email sent'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final bgGradient = _isDark
     ? const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF212121)], begin: Alignment.topLeft, end: Alignment.bottomRight)
      : const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)], begin: Alignment.topLeft, end: Alignment.bottomRight);

    final cardColor = _isDark? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = _isDark? Colors.white : const Color(0xFF1A237E);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Card(
                  color: cardColor,
                  elevation: 16,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // LOGO SECTION
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _isDark? Colors.white10 : const Color(0xFF3949AB).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.sports_soccer, size: 70, color: Color(0xFF3949AB)),
                          ),
                          const SizedBox(height: 16),
                          Text('Highfield Zone League',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textColor
                            ),
                          ),
                          Text('Admin Portal', style: TextStyle(color: _isDark? Colors.grey[400] : Colors.grey)),
                          const SizedBox(height: 28),

                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Admin Email',
                              labelStyle: TextStyle(color: _isDark? Colors.grey[400] : Colors.grey[700]),
                              prefixIcon: Icon(Icons.email_outlined, color: _isDark? Colors.grey[400] : const Color(0xFF3949AB)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              filled: true,
                              fillColor: _isDark? Colors.white10 : Colors.grey[100],
                            ),
                            validator: (v) => v!.isEmpty?'Required':null
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _pass,
                            obscureText: _obscure,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(color: _isDark? Colors.grey[400] : Colors.grey[700]),
                              prefixIcon: Icon(Icons.lock_outline, color: _isDark? Colors.grey[400] : const Color(0xFF3949AB)),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure? Icons.visibility : Icons.visibility_off, color: _isDark? Colors.grey[400] : const Color(0xFF3949AB)),
                                onPressed: () => setState(() => _obscure =!_obscure),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              filled: true,
                              fillColor: _isDark? Colors.white10 : Colors.grey[100],
                            ),
                            validator: (v) => v!.length<6?'Min 6 chars':null
                          ),
                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(onPressed: _forgot, child: Text('Forgot Password?', style: TextStyle(color: const Color(0xFF3949AB))))
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: _loading
                            ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3949AB),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 6,
                                  ),
                                  child: const Text('Login / Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text('Max 5 admins allowed', style: TextStyle(fontSize: 12, color: _isDark? Colors.grey[500] : Colors.grey[600]))
                        ]
                      )
                    )
                  )
                )
              )
            ),

            // DARK MODE TOGGLE
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(_isDark? Icons.light_mode : Icons.dark_mode, color: Colors.white, size: 28),
                onPressed: () => setState(() => _isDark =!_isDark),
              ),
            )
          ]
        )
      )
    );
  }
}