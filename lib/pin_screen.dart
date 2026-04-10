import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PinScreen extends StatefulWidget {
  final bool creation;
  PinScreen({this.creation = false});
  @override
  _PinScreenState createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String _pinConfirm = '';
  bool _confirmation = false;
  String _erreur = '';

  void _appuyerChiffre(String chiffre) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += chiffre;
      _erreur = '';
    });
    if (_pin.length == 4) {
      Future.delayed(Duration(milliseconds: 200), () => _valider());
    }
  }

  void _supprimer() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _valider() async {
    final prefs = await SharedPreferences.getInstance();
    if (widget.creation) {
      if (!_confirmation) {
        setState(() { _pinConfirm = _pin; _pin = ''; _confirmation = true; });
      } else {
        if (_pin == _pinConfirm) {
          await prefs.setString('app_pin', _pin);
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
        } else {
          setState(() { _pin = ''; _pinConfirm = ''; _confirmation = false; _erreur = 'Les codes ne correspondent pas'; });
        }
      }
    } else {
      final savedPin = prefs.getString('app_pin');
      if (_pin == savedPin) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
      } else {
        setState(() { _pin = ''; _erreur = 'Code incorrect'; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBlue,
      body: SafeArea(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(height: 40),
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Center(child: Text('🔐', style: TextStyle(fontSize: 36))),
          ),
          SizedBox(height: 24),
          Text('NattPro', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text(
            widget.creation
                ? (_confirmation ? 'Confirmez votre code PIN' : 'Créez votre code PIN')
                : 'Entrez votre code PIN',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SizedBox(height: 40),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) =>
            Container(
              margin: EdgeInsets.symmetric(horizontal: 10),
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: i < _pin.length ? Colors.white : Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          )),
          SizedBox(height: 16),
          if (_erreur.isNotEmpty) Text(_erreur, style: TextStyle(color: Colors.red.shade200, fontSize: 13)),
          SizedBox(height: 40),
          ...[
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '⌫'],
          ].map((rangee) => Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: rangee.map((c) =>
              GestureDetector(
                onTap: () {
                  if (c == '⌫') _supprimer();
                  else if (c.isNotEmpty) _appuyerChiffre(c);
                },
                child: Container(
                  width: 72, height: 72,
                  margin: EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: c.isEmpty ? Colors.transparent : Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: c == '⌫'
                      ? Icon(Icons.backspace_outlined, color: Colors.white, size: 22)
                      : Text(c, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500))),
                ),
              ),
            ).toList()),
          )).toList(),
          SizedBox(height: 20),
          if (!widget.creation) TextButton(
            onPressed: () async {
              await supabase.auth.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('app_pin');
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AuthScreen()));
            },
            child: Text('Mot de passe oublié ? Se reconnecter', style: TextStyle(color: Colors.white60, fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}
