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
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _estPremium ? Colors.amber.shade800 : kBlue)),
                if (_estPremium && _dateFin != null)
                  Text('Expire le ${_dateFin!.day}/${_dateFin!.month}/${_dateFin!.year}',
                    style: TextStyle(color: kGris, fontSize: 12)),
                if (!_estPremium)
                  Text('Passez Premium pour tout débloquer', style: TextStyle(color: kGris, fontSize: 12)),
              ])),
            ]),
          ),
          SizedBox(height: 20),

          // Comparaison Gratuit vs Premium
          Row(children: [
            Expanded(child: _carteFormule(
              titre: 'Gratuit',
              prix: '0 FCFA',
              couleur: Colors.grey,
              fonctionnalites: [
                _feature('2 groupes maximum', false),
                _feature('10 membres/groupe', false),
                _feature('Tirage au sort', true),
                _feature('Paiements basiques', true),
                _feature('WhatsApp partage', true),
                _feature('Publicités', false),
              ],
              estActif: !_estPremium,
              onTap: null,
            )),
            SizedBox(width: 12),
            Expanded(child: _carteFormule(
              titre: 'Premium 👑',
              prix: '1 000 FCFA/mois',
              couleur: Colors.amber,
              fonctionnalites: [
                _feature('Groupes illimités', true),
                _feature('Membres illimités', true),
                _feature('Coffre-fort', true),
                _feature('Amendes', true),
                _feature('Historique complet', true),
                _feature('Sans publicités', true),
              ],
              estActif: _estPremium,
              onTap: _estPremium ? null : () => _afficherOptionsPaiement(),
            )),
          ]),
          SizedBox(height: 20),

          // Avantages détaillés
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pourquoi passer Premium ?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kNoir)),
              SizedBox(height: 14),
              _avantage('🏦', 'Coffre-fort personnel', 'Chaque membre épargne à son rythme'),
              _avantage('⚠️', 'Système d\'amendes', 'Gérez les retards et absences'),
              _avantage('📊', 'Historique complet', 'Tous les paiements archivés'),
              _avantage('👥', 'Groupes illimités', 'Gérez autant de tontines que vous voulez'),
              _avantage('🚫', 'Sans publicités', 'Expérience fluide et professionnelle'),
              _avantage('🔔', 'Notifications prioritaires', 'Rappels automatiques pour vos membres'),
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
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('👑 ', style: TextStyle(fontSize: 20)),
                Text('Passer Premium — 1 000 FCFA/mois',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),

          if (_estPremium) Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
            child: Row(children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('Vous bénéficiez de toutes les fonctionnalités Premium !',
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500)),
            ]),
          ),
          SizedBox(height: 10),
        ]),
      ),
    );
  }

  Widget _carteFormule({
    required String titre,
    required String prix,
    required Color couleur,
    required List<Widget> fonctionnalites,
    required bool estActif,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: estActif ? couleur : Colors.grey.shade200, width: estActif ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (estActif) Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(6)),
            child: Text('Actuel', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          SizedBox(height: 8),
          Text(titre, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kNoir)),
          SizedBox(height: 4),
          Text(prix, style: TextStyle(color: couleur, fontWeight: FontWeight.w600, fontSize: 12)),
          SizedBox(height: 12),
          ...fonctionnalites,
        ]),
      ),
    );
  }

  Map<String, bool> _feature(String label, bool inclus) => {'label': label, 'inclus': inclus} as Map<String, bool>;

  Widget _feature(String label, bool inclus) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(inclus ? Icons.check_circle : Icons.cancel, color: inclus ? Colors.green : Colors.red.shade300, size: 14),
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
          _boutonPaiement('Wave', Color(0xFF0057FF), '📱 Payer avec Wave', () => _payerWave()),
          SizedBox(height: 10),
          _boutonPaiement('Orange Money', Color(0xFFFF6600), '🟠 Payer avec Orange Money', () => _payerOrangeMoney()),
          SizedBox(height: 10),
          _boutonPaiement('Free Money', Color(0xFF00A651), '💚 Payer avec Free Money', () => _payerFreeMoney()),
          SizedBox(height: 16),
          Text('Après le paiement, contactez-nous sur WhatsApp pour activation',
            style: TextStyle(color: kGris, fontSize: 11), textAlign: TextAlign.center),
        ]),
      ),
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
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(label[0], style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
          SizedBox(width: 12),
          Text(texte, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kNoir)),
          Spacer(),
          Icon(Icons.arrow_forward_ios, size: 14, color: kGris),
        ]),
      ),
    );
  }

  Future<void> _payerWave() async {
    Navigator.pop(context);
    // Numéro Wave du gérant de NattPro
    final message = 'Bonjour, je veux activer NattPro Premium pour ${supabase.auth.currentUser?.email}. Montant: 1000 FCFA';
    final url = Uri.parse('https://wa.me/221XXXXXXXXX?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _payerOrangeMoney() async {
    Navigator.pop(context);
    final message = 'Bonjour, je veux activer NattPro Premium pour ${supabase.auth.currentUser?.email}. Montant: 1000 FCFA';
    final url = Uri.parse('https://wa.me/221XXXXXXXXX?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _payerFreeMoney() async {
    Navigator.pop(context);
    final message = 'Bonjour, je veux activer NattPro Premium pour ${supabase.auth.currentUser?.email}. Montant: 1000 FCFA';
    final url = Uri.parse('https://wa.me/221XXXXXXXXX?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _activerPremiumManuellement(String userId) async {
    // Cette fonction est appelée par le gérant après confirmation du paiement
    final dateFin = DateTime.now().add(Duration(days: 30));
    await supabase.from('abonnements').upsert({
      'user_id': userId,
      'type': 'premium',
      'actif': true,
      'date_fin': dateFin.toIso8601String(),
      'montant': 1000,
    });
  }
}
