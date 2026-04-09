import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

class ImpayesScreen extends StatelessWidget {
  final GroupeNatt groupe;
  ImpayesScreen({required this.groupe});

  @override
  Widget build(BuildContext context) {
    final impayes = groupe.membresNonPayes;
    final tour = groupe.tourActuel;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kBlue,
        title: Text('Impayés — ${groupe.nom}', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(children: [
        Container(
          margin: EdgeInsets.all(16), padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat('❌', '${impayes.length}', 'Impayés'),
            _stat('✅', '${groupe.membres.length - impayes.length}', 'Payés'),
            _stat('💰', '${(impayes.length * groupe.montant).toStringAsFixed(0)}', 'FCFA manquant'),
          ]),
        ),
        if (impayes.isEmpty)
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('🎉', style: TextStyle(fontSize: 60)),
            SizedBox(height: 16),
            Text('Tout le monde a payé !', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.green)),
          ])))
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: impayes.length,
              itemBuilder: (context, index) {
                final membre = impayes[index];
                return Container(
                  margin: EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      backgroundColor: Colors.red.shade50,
                      child: Text(membre.nom[0], style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(membre.nom, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(membre.telephone.isNotEmpty ? membre.telephone : 'Pas de numéro', style: TextStyle(color: kGris, fontSize: 12)),
                      Text('Tour ${tour + 1} — ${groupe.montant.toStringAsFixed(0)} FCFA', style: TextStyle(color: Colors.red, fontSize: 11)),
                    ])),
                    if (membre.telephone.isNotEmpty) Column(children: [
                      _boutonPaiement('Wave', Colors.blue, membre.telephone, groupe.montant),
                      SizedBox(height: 6),
                      _boutonPaiement('OM', Colors.orange, membre.telephone, groupe.montant),
                      SizedBox(height: 6),
                      _boutonWhatsApp(context, membre, groupe),
                    ]),
                  ]),
                );
              },
            ),
          ),
        if (impayes.isNotEmpty) Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF25D366), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: Icon(Icons.send, color: Colors.white),
              label: Text('Rappel groupé WhatsApp (${impayes.length})', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onPressed: () => _rappelGroupe(context, impayes, groupe),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _stat(String emoji, String val, String label) {
    return Column(children: [
      Text(emoji, style: TextStyle(fontSize: 20)),
      Text(val, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
      Text(label, style: TextStyle(color: Colors.white70, fontSize: 10)),
    ]);
  }

  Widget _boutonPaiement(String label, Color color, String telephone, double montant) {
    return GestureDetector(
      onTap: () async {
        final tel = telephone.replaceAll(' ', '').replaceAll('+', '').replaceAll('-', '');
        Uri url;
        if (label == 'Wave') {
          url = Uri.parse('https://pay.wave.com/m/$tel');
        } else {
          url = Uri.parse('tel:$tel');
        }
        try {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _boutonWhatsApp(BuildContext context, Membre membre, GroupeNatt groupe) {
    return GestureDetector(
      onTap: () => _envoyerRappelWhatsApp(context, membre, groupe),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Color(0xFF25D366).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFF25D366).withOpacity(0.4)),
        ),
        child: Text('WA', style: TextStyle(color: Color(0xFF25D366), fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _envoyerRappelWhatsApp(BuildContext context, Membre membre, GroupeNatt groupe) async {
    final tel = membre.telephone.replaceAll(' ', '');
    final message = '🤝 Salam ${membre.nom},\n\nC\'est un rappel de *NattPro* pour le groupe *${groupe.nom}*.\n\nTa cotisation de *${groupe.montant.toStringAsFixed(0)} FCFA* n\'est pas encore reçue.\n\nMerci de payer dès que possible ! 🙏\n\n_NattPro 🇸🇳_';
    final encoded = Uri.encodeComponent(message);

    final urlDirect = Uri.parse('whatsapp://send?phone=$tel&text=$encoded');
    final urlWeb = Uri.parse('https://wa.me/$tel?text=$encoded');

    try {
      if (await canLaunchUrl(urlDirect)) {
        await launchUrl(urlDirect);
      } else {
        await launchUrl(urlWeb, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(urlWeb, mode: LaunchMode.externalApplication);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir WhatsApp')));
      }
    }
  }

  Future<void> _rappelGroupe(BuildContext context, List<Membre> impayes, GroupeNatt groupe) async {
    String message = '🤝 *Rappel NattPro — ${groupe.nom}*\n\n';
    message += 'Les membres suivants n\'ont pas encore cotisé :\n\n';
    for (final m in impayes) {
      message += '• ${m.nom}\n';
    }
    message += '\nMontant : *${groupe.montant.toStringAsFixed(0)} FCFA*\n';
    message += '\nMerci de payer dès que possible 🙏\n\n_NattPro 🇸🇳_';

    final encoded = Uri.encodeComponent(message);
    final urlDirect = Uri.parse('whatsapp://send?text=$encoded');
    final urlWeb = Uri.parse('https://wa.me/?text=$encoded');

    try {
      if (await canLaunchUrl(urlDirect)) {
        await launchUrl(urlDirect);
      } else {
        await launchUrl(urlWeb, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(urlWeb, mode: LaunchMode.externalApplication);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir WhatsApp')));
      }
    }
  }
}
