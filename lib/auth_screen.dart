import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'pin_screen.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _connexion = true;
  bool _chargement = false;
  bool _voirPass = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(children: [
            SizedBox(height: 40),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(20)),
              child: Center(child: Text('🤝', style: TextStyle(fontSize: 40))),
            ),
            SizedBox(height: 20),
            Text('NattPro', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kBlue)),
            SizedBox(height: 6),
            Text('Gérez votre tontine facilement', style: TextStyle(color: kGris, fontSize: 14)),
            SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _connexion = true),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: _connexion ? kBlue : Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Text('Connexion', textAlign: TextAlign.center,
                      style: TextStyle(color: _connexion ? Colors.white : kGris, fontWeight: FontWeight.w600)),
                  ),
                )),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _connexion = false),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: !_connexion ? kBlue : Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Text('Inscription', textAlign: TextAlign.center,
                      style: TextStyle(color: !_connexion ? Colors.white : kGris, fontWeight: FontWeight.w600)),
                  ),
                )),
              ]),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Adresse email',
                    prefixIcon: Icon(Icons.email_outlined, color: kBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                SizedBox(height: 14),
                TextField(
                  controller: _passCtrl,
                  obscureText: !_voirPass,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock_outlined, color: kBlue),
                    suffixIcon: IconButton(
                      icon: Icon(_voirPass ? Icons.visibility_off : Icons.visibility, color: kGris),
                      onPressed: () => setState(() => _voirPass = !_voirPass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _chargement ? null : _soumettre,
                    child: _chargement
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(_connexion ? 'Se connecter' : 'Créer un compte',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _connexion = !_connexion),
              child: Text(
                _connexion ? 'Pas encore de compte ? Inscrivez-vous' : 'Déjà un compte ? Connectez-vous',
                style: TextStyle(color: kBlue, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _soumettre() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    setState(() => _chargement = true);
    try {
      if (_connexion) {
        await supabase.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      } else {
        await supabase.auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      }
      // Vérifier si PIN existe
      final prefs = await SharedPreferences.getInstance();
      final pinExiste = prefs.getString('app_pin') != null;
      if (pinExiste) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PinScreen(creation: true)));
      }
    } on AuthException catch (e) {
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }
