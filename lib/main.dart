import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'supabase_config.dart';
import 'dart:math';

final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  tz.initializeTimeZones();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);
  await notificationsPlugin.initialize(settings);
}

Future<void> envoyerNotification(String titre, String corps) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'nattro_channel', 'NattPro',
      channelDescription: 'Rappels de cotisation',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );
  await notificationsPlugin.show(0, titre, corps, details);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(NattProApp());
}

final supabase = Supabase.instance.client;

class NattProApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NattPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF006633)),
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}

class Membre {
  String? id;
  String nom;
  String telephone;
  int ordre;
  List<bool> paiements;
  Membre({this.id, required this.nom, required this.telephone, required this.ordre, required this.paiements});
  factory Membre.fromJson(Map<String, dynamic> json) => Membre(
    id: json['id'], nom: json['nom'], telephone: json['telephone'] ?? '',
    ordre: json['ordre'] ?? 0, paiements: [],
  );
}

class GroupeNatt {
  String? id;
  String nom;
  double montant;
  String frequence;
  DateTime dateDebut;
  List<Membre> membres;
  bool tirageEffectue;
  GroupeNatt({this.id, required this.nom, required this.montant, required this.frequence, required this.dateDebut, required this.membres, this.tirageEffectue = false});
  factory GroupeNatt.fromJson(Map<String, dynamic> json) => GroupeNatt(
    id: json['id'], nom: json['nom'], montant: (json['montant'] as num).toDouble(),
    frequence: json['frequence'], dateDebut: DateTime.parse(json['date_debut']),
    tirageEffectue: json['tirage_effectue'] ?? false, membres: [],
  );
  int get tourActuel {
    final maintenant = DateTime.now();
    int tours = 0;
    if (frequence == 'Hebdomadaire') {
      tours = maintenant.difference(dateDebut).inDays ~/ 7;
    } else {
      tours = (maintenant.year - dateDebut.year) * 12 + maintenant.month - dateDebut.month;
    }
    return tours.clamp(0, membres.isEmpty ? 0 : membres.length - 1);
  }
}

// ═══════════════════════════════
// ÉCRAN ACCUEIL
// ═══════════════════════════════

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<GroupeNatt> groupes = [];
  bool chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerGroupes();
  }

  Future<void> _chargerGroupes() async {
    setState(() => chargement = true);
    try {
      final data = await supabase.from('groupes').select('*, membres(*)').order('created_at');
      final liste = (data as List).map((g) {
        final groupe = GroupeNatt.fromJson(g);
        groupe.membres = (g['membres'] as List).map((m) => Membre.fromJson(m)).toList();
        groupe.membres.sort((a, b) => a.ordre.compareTo(b.ordre));
        return groupe;
      }).toList();
      setState(() { groupes = liste; chargement = false; });
    } catch (e) {
      setState(() => chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Color(0xFF006633),
        title: Text('NattPro 🤝', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.notifications, color: Colors.white), onPressed: _testerNotification),
          IconButton(icon: Icon(Icons.refresh, color: Colors.white), onPressed: _chargerGroupes),
        ],
      ),
      body: chargement
          ? Center(child: CircularProgressIndicator(color: Color(0xFF006633)))
          : groupes.isEmpty ? _buildEmpty() : _buildListe(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Color(0xFF006633),
        onPressed: _ajouterGroupe,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Nouveau Natt', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _testerNotification() async {
    await envoyerNotification('NattPro 🤝', 'Rappel : Pensez à cotiser pour votre Natt !');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notification envoyée !')));
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('🤝', style: TextStyle(fontSize: 80)),
      SizedBox(height: 16),
      Text('Amul Natt bi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      Text('Créez votre premier groupe de tontine', style: TextStyle(color: Colors.grey)),
    ]));
  }

  Widget _buildListe() {
    return RefreshIndicator(
      color: Color(0xFF006633),
      onRefresh: _chargerGroupes,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: groupes.length,
        itemBuilder: (context, index) {
          final groupe = groupes[index];
          final receveur = groupe.membres.isNotEmpty ? groupe.membres[groupe.tourActuel] : null;
          return Dismissible(
            key: Key(groupe.id ?? index.toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: 20),
              color: Colors.red,
              child: Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) async {
              return await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Supprimer ?'),
                  content: Text('Supprimer le groupe "${groupe.nom}" ?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Supprimer', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (_) async {
              await supabase.from('groupes').delete().eq('id', groupe.id!);
              setState(() => groupes.removeAt(index));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Groupe supprimé')));
            },
            child: Card(
              margin: EdgeInsets.only(bottom: 12),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: Color(0xFF006633),
                  child: Text(groupe.nom[0].toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(groupe.nom, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(height: 4),
                  Text('💰 ${groupe.montant.toStringAsFixed(0)} FCFA — ${groupe.frequence}'),
                  if (receveur != null) Text('🎯 Tour : ${receveur.nom}', style: TextStyle(color: Color(0xFF006633), fontWeight: FontWeight.w600)),
                  Text('👥 ${groupe.membres.length} membres'),
                ]),
                trailing: Icon(Icons.arrow_forward_ios, color: Color(0xFF006633)),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => DetailGroupeScreen(groupe: groupe, onUpdate: _chargerGroupes),
                )),
              ),
            ),
          );
        },
      ),
    );
  }

  void _ajouterGroupe() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CreerGroupeScreen(onCreer: _chargerGroupes),
    ));
  }
}

// ═══════════════════════════════
// CRÉER UN GROUPE
// ═══════════════════════════════

class CreerGroupeScreen extends StatefulWidget {
  final VoidCallback onCreer;
  CreerGroupeScreen({required this.onCreer});
  @override
  _CreerGroupeScreenState createState() => _CreerGroupeScreenState();
}

class _CreerGroupeScreenState extends State<CreerGroupeScreen> {
  final _nomCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  String _frequence = 'Mensuel';
  DateTime _dateDebut = DateTime.now();
  bool _enregistrement = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF006633),
        title: Text('Créer un Natt', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(children: [
          _champ(_nomCtrl, 'Nom du groupe', Icons.group),
          SizedBox(height: 16),
          _champ(_montantCtrl, 'Montant (FCFA)', Icons.attach_money, type: TextInputType.number),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _frequence,
            decoration: InputDecoration(labelText: 'Fréquence', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            items: ['Hebdomadaire', 'Mensuel'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (val) => setState(() => _frequence = val!),
          ),
          SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey)),
            leading: Icon(Icons.calendar_today),
            title: Text('Date de début'),
            subtitle: Text('${_dateDebut.day}/${_dateDebut.month}/${_dateDebut.year}'),
            onTap: () async {
              final date = await showDatePicker(context: context, initialDate: _dateDebut, firstDate: DateTime(2024), lastDate: DateTime(2030));
              if (date != null) setState(() => _dateDebut = date);
            },
          ),
          SizedBox(height: 30),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF006633), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _enregistrement ? null : _valider,
              child: _enregistrement
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Créer', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _champ(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
    );
  }

  Future<void> _valider() async {
    if (_nomCtrl.text.isEmpty || _montantCtrl.text.isEmpty) return;
    setState(() => _enregistrement = true);
    try {
      await supabase.from('groupes').insert({
        'nom': _nomCtrl.text, 'montant': double.tryParse(_montantCtrl.text) ?? 0,
        'frequence': _frequence, 'date_debut': _dateDebut.toIso8601String().split('T')[0],
        'tirage_effectue': false,
      });
      widget.onCreer();
      Navigator.pop(context);
    } catch (e) {
      setState(() => _enregistrement = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }
}

// ═══════════════════════════════
// DÉTAIL GROUPE
// ═══════════════════════════════

class DetailGroupeScreen extends StatefulWidget {
  final GroupeNatt groupe;
  final VoidCallback onUpdate;
  DetailGroupeScreen({required this.groupe, required this.onUpdate});
  @override
  _DetailGroupeScreenState createState() => _DetailGroupeScreenState();
}

class _DetailGroupeScreenState extends State<DetailGroupeScreen> {

  @override
  Widget build(BuildContext context) {
    final groupe = widget.groupe;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF006633),
        title: Text(groupe.nom, style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: Icon(Icons.history, color: Colors.white), tooltip: 'Historique', onPressed: _voirHistorique),
          IconButton(icon: Icon(Icons.share, color: Colors.white), tooltip: 'WhatsApp', onPressed: _partagerWhatsApp),
          if (groupe.membres.length >= 2)
            IconButton(icon: Icon(Icons.shuffle, color: Colors.white), onPressed: _tirage),
        ],
      ),
      body: Column(children: [
        _buildResume(),
        if (!groupe.tirageEffectue && groupe.membres.length >= 2)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange)),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Effectuez le tirage pour définir l\'ordre', style: TextStyle(color: Colors.orange[800]))),
            ]),
          ),
        SizedBox(height: 8),
        Expanded(
          child: groupe.membres.isEmpty
              ? Center(child: Text('Ajoutez des membres !', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: groupe.membres.length,
                  itemBuilder: (context, index) => _buildMembreCard(groupe.membres[index], index),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Color(0xFF006633),
        onPressed: _afficherOptionsAjout,
        icon: Icon(Icons.person_add, color: Colors.white),
        label: Text('Ajouter', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildResume() {
    final groupe = widget.groupe;
    final cagnotte = groupe.membres.length * groupe.montant;
    final paye = groupe.membres.where((m) => m.paiements.isNotEmpty && m.paiements.last).length;
    return Container(
      margin: EdgeInsets.all(16), padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Color(0xFF006633), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat('👥', '${groupe.membres.length}', 'Membres'),
          _stat('💰', '${groupe.montant.toStringAsFixed(0)}', 'FCFA'),
          _stat('🏆', '${cagnotte.toStringAsFixed(0)}', 'Cagnotte'),
        ]),
        SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: groupe.membres.isEmpty ? 0 : paye / groupe.membres.length,
            backgroundColor: Colors.white30,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
            minHeight: 8,
          ),
        ),
        SizedBox(height: 4),
        Text('$paye / ${groupe.membres.length} ont payé', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  Widget _stat(String emoji, String val, String label) {
    return Column(children: [
      Text(emoji, style: TextStyle(fontSize: 22)),
      Text(val, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      Text(label, style: TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }

  Widget _buildMembreCard(Membre membre, int index) {
    final groupe = widget.groupe;
    final estTour = groupe.tirageEffectue && index == groupe.tourActuel % groupe.membres.length;
    final aPaye = membre.paiements.isNotEmpty && membre.paiements.last;
    return Dismissible(
      key: Key(membre.id ?? index.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        color: Colors.red,
        child: Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Supprimer ?'),
            content: Text('Supprimer "${membre.nom}" du groupe ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        await supabase.from('membres').delete().eq('id', membre.id!);
        setState(() {
          widget.groupe.membres.removeAt(index);
          widget.groupe.tirageEffectue = false;
        });
        widget.onUpdate();
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: estTour ? Colors.amber[50] : null,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: estTour ? Colors.amber : Color(0xFF006633),
            child: Text('${membre.ordre}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          title: Text(membre.nom, style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(membre.telephone),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (estTour) Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
              child: Text('🎯', style: TextStyle(fontSize: 12)),
            ),
            SizedBox(width: 6),
            GestureDetector(
              onTap: () => _togglePaiement(membre, aPaye),
              child: Icon(aPaye ? Icons.check_circle : Icons.radio_button_unchecked, color: aPaye ? Colors.green : Colors.grey, size: 28),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _togglePaiement(Membre membre, bool aPaye) async {
    try {
      final tourActuel = widget.groupe.tourActuel;
      final existing = await supabase.from('paiements').select().eq('membre_id', membre.id!).eq('tour', tourActuel);
      if ((existing as List).isEmpty) {
        await supabase.from('paiements').insert({'membre_id': membre.id, 'tour': tourActuel, 'paye': true, 'date_paiement': DateTime.now().toIso8601String()});
      } else {
        await supabase.from('paiements').update({'paye': !aPaye}).eq('membre_id', membre.id!).eq('tour', tourActuel);
      }
      setState(() {
        if (membre.paiements.isEmpty) membre.paiements.add(!aPaye);
        else membre.paiements[membre.paiements.length - 1] = !aPaye;
      });
      if (!aPaye) await envoyerNotification('✅ Paiement confirmé', '${membre.nom} a cotisé pour ${widget.groupe.nom}');
      widget.onUpdate();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _partagerWhatsApp() async {
    final groupe = widget.groupe;
    if (!groupe.tirageEffectue) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ Effectuez le tirage d\'abord !')));
      return;
    }
    String message = '🤝 *NattPro - ${groupe.nom}*\n\n';
    message += '💰 Montant : ${groupe.montant.toStringAsFixed(0)} FCFA\n';
    message += '📅 Fréquence : ${groupe.frequence}\n\n';
    message += '🎯 *Ordre du tirage :*\n';
    for (final membre in groupe.membres) {
      message += '${membre.ordre}. ${membre.nom} - ${membre.telephone}\n';
    }
    message += '\n_Partagé via NattPro_ 🇸🇳';
    final encoded = Uri.encodeComponent(message);
    final url = Uri.parse('whatsapp://send?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WhatsApp non installé !')));
    }
  }

  void _voirHistorique() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => HistoriqueScreen(groupe: widget.groupe),
    ));
  }

  Future<void> _tirage() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('🎲 Tirage au sort'),
        content: Text('Mélanger les ${widget.groupe.membres.length} membres ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF006633)),
            onPressed: () async {
              Navigator.pop(context);
              widget.groupe.membres.shuffle(Random());
              for (int i = 0; i < widget.groupe.membres.length; i++) {
                widget.groupe.membres[i].ordre = i + 1;
                await supabase.from('membres').update({'ordre': i + 1}).eq('id', widget.groupe.membres[i].id!);
              }
              await supabase.from('groupes').update({'tirage_effectue': true}).eq('id', widget.groupe.id!);
              setState(() => widget.groupe.tirageEffectue = true);
              widget.onUpdate();
              _afficherResultat();
              await envoyerNotification('🎲 Tirage effectué !', 'L\'ordre du ${widget.groupe.nom} est défini !');
            },
            child: Text('Tirer !', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _afficherResultat() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('🎉 Résultat du tirage'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: widget.groupe.membres.map((m) => ListTile(
            leading: CircleAvatar(backgroundColor: Color(0xFF006633), child: Text('${m.ordre}', style: TextStyle(color: Colors.white))),
            title: Text(m.nom),
            subtitle: Text(m.telephone),
          )).toList()),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF006633)),
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _afficherOptionsAjout() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Ajouter un membre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          ListTile(
            leading: CircleAvatar(backgroundColor: Color(0xFF006633), child: Icon(Icons.contacts, color: Colors.white)),
            title: Text('Depuis mes contacts'),
            onTap: () { Navigator.pop(context); _ajouterDepuisContacts(); },
          ),
          Divider(),
          ListTile(
            leading: CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person_add, color: Colors.white)),
            title: Text('Nouveau contact'),
            onTap: () { Navigator.pop(context); _ajouterManuellement(); },
          ),
        ]),
      ),
    );
  }

  Future<void> _ajouterDepuisContacts() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permission contacts refusée')));
      return;
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Choisir un contact'),
        content: SizedBox(
          width: double.maxFinite, height: 400,
          child: ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              final tel = contact.phones.isNotEmpty ? contact.phones.first.number : '';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(0xFF006633),
                  child: Text(contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?', style: TextStyle(color: Colors.white)),
                ),
                title: Text(contact.displayName),
                subtitle: Text(tel),
                onTap: () { Navigator.pop(context); _sauvegarderMembre(contact.displayName, tel); },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer'))],
      ),
    );
  }

  void _ajouterManuellement() {
    final nomCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nouveau membre'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nomCtrl, decoration: InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person))),
          SizedBox(height: 12),
          TextField(controller: telCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF006633)),
            onPressed: () {
              if (nomCtrl.text.isNotEmpty) { Navigator.pop(context); _sauvegarderMembre(nomCtrl.text, telCtrl.text); }
            },
            child: Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sauvegarderMembre(String nom, String telephone) async {
    try {
      final ordre = widget.groupe.membres.length + 1;
      final result = await supabase.from('membres').insert({
        'groupe_id': widget.groupe.id, 'nom': nom, 'telephone': telephone, 'ordre': ordre,
      }).select();
      setState(() {
        widget.groupe.membres.add(Membre(id: result[0]['id'], nom: nom, telephone: telephone, ordre: ordre, paiements: []));
        widget.groupe.tirageEffectue = false;
      });
      widget.onUpdate();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }
}

// ═══════════════════════════════
// HISTORIQUE DES PAIEMENTS
// ═══════════════════════════════

class HistoriqueScreen extends StatefulWidget {
  final GroupeNatt groupe;
  HistoriqueScreen({required this.groupe});
  @override
  _HistoriqueScreenState createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  List<Map<String, dynamic>> historique = [];
  bool chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    setState(() => chargement = true);
    try {
      final membres = widget.groupe.membres;
      List<Map<String, dynamic>> result = [];
      for (final membre in membres) {
        if (membre.id == null) continue;
        final paiements = await supabase.from('paiements').select().eq('membre_id', membre.id!).order('tour');
        for (final p in paiements as List) {
          result.add({
            'membre': membre.nom,
            'tour': p['tour'],
            'paye': p['paye'],
            'date': p['date_paiement'],
          });
        }
      }
      result.sort((a, b) => (b['tour'] as int).compareTo(a['tour'] as int));
      setState(() { historique = result; chargement = false; });
    } catch (e) {
      setState(() => chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF006633),
        title: Text('Historique — ${widget.groupe.nom}', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: chargement
          ? Center(child: CircularProgressIndicator(color: Color(0xFF006633)))
          : historique.isEmpty
              ? Center(child: Text('Aucun paiement enregistré', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: historique.length,
                  itemBuilder: (context, index) {
                    final h = historique[index];
                    final date = h['date'] != null ? DateTime.parse(h['date']) : null;
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: h['paye'] ? Colors.green : Colors.red,
                          child: Icon(h['paye'] ? Icons.check : Icons.close, color: Colors.white),
                        ),
                        title: Text(h['membre'], style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Tour ${h['tour'] + 1}${date != null ? ' • ${date.day}/${date.month}/${date.year}' : ''}'),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: h['paye'] ? Colors.green[50] : Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(h['paye'] ? 'Payé ✅' : 'Impayé ❌', style: TextStyle(color: h['paye'] ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
