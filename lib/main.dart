import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_config.dart';
import 'auth_screen.dart';
import 'dart:math';

final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
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
const kBlue = Color(0xFF1B4FD8);
const kBluLight = Color(0xFFEEF2FF);
const kNoir = Color(0xFF111111);
const kGris = Color(0xFF888888);

class NattProApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NattPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kBlue),
        useMaterial3: true,
      ),
      home: supabase.auth.currentSession != null ? HomeScreen() : AuthScreen(),
    );
  }
}

class Paiement {
  String? id;
  String membreId;
  int tour;
  bool paye;
  DateTime? date;
  Paiement({this.id, required this.membreId, required this.tour, required this.paye, this.date});
}

class Membre {
  String? id;
  String nom;
  String telephone;
  int ordre;
  bool aDejaGagne; // AJOUT : Pour la logique de gagnant
  List<Paiement> paiements;
  
  Membre({this.id, required this.nom, required this.telephone, required this.ordre, this.aDejaGagne = false, required this.paiements});
  
  factory Membre.fromJson(Map<String, dynamic> json) => Membre(
    id: json['id'], 
    nom: json['nom'], 
    telephone: json['telephone'] ?? '',
    ordre: json['ordre'] ?? 0, 
    aDejaGagne: json['a_deja_gagne'] ?? false, // Mappage Supabase
    paiements: [],
  );
  
  bool aPaye(int tour) => paiements.any((p) => p.tour == tour && p.paye);
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
    int tours = (frequence == 'Hebdomadaire') 
      ? maintenant.difference(dateDebut).inDays ~/ 7 
      : (maintenant.year - dateDebut.year) * 12 + maintenant.month - dateDebut.month;
    return tours.clamp(0, membres.isEmpty ? 0 : membres.length - 1);
  }
  
  Membre? get receveurActuel => membres.isNotEmpty && tirageEffectue ? membres.firstWhere((m) => m.ordre == tourActuel + 1, orElse: () => membres[0]) : null;
  double get cagnotte => membres.length * montant;
  int get nbPayesTourActuel => membres.where((m) => m.aPaye(tourActuel)).length;
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<GroupeNatt> groupes = [];
  bool chargement = true;
  int _onglet = 0;

  @override
  void initState() { super.initState(); _chargerGroupes(); }

  Future<void> _chargerGroupes() async {
    setState(() => chargement = true);
    try {
      final data = await supabase.from('groupes').select('*, membres(*, paiements(*))').eq('user_id', supabase.auth.currentUser!.id).order('created_at');
      final liste = (data as List).map((g) {
        final groupe = GroupeNatt.fromJson(g);
        groupe.membres = (g['membres'] as List).map((m) {
          final membre = Membre.fromJson(m);
          membre.paiements = (m['paiements'] as List).map((p) => Paiement(
            id: p['id'], membreId: p['membre_id'], tour: p['tour'], paye: p['paye'],
            date: p['date_paiement'] != null ? DateTime.parse(p['date_paiement']) : null,
          )).toList();
          return membre;
        }).toList()..sort((a, b) => a.ordre.compareTo(b.ordre));
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
      body: _onglet == 0 ? _buildAccueil() : _buildHistoriquePaiements(),
      bottomNavigationBar: _buildNavBar(),
      floatingActionButton: _onglet == 0 ? FloatingActionButton(backgroundColor: kBlue, child: Icon(Icons.add, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreerGroupeScreen(onCreer: _chargerGroupes)))) : null,
    );
  }

  // --- UI NAV BAR ---
  Widget _buildNavBar() {
    return BottomNavigationBar(
      currentIndex: _onglet,
      onTap: (i) => setState(() => _onglet = i),
      selectedItemColor: kBlue,
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Paiements'),
      ],
    );
  }

  // --- UI ACCUEIL ---
  Widget _buildAccueil() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 150, pinned: true, backgroundColor: kBlue,
          flexibleSpace: FlexibleSpaceBar(title: Text('NattPro 🤝', style: TextStyle(fontSize: 18, color: Colors.white))),
          actions: [IconButton(icon: Icon(Icons.refresh, color: Colors.white), onPressed: _chargerGroupes)],
        ),
        if (chargement) SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kBlue)))
        else if (groupes.isEmpty) SliverFillRemaining(child: Center(child: Text('Aucun groupe actif')))
        else SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverList(delegate: SliverChildBuilderDelegate((context, i) => _buildGroupeCard(groupes[i]), childCount: groupes.length)),
        )
      ],
    );
  }

  Widget _buildGroupeCard(GroupeNatt g) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(g.nom, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${g.membres.length} membres · ${g.montant} FCFA"),
        trailing: Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailGroupeScreen(groupe: g, onUpdate: _chargerGroupes))),
      ),
    );
  }

  Widget _buildHistoriquePaiements() {
    return Center(child: Text("Historique des paiements"));
  }
}

// --- ECRAN DETAIL (INTEGRATION DES NOUVELLES FONCTIONNALITÉS) ---
class DetailGroupeScreen extends StatefulWidget {
  final GroupeNatt groupe;
  final VoidCallback onUpdate;
  DetailGroupeScreen({required this.groupe, required this.onUpdate});
  @override
  _DetailGroupeScreenState createState() => _DetailGroupeScreenState();
}

class _DetailGroupeScreenState extends State<DetailGroupeScreen> {

  // 1. FONCTION : AMENDE
  Future<void> _infligerAmende(Membre membre) async {
    final motifCtrl = TextEditingController();
    final montantCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('Amende : ${membre.nom}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: motifCtrl, decoration: InputDecoration(labelText: 'Motif')),
        TextField(controller: montantCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Montant')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
        ElevatedButton(onPressed: () async {
          await supabase.from('amendes').insert({
            'membre_id': membre.id, 'groupe_id': widget.groupe.id,
            'motif': motifCtrl.text, 'montant': double.parse(montantCtrl.text),
          });
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Amende enregistrée')));
        }, child: Text('Valider')),
      ],
    ));
  }

  // 2. FONCTION : COFFRE-FORT
  Future<void> _depotCoffre(Membre membre) async {
    final montantCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('Épargne : ${membre.nom}'),
      content: TextField(controller: montantCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Montant')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
        ElevatedButton(onPressed: () async {
          await supabase.from('coffre_fort').insert({
            'membre_id': membre.id, 'groupe_id': widget.groupe.id, 'montant': double.parse(montantCtrl.text),
          });
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Argent épargné')));
        }, child: Text('Déposer')),
      ],
    ));
  }

  // 3. FONCTION : TIRAGE LOGIQUE GAGNANT UNIQUE
  Future<void> _lancerTirage() async {
    // On ne tire au sort que ceux qui n'ont pas encore gagné
    final eligibles = widget.groupe.membres.where((m) => !m.aDejaGagne).toList();
    if (eligibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tout le monde a déjà gagné !')));
      return;
    }

    eligibles.shuffle();
    // Le premier de la liste mélangée est le gagnant du tour
    final gagnant = eligibles[0];

    for (int i = 0; i < widget.groupe.membres.length; i++) {
      final membre = widget.groupe.membres[i];
      // On met à jour l'ordre pour ce tour et on marque le gagnant
      if (membre.id == gagnant.id) {
        await supabase.from('membres').update({'a_deja_gagne': true, 'ordre': widget.groupe.tourActuel + 1}).eq('id', membre.id!);
      }
    }
    
    await supabase.from('groupes').update({'tirage_effectue': true}).eq('id', widget.groupe.id!);
    widget.onUpdate();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagnant du tour : ${gagnant.nom}')));
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.groupe;
    return Scaffold(
      appBar: AppBar(title: Text(g.nom), backgroundColor: kBlue, iconTheme: IconThemeData(color: Colors.white),
        actions: [IconButton(icon: Icon(Icons.shuffle), onPressed: _lancerTirage)]),
      body: Column(children: [
        _buildResumeTop(),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: g.membres.length,
            itemBuilder: (context, i) => _buildMembreCard(g.membres[i]),
          ),
        )
      ]),
    );
  }

  Widget _buildResumeTop() {
    return Container(
      padding: EdgeInsets.all(16), color: kBlue,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _statItem("Tour", "${widget.groupe.tourActuel + 1}"),
        _statItem("Cagnotte", "${widget.groupe.cagnotte} F"),
      ]),
    );
  }

  Widget _statItem(String l, String v) => Column(children: [Text(l, style: TextStyle(color: Colors.white70)), Text(v, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]);

  Widget _buildMembreCard(Membre m) {
    final aPaye = m.aPaye(widget.groupe.tourActuel);
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text("${m.ordre}")),
        title: Text(m.nom, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            IconButton(icon: Icon(Icons.gavel, color: Colors.red, size: 20), onPressed: () => _infligerAmende(m)),
            IconButton(icon: Icon(Icons.savings, color: Colors.green, size: 20), onPressed: () => _depotCoffre(m)),
          ],
        ),
        trailing: IconButton(
          icon: Icon(aPaye ? Icons.check_circle : Icons.circle_outlined, color: aPaye ? Colors.green : Colors.grey),
          onPressed: () async {
            if (!aPaye) {
              await supabase.from('paiements').insert({'membre_id': m.id, 'tour': widget.groupe.tourActuel, 'paye': true});
              widget.onUpdate();
            }
          },
        ),
      ),
    );
  }
}

// --- ECRAN CREATION GROUPE ---
class CreerGroupeScreen extends StatelessWidget {
  final VoidCallback onCreer;
  final nomCtrl = TextEditingController();
  final montantCtrl = TextEditingController();
  CreerGroupeScreen({required this.onCreer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Nouveau Groupe")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(children: [
          TextField(controller: nomCtrl, decoration: InputDecoration(labelText: "Nom")),
          TextField(controller: montantCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Montant")),
          SizedBox(height: 20),
          ElevatedButton(onPressed: () async {
            await supabase.from('groupes').insert({
              'nom': nomCtrl.text, 'montant': double.parse(montantCtrl.text),
              'user_id': supabase.auth.currentUser!.id, 'frequence': 'Mensuel',
              'date_debut': DateTime.now().toIso8601String(),
            });
            onCreer();
            Navigator.pop(context);
          }, child: Text("Créer"))
        ]),
      ),
    );
  }
}

