import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'dart:math';

class InvitationScreen extends StatefulWidget {
  final GroupeNatt groupe;
  InvitationScreen({required this.groupe});
  @override
  _InvitationScreenState createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  String? code;
  bool chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerOuCreerCode();
  }

  String _genererCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (_) => chars[Random().nextInt(chars.length)]).join();
  }

  Future<void> _chargerOuCreerCode() async {
    setState(() => chargement = true);
    try {
      final data = await supabase
          .from('invitations')
          .select()
          .eq('groupe_id', widget.groupe.id!)
          .maybeSingle();

      if (data != null) {
        setState(() { code = data['code']; chargement = false; });
      } else {
        final nouveau = _genererCode();
        await supabase.from('invitations').insert({
          'groupe_id': widget.groupe.id,
          'code': nouveau,
        });
        setState(() { code = nouveau; chargement = false; });
      }
    } catch (e) {
      setState(() => chargement = false);
    }
  }

  String get lienInvitation => 'https://nattproapp.com/rejoindre/$code';

  String get messageInvitation =>
      '🤝 *Rejoignez notre groupe Natt !*\n\n'
      'Groupe : *${widget.groupe.nom}*\n'
      'Cotisation : *${widget.groupe.montant.toStringAsFixed(0)} FCFA*\n'
      'Fréquence : *${widget.groupe.frequence}*\n\n'
      'Code d\'invitation : *$code*\n\n'
      'Téléchargez NattPro et entrez ce code pour rejoindre le groupe !\n\n'
      '_NattPro — Gérez votre tontine facilement_ 🇸🇳';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kBlue,
        title: Text('Inviter des membres', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: chargement
          ? Center(child: CircularProgressIndicator(color: kBlue))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    Text('Code d\'invitation', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    SizedBox(height: 12),
                    Text(code ?? '', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 6)),
                    SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Code copié !')));
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.copy, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Copier le code', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Partager sur', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kNoir)),
                    SizedBox(height: 16),
                    _boutonPartage('WhatsApp', Color(0xFF25D366), Icons.chat, () => _partager('whatsapp')),
                    SizedBox(height: 10),
                    _boutonPartage('Facebook', Color(0xFF1877F2), Icons.facebook, () => _partager('facebook')),
                    SizedBox(height: 10),
                    _boutonPartage('Telegram', Color(0xFF0088CC), Icons.send, () => _partager('telegram')),
                    SizedBox(height: 10),
                    _boutonPartage('SMS', Color(0xFF34B7F1), Icons.sms, () => _partager('sms')),
                    SizedBox(height: 10),
                    _boutonPartage('Copier le lien', kBlue, Icons.link, () {
                      Clipboard.setData(ClipboardData(text: lienInvitation));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lien copié !')));
                    }),
                  ]),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(color: kBluLight, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: kBlue, size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Text(
                      'Partagez ce code avec les membres. Ils pourront rejoindre le groupe en entrant ce code dans NattPro.',
                      style: TextStyle(color: kBlue, fontSize: 12),
                    )),
                  ]),
                ),
              ]),
            ),
    );
  }

  Widget _boutonPartage(String label, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          SizedBox(width: 14),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kNoir)),
          Spacer(),
          Icon(Icons.arrow_forward_ios, size: 14, color: kGris),
        ]),
      ),
    );
  }

  Future<void> _partager(String plateforme) async {
    final message = messageInvitation;
    final encoded = Uri.encodeComponent(message);
    Uri url;
    switch (plateforme) {
      case 'whatsapp':
        url = Uri.parse('whatsapp://send?text=$encoded');
        final urlWeb = Uri.parse('https://wa.me/?text=$encoded');
        try {
          if (await canLaunchUrl(url)) { await launchUrl(url); return; }
          await launchUrl(urlWeb, mode: LaunchMode.externalApplication);
        } catch (_) {
          await launchUrl(urlWeb, mode: LaunchMode.externalApplication);
        }
        return;
      case 'facebook':
        url = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(lienInvitation)}');
        break;
      case 'telegram':
        url = Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(lienInvitation)}&text=$encoded');
        break;
      case 'sms':
        url = Uri.parse('sms:?body=$encoded');
        break;
      default:
        return;
    }
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir l\'application')));
    }
  }
}
