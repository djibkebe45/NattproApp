import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

class PremiumScreen extends StatefulWidget {
  @override
  _PremiumScreenState createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _chargement = false;
  bool _estPremium = false;
  DateTime? _dateFin;

  @override
  void initState() {
    super.initState();
    _verifierStatut();
  }

  Future<void> _verifierStatut() async {
    try {
      final data = await supabase
          .from('abonnements')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .eq('actif', true)
          .maybeSingle();
      if (data != null) {
        setState(() {
          _estPremium = data['type'] == 'premium';
          _dateFin = data['date_fin'] != null ? DateTime.parse(data['date_fin']) : null;
        });
      }
    } catch (e) {}
  }

  Widget _featureItem(String label, bool inclus) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(inclus ? Icons.check_circle : Icons.cancel,
          color: inclus ? Colors.green : Colors.red.shade300, size: 14),
        SizedBox(width: 6),
        Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: inclus ? kNoir : kGris))),
      ]),
    );
  }

  Widget _avantage(String emoji, String titre, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: kBluLight, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(emoji, style: TextStyle(fontSize: 20))),
        ),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titre, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kNoir)),
          Text(description, style: TextStyle(color: kGris, fontSize: 11)),
        ])),
      ]),
    );
  }

  Widget _boutonPaiement(String label, Color color, String texte, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(label[0], style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
          SizedBox(width: 12),
          Text(texte, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kNoir)),
          Spacer(),
          Icon(Icons.arrow_forward_ios, size: 14, color: kGris),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kBlue,
        title: Text('NattPro Premium', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          // Statut actuel
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _estPremium ? Colors.amber.shade50 : kBluLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _estPremium ? Colors.amber : kBlue.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: _estPremium ? Colors.amber : kBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(_estPremium ? '👑' : '🔓', style: TextStyle(fontSize: 24))),
              ),
              SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_estPremium ? 'Compte Premium Actif' : 'Compte Gratuit',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16,
                    color: _estPremium ? Colors.amber.shade800 : kBlue)),
                if (_estPremium && _dateFin != null)
                  Text('Expire le ${_dateFin!.day}/${_dateFin!.month}/${_dateFin!.year}',
                    style: TextStyle(color: kGris, fontSize: 12)),
                if (!_estPremium)
                  Text('Passez Premium pour tout débloquer',
                    style: TextStyle(color: kGris, fontSize: 12)),
              ])),
            ]),
          ),
          SizedBox(height: 20),

          // Comparaison
          Row(children: [
            Expanded(child: Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: !_estPremium ? Colors.grey : Colors.grey.shade200,
                  width: !_estPremium ? 2 : 1)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!_estPremium) Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(6)),
                  child: Text('Actuel', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                SizedBox(height: 8),
                Text('Gratuit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                SizedBox(height: 4),
                Text('0 FCFA', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 12)),
                SizedBox(height: 12),
                _featureItem('2 groupes maximum', false),
                _featureItem('10 membres/groupe', false),
                _featureItem('Tirage au sort', true),
                _featureItem('Paiements basiques', true),
                _featureItem('WhatsApp partage', true),
                _featureItem('Publicités', false),
              ]),
            )),
            SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: _estPremium ? null : _afficherOptionsPaiement,
              child: Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _estPremium ? Colors.amber : Colors.amber.shade300,
                    width: _estPremium ? 2 : 1)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_estPremium) Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
                    child: Text('Actuel', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(height: 8),
                  Text('Premium 👑', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('1 000 FCFA/mois', style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
                  SizedBox(height: 12),
                  _featureItem('Groupes illimités', true),
                  _featureItem('Membres illimités', true),
                  _featureItem('Coffre-fort', true),
                  _featureItem('Amendes', true),
                  _featureItem('Historique complet', true),
                  _featureItem('Sans publicités', true),
                ]),
              ),
            )),
          ]),
          SizedBox(height: 20),

          // Avantages
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pourquoi passer Premium ?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kNoir)),
              SizedBox(height: 14),
              _avantage('🏦', 'Coffre-fort personnel', 'Chaque membre épargne à son rythme'),
              _avantage('⚠️', 'Système d\'amendes', 'Gérez les retards et absences'),
              _avantage('📊', 'Historique complet', 'Tous les paiements archivés'),
              _avantage('👥', 'Groupes illimités', 'Gérez autant de tontines que vous voulez'),
              _avantage('🚫', 'Sans publicités', 'Expérience fluide et professionnelle'),
            ]),
          ),
          SizedBox(height: 20),

          if (!_estPremium) SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _afficherOptionsPaiement,
              child: Text('👑 Passer Premium — 1 000 FCFA/mois',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),

          if (_estPremium) Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200)),
            child: Row(children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Expanded(child: Text('Vous bénéficiez de toutes les fonctionnalités Premium !',
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500))),
            ]),
          ),
          SizedBox(height: 10),
        ]),
      ),
    );
  }

  void _afficherOptionsPaiement() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 16),
          Text('Choisir le mode de paiement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('1 000 FCFA / mois', style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.w600, fontSize: 15)),
          SizedBox(height: 20),
          _boutonPaiement('Wave', Color(0xFF0057FF), '📱 Payer avec Wave', () => _payerAvec('Wave')),
          SizedBox(height: 10),
          _boutonPaiement('Orange', Color(0xFFFF6600), '🟠 Payer avec Orange Money', () => _payerAvec('Orange Money')),
          SizedBox(height: 10),
          _boutonPaiement('Free', Color(0xFF00A651), '💚 Payer avec Free Money', () => _payerAvec('Free Money')),
          SizedBox(height: 16),
          Text('Après le paiement, envoyez votre reçu sur WhatsApp pour activation',
            style: TextStyle(color: kGris, fontSize: 11), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Future<void> _payerAvec(String mode) async {
    Navigator.pop(context);
    final email = supabase.auth.currentUser?.email ?? '';
    final message = 'Bonjour, je veux activer NattPro Premium.\nEmail: $email\nMode: $mode\nMontant: 1000 FCFA';
    final url = Uri.parse('https://wa.me/221TONNUMERO?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir WhatsApp')));
    }
  }
}
